import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'core/application/translate_clipboard_use_case_impl.dart';
import 'core/application/use_case_result.dart';
import 'core/domain/gateways/clipboard_gateway.dart';
import 'core/domain/gateways/overlay_gateway.dart';
import 'core/domain/llm_config.dart';
import 'core/domain/translation_record.dart';
import 'infrastructure/debug_trace_logger.dart';
import 'infrastructure/http_llm_gateway.dart';
import 'infrastructure/in_memory_record_repository.dart';
import 'infrastructure/shared_prefs_llm_config_repository.dart';
import 'infrastructure/shared_prefs_secret_vault.dart';
import 'infrastructure/vault_api_key_provider.dart';

const MethodChannel _backgroundChannel = MethodChannel('modeltranslation/background_translate');

@pragma('vm:entry-point')
Future<void> backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  final worker = _BackgroundTranslationWorker();
  _backgroundChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method != 'translateClipboard') {
      throw PlatformException(
        code: 'method_not_implemented',
        message: 'Unsupported method: ${call.method}',
      );
    }

    final Map<Object?, Object?>? args = call.arguments as Map<Object?, Object?>?;
    final String? clipboardText = (args?['clipboardText'] as String?)?.trim();
    final result = await worker.translate(clipboardText);
    return result;
  });
}

class _BackgroundTranslationWorker {
  _BackgroundTranslationWorker();

  final SharedPrefsSecretVault _vault = SharedPrefsSecretVault();
  final SharedPrefsLlmConfigRepository _configRepository = SharedPrefsLlmConfigRepository(
    initialConfig: LlmConfig(
      id: 'default-active-config',
      provider: 'openai-compatible',
      baseUrl: 'https://api.openai.com/v1',
      apiKeyRef: null,
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 512,
      timeoutMs: 12000,
      systemPrompt: 'Translate the text accurately and keep formatting.',
      updatedAt: DateTime(2026, 4, 11),
    ),
  );

  Future<Map<String, Object?>> translate(String? sourceText) async {
    final useCase = TranslateClipboardUseCaseImpl(
      clipboardGateway: _NoopClipboardGateway(),
      configRepository: _configRepository,
      llmGateway: HttpLlmGateway(
        apiKeyProvider: VaultApiKeyProvider(_vault).resolve,
      ),
      overlayGateway: _NoopOverlayGateway(),
      recordRepository: InMemoryRecordRepository(),
      nowProvider: DateTime.now,
      idProvider: () => DateTime.now().microsecondsSinceEpoch.toString(),
      targetLang: 'zh',
      stylePreset: 'concise',
      debugLogger: DebugTraceLogger.disabled(),
    );

    final UseCaseResult<TranslationRecord> result = await useCase.execute(
      sourceTextOverride: sourceText,
    );

    if (!result.isSuccess) {
      return <String, Object?>{
        'ok': false,
        'error': result.failure?.message ?? 'Translation failed',
      };
    }

    return <String, Object?>{
      'ok': true,
      'translatedText': result.value?.translatedText ?? '',
    };
  }
}

class _NoopClipboardGateway implements ClipboardGateway {
  @override
  Future<String?> readText() async => null;
}

class _NoopOverlayGateway implements OverlayGateway {
  @override
  Future<void> showError(String message) async {}

  @override
  Future<void> showResult(String translatedText) async {}
}
