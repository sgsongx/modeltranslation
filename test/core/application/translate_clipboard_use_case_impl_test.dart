import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/translate_clipboard_use_case.dart';
import 'package:modeltranslation/core/application/translate_clipboard_use_case_impl.dart';
import 'package:modeltranslation/core/application/use_case_result.dart';
import 'package:modeltranslation/core/domain/config/connection_test_result.dart';
import 'package:modeltranslation/core/domain/gateways/clipboard_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/overlay_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/record_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

class FakeClipboardGateway implements ClipboardGateway {
  FakeClipboardGateway(this.value);

  final String? value;

  @override
  Future<String?> readText() async => value;
}

class FakeLlmConfigRepository implements LlmConfigRepository {
  FakeLlmConfigRepository(this.activeConfig);

  final LlmConfig? activeConfig;

  @override
  Future<LlmConfig?> loadActive() async => activeConfig;

  @override
  Future<void> saveActive(LlmConfig config) async {}
}

class FakeLlmGateway implements LlmGateway {
  TranslationRequest? lastRequest;
  String result = '你好，世界';

  @override
  Future<String> translate(TranslationRequest request) async {
    lastRequest = request;
    return result;
  }
}

class FakeOverlayGateway implements OverlayGateway {
  String? lastResult;
  String? lastError;

  @override
  Future<void> showError(String message) async {
    lastError = message;
  }

  @override
  Future<void> showResult(String translatedText) async {
    lastResult = translatedText;
  }
}

class FakeRecordRepository implements RecordRepository {
  final List<TranslationRecord> savedRecords = <TranslationRecord>[];

  @override
  Future<void> save(TranslationRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> clearAll() async {
    savedRecords.clear();
  }

  @override
  Future<void> deleteById(String id) async {
    savedRecords.removeWhere((record) => record.id == id);
  }

  @override
  Future<TranslationRecord?> getById(String id) async {
    for (final record in savedRecords) {
      if (record.id == id) {
        return record;
      }
    }

    return null;
  }

  @override
  Future<List<TranslationRecord>> listRecent({int limit = 50}) async {
    return savedRecords.take(limit).toList();
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    return savedRecords.where((record) => record.sourceText.contains(query)).toList();
  }
}

void main() {
  test('TranslateClipboardUseCaseImpl translates clipboard text and saves a record', () async {
    final config = LlmConfig(
      id: 'config-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 1024,
      timeoutMs: 15000,
      systemPrompt: 'Translate with a concise style.',
      updatedAt: DateTime(2026, 4, 11),
    );
    final clipboardGateway = FakeClipboardGateway('Hello world');
    final configRepository = FakeLlmConfigRepository(config);
    final llmGateway = FakeLlmGateway();
    final overlayGateway = FakeOverlayGateway();
    final recordRepository = FakeRecordRepository();
    final useCase = TranslateClipboardUseCaseImpl(
      clipboardGateway: clipboardGateway,
      configRepository: configRepository,
      llmGateway: llmGateway,
      overlayGateway: overlayGateway,
      recordRepository: recordRepository,
      nowProvider: () => DateTime(2026, 4, 11, 12),
      idProvider: () => 'record-1',
      targetLang: 'zh',
      stylePreset: 'concise',
    );

    final result = await useCase.execute();

    expect(result.isSuccess, isTrue);
    expect(result.value?.translatedText, '你好，世界');
    expect(llmGateway.lastRequest?.sourceText, 'Hello world');
    expect(llmGateway.lastRequest?.targetLang, 'zh');
    expect(overlayGateway.lastResult, '你好，世界');
    expect(recordRepository.savedRecords, hasLength(1));
    expect(recordRepository.savedRecords.single.id, 'record-1');
  });

  test('TranslateClipboardUseCaseImpl returns a structured failure when the clipboard is empty', () async {
    final config = LlmConfig(
      id: 'config-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 1024,
      timeoutMs: 15000,
      systemPrompt: 'Translate with a concise style.',
      updatedAt: DateTime(2026, 4, 11),
    );
    final clipboardGateway = FakeClipboardGateway('   ');
    final configRepository = FakeLlmConfigRepository(config);
    final llmGateway = FakeLlmGateway();
    final overlayGateway = FakeOverlayGateway();
    final recordRepository = FakeRecordRepository();
    final useCase = TranslateClipboardUseCaseImpl(
      clipboardGateway: clipboardGateway,
      configRepository: configRepository,
      llmGateway: llmGateway,
      overlayGateway: overlayGateway,
      recordRepository: recordRepository,
      nowProvider: () => DateTime(2026, 4, 11, 12),
      idProvider: () => 'record-1',
      targetLang: 'zh',
      stylePreset: 'concise',
    );

    final result = await useCase.execute();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.code, 'clipboard_empty');
    expect(overlayGateway.lastError, isNotNull);
    expect(llmGateway.lastRequest, isNull);
    expect(recordRepository.savedRecords, isEmpty);
  });
}
