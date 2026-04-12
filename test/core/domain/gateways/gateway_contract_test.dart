import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/gateways/clipboard_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/overlay_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/record_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

class FakeClipboardGateway implements ClipboardGateway {
  @override
  Future<String?> readText() async => 'Hello world';
}

class FakeLlmGateway implements LlmGateway {
  @override
  Future<String> translate(TranslationRequest request) async {
    return '你好，世界';
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
  test('ClipboardGateway can read clipboard text', () async {
    final gateway = FakeClipboardGateway();

    expect(await gateway.readText(), 'Hello world');
  });

  test('LlmGateway can translate a request payload', () async {
    final gateway = FakeLlmGateway();
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

    final result = await gateway.translate(
      TranslationRequest(
        sourceText: 'Hello world',
        sourceLang: 'en',
        targetLang: 'zh',
        stylePreset: 'concise',
        configSnapshot: config,
      ),
    );

    expect(result, '你好，世界');
  });

  test('OverlayGateway can show results and errors', () async {
    final gateway = FakeOverlayGateway();

    await gateway.showResult('你好，世界');
    await gateway.showError('timeout');

    expect(gateway.lastResult, '你好，世界');
    expect(gateway.lastError, 'timeout');
  });

  test('RecordRepository can persist translation records', () async {
    final repository = FakeRecordRepository();
    final record = TranslationRecord(
      id: 'record-1',
      sourceText: 'Hello world',
      translatedText: '你好，世界',
      provider: 'openai-compatible',
      model: 'gpt-4o-mini',
      paramsJson: '{"temperature":0.2}',
      status: TranslationStatus.success,
      errorMessage: null,
      createdAt: DateTime(2026, 4, 11),
    );

    await repository.save(record);

    expect(repository.savedRecords, hasLength(1));
    expect(repository.savedRecords.single.id, 'record-1');
  });
}