import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/translate_clipboard_use_case_impl.dart';
import 'package:modeltranslation/core/domain/gateways/clipboard_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/overlay_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/record_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';
import 'package:modeltranslation/infrastructure/debug_trace_logger.dart';
import 'package:modeltranslation/infrastructure/debug_translate_clipboard_gateway.dart';
import 'package:modeltranslation/infrastructure/debug_llm_gateway.dart';

class CollectingLogger implements DebugTraceLogger {
  final List<String> entries = <String>[];

  @override
  bool get enabled => true;

  @override
  void log(String message) {
    entries.add(message);
  }
}

class FakeClipboardGateway implements ClipboardGateway {
  @override
  Future<String?> readText() async => 'Hello world';
}

class FakeLlmConfigRepository implements LlmConfigRepository {
  @override
  Future<LlmConfig?> loadActive() async => LlmConfig(
        id: 'cfg-1',
        provider: 'openai-compatible',
        baseUrl: 'https://api.example.com/v1',
        apiKeyRef: 'ref-1',
        model: 'gpt-4o-mini',
        temperature: 0.2,
        topP: 0.9,
        maxTokens: 256,
        timeoutMs: 3000,
        systemPrompt: 'Translate accurately.',
        updatedAt: DateTime(2026, 4, 11),
      );

  @override
  Future<void> saveActive(LlmConfig config) async {}
}

class FakeLlmGateway implements LlmGateway {
  @override
  Future<String> translate(TranslationRequest request) async => '你好，世界';
}

class FakeOverlayGateway implements OverlayGateway {
  @override
  Future<void> showError(String message) async {}

  @override
  Future<void> showResult({
    required String sourceText,
    required String translatedText,
    required double fontSizeSp,
  }) async {}
}

class FakeRecordRepository implements RecordRepository {
  final List<TranslationRecord> records = <TranslationRecord>[];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<TranslationRecord?> getById(String id) async => null;

  @override
  Future<List<TranslationRecord>> listRecent({int limit = 50}) async => records.take(limit).toList();

  @override
  Future<List<TranslationRecord>> search(String query) async => records.where((record) => record.sourceText.contains(query)).toList();

  @override
  Future<void> save(TranslationRecord record) async {
    records.add(record);
  }
}

void main() {
  test('TranslateClipboardUseCaseImpl emits debug traces for the happy path', () async {
    final logger = CollectingLogger();
    final useCase = TranslateClipboardUseCaseImpl(
      clipboardGateway: DebugTranslateClipboardGateway(FakeClipboardGateway(), logger: logger),
      configRepository: FakeLlmConfigRepository(),
      llmGateway: DebugLlmGateway(FakeLlmGateway(), logger: logger),
      overlayGateway: FakeOverlayGateway(),
      recordRepository: FakeRecordRepository(),
      nowProvider: () => DateTime(2026, 4, 11, 12),
      idProvider: () => 'record-1',
      targetLang: 'zh',
      stylePreset: 'concise',
      debugLogger: logger,
    );

    await useCase.execute();

      expect(logger.entries, anyElement(contains('translation.execute:start')));
      expect(logger.entries, anyElement(contains('clipboard.read:start')));
      expect(logger.entries, anyElement(contains('clipboard.read:success length=11')));
      expect(logger.entries, anyElement(contains('llm.translate:start')));
      expect(logger.entries, anyElement(contains('llm.translate:success')));
      expect(logger.entries, anyElement(contains('record.save:start status=success')));
  });
}
