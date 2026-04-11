import 'dart:convert';

import '../domain/gateways/clipboard_gateway.dart';
import '../domain/gateways/llm_config_repository.dart';
import '../domain/gateways/llm_gateway.dart';
import '../domain/gateways/overlay_gateway.dart';
import '../domain/gateways/record_repository.dart';
import '../domain/llm_config.dart';
import '../domain/translation_record.dart';
import '../domain/translation_request.dart';
import 'translate_clipboard_use_case.dart';
import 'use_case_result.dart';

class TranslateClipboardUseCaseImpl implements TranslateClipboardUseCase {
  TranslateClipboardUseCaseImpl({
    required ClipboardGateway clipboardGateway,
    required LlmConfigRepository configRepository,
    required LlmGateway llmGateway,
    required OverlayGateway overlayGateway,
    required RecordRepository recordRepository,
    required DateTime Function() nowProvider,
    required String Function() idProvider,
    required this.targetLang,
    required this.stylePreset,
  })  : _clipboardGateway = clipboardGateway,
        _configRepository = configRepository,
        _llmGateway = llmGateway,
        _overlayGateway = overlayGateway,
        _recordRepository = recordRepository,
        _nowProvider = nowProvider,
        _idProvider = idProvider;

  final ClipboardGateway _clipboardGateway;
  final LlmConfigRepository _configRepository;
  final LlmGateway _llmGateway;
  final OverlayGateway _overlayGateway;
  final RecordRepository _recordRepository;
  final DateTime Function() _nowProvider;
  final String Function() _idProvider;
  final String targetLang;
  final String? stylePreset;

  @override
  Future<UseCaseResult<TranslationRecord>> execute() async {
    final clipboardText = (await _clipboardGateway.readText())?.trim();
    if (clipboardText == null || clipboardText.isEmpty) {
      const failure = UseCaseFailure(
        code: 'clipboard_empty',
        message: 'Clipboard text is empty.',
      );
      await _overlayGateway.showError(failure.message);
      return UseCaseResult.failure(failure);
    }

    final config = await _configRepository.loadActive();
    if (config == null) {
      const failure = UseCaseFailure(
        code: 'config_missing',
        message: 'No active translation config found.',
      );
      await _overlayGateway.showError(failure.message);
      return UseCaseResult.failure(failure);
    }

    final request = TranslationRequest(
      sourceText: clipboardText,
      sourceLang: null,
      targetLang: targetLang,
      stylePreset: stylePreset,
      configSnapshot: config,
    );

    try {
      final translatedText = await _llmGateway.translate(request);
      final record = _buildRecord(
        sourceText: clipboardText,
        translatedText: translatedText,
        config: config,
        status: TranslationStatus.success,
        errorMessage: null,
      );

      await _overlayGateway.showResult(translatedText);
      await _recordRepository.save(record);
      return UseCaseResult.success(record);
    } catch (error) {
      final failureMessage = error.toString();
      final record = _buildRecord(
        sourceText: clipboardText,
        translatedText: '',
        config: config,
        status: TranslationStatus.failure,
        errorMessage: failureMessage,
      );

      await _overlayGateway.showError(failureMessage);
      await _recordRepository.save(record);
      return UseCaseResult.failure(
        UseCaseFailure(
          code: 'translation_failed',
          message: failureMessage,
          details: error,
        ),
      );
    }
  }

  TranslationRecord _buildRecord({
    required String sourceText,
    required String translatedText,
    required LlmConfig config,
    required TranslationStatus status,
    required String? errorMessage,
  }) {
    return TranslationRecord(
      id: _idProvider(),
      sourceText: sourceText,
      translatedText: translatedText,
      provider: config.provider,
      model: config.model,
      paramsJson: jsonEncode(<String, Object?>{
        'baseUrl': config.baseUrl,
        'temperature': config.temperature,
        'topP': config.topP,
        'maxTokens': config.maxTokens,
        'timeoutMs': config.timeoutMs,
        'targetLang': targetLang,
        'stylePreset': stylePreset,
      }),
      status: status,
      errorMessage: errorMessage,
      createdAt: _nowProvider(),
    );
  }
}
