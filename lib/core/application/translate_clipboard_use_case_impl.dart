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
import '../../infrastructure/debug_trace_logger.dart';

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
    DebugTraceLogger? debugLogger,
  })  : _clipboardGateway = clipboardGateway,
        _configRepository = configRepository,
        _llmGateway = llmGateway,
        _overlayGateway = overlayGateway,
        _recordRepository = recordRepository,
        _nowProvider = nowProvider,
      _idProvider = idProvider,
        _debugLogger = debugLogger ?? DebugTraceLogger.disabled();

  final ClipboardGateway _clipboardGateway;
  final LlmConfigRepository _configRepository;
  final LlmGateway _llmGateway;
  final OverlayGateway _overlayGateway;
  final RecordRepository _recordRepository;
  final DateTime Function() _nowProvider;
  final String Function() _idProvider;
  final String targetLang;
  final String? stylePreset;
  final DebugTraceLogger _debugLogger;

  @override
  Future<UseCaseResult<TranslationRecord>> execute() async {
    _trace('translation.execute:start target=$targetLang style=${stylePreset ?? 'none'}');

    _trace('clipboard.read:start');
    final clipboardText = (await _clipboardGateway.readText())?.trim();
    if (clipboardText == null || clipboardText.isEmpty) {
      _trace('clipboard.read:empty');
      const failure = UseCaseFailure(
        code: 'clipboard_empty',
        message: 'Clipboard text is empty.',
      );
      _trace('overlay.show:error clipboard_empty');
      await _overlayGateway.showError(failure.message);
      return UseCaseResult.failure(failure);
    }
    _trace('clipboard.read:success length=${clipboardText.length}');

    _trace('config.load:start');
    final config = await _configRepository.loadActive();
    if (config == null) {
      _trace('config.load:missing');
      const failure = UseCaseFailure(
        code: 'config_missing',
        message: 'No active translation config found.',
      );
      _trace('overlay.show:error config_missing');
      await _overlayGateway.showError(failure.message);
      return UseCaseResult.failure(failure);
    }
    _trace('config.load:success provider=${config.provider} model=${config.model}');

    final request = TranslationRequest(
      sourceText: clipboardText,
      sourceLang: null,
      targetLang: targetLang,
      stylePreset: stylePreset,
      configSnapshot: config,
    );

    try {
      _trace('llm.translate:start endpoint=${config.baseUrl}');
      final translatedText = await _llmGateway.translate(request);
      _trace('llm.translate:success length=${translatedText.length}');
      final record = _buildRecord(
        sourceText: clipboardText,
        translatedText: translatedText,
        config: config,
        status: TranslationStatus.success,
        errorMessage: null,
      );

      _trace('overlay.show:result length=${translatedText.length}');
      await _overlayGateway.showResult(translatedText);
      _trace('record.save:start status=success');
      await _recordRepository.save(record);
      _trace('record.save:success id=${record.id}');
      _trace('translation.execute:success');
      return UseCaseResult.success(record);
    } catch (error) {
      final failureMessage = error.toString();
      _trace('llm.translate:error ${error.runtimeType}');
      final record = _buildRecord(
        sourceText: clipboardText,
        translatedText: '',
        config: config,
        status: TranslationStatus.failure,
        errorMessage: failureMessage,
      );

      _trace('overlay.show:error translation_failed');
      await _overlayGateway.showError(failureMessage);
      _trace('record.save:start status=failure');
      await _recordRepository.save(record);
      _trace('record.save:success id=${record.id}');
      _trace('translation.execute:failure');
      return UseCaseResult.failure(
        UseCaseFailure(
          code: 'translation_failed',
          message: failureMessage,
          details: error,
        ),
      );
    }
  }

  void _trace(String message) {
    if (_debugLogger.enabled) {
      _debugLogger.log(message);
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
