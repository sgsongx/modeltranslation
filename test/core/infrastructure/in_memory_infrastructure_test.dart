import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:modeltranslation/infrastructure/in_memory_llm_config_repository.dart';
import 'package:modeltranslation/infrastructure/in_memory_record_repository.dart';
import 'package:modeltranslation/infrastructure/mock_llm_connection_tester.dart';

LlmConfig buildConfig({required String baseUrl, required String? apiKeyRef}) {
  return LlmConfig(
    id: 'active-config',
    provider: 'openai-compatible',
    baseUrl: baseUrl,
    apiKeyRef: apiKeyRef,
    model: 'gpt-4o-mini',
    temperature: 0.2,
    topP: 0.9,
    maxTokens: 1024,
    timeoutMs: 15000,
    systemPrompt: 'Translate with a concise style.',
    updatedAt: DateTime(2026, 4, 11),
  );
}

TranslationRecord buildRecord({required String id, required DateTime createdAt}) {
  return TranslationRecord(
    id: id,
    sourceText: 'Hello world',
    translatedText: '你好，世界',
    provider: 'openai-compatible',
    model: 'gpt-4o-mini',
    paramsJson: '{"temperature":0.2}',
    status: TranslationStatus.success,
    errorMessage: null,
    createdAt: createdAt,
  );
}

void main() {
  test('InMemoryLlmConfigRepository loads and saves active config', () async {
    final repository = InMemoryLlmConfigRepository();

    expect(await repository.loadActive(), isNull);

    final config = buildConfig(
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
    );
    await repository.saveActive(config);

    expect(await repository.loadActive(), isNotNull);
    expect((await repository.loadActive())!.baseUrl, 'https://api.example.com/v1');
  });

  test('MockLlmConnectionTester returns success for valid config and failure for invalid config', () async {
    final tester = MockLlmConnectionTester();

    final success = await tester.test(
      buildConfig(
        baseUrl: 'https://api.example.com/v1',
        apiKeyRef: 'secure-ref-1',
      ),
    );
    final failure = await tester.test(
      buildConfig(
        baseUrl: '',
        apiKeyRef: null,
      ),
    );

    expect(success.isSuccess, isTrue);
    expect(success.message, isNotNull);
    expect(failure.isSuccess, isFalse);
    expect(failure.errorMessage, isNotNull);
  });

  test('InMemoryRecordRepository supports save/list/search/delete/clear', () async {
    final repository = InMemoryRecordRepository();
    final older = buildRecord(id: 'record-1', createdAt: DateTime(2026, 4, 11, 10));
    final newer = buildRecord(id: 'record-2', createdAt: DateTime(2026, 4, 11, 11));

    await repository.save(older);
    await repository.save(newer);

    expect(await repository.listRecent(limit: 1), [newer]);
    expect((await repository.search('你好')).length, 2);

    await repository.deleteById('record-1');
    expect(await repository.getById('record-1'), isNull);

    await repository.clearAll();
    expect(await repository.listRecent(), isEmpty);
  });
}
