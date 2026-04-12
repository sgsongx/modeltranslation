import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/translation_history_use_case_impl.dart';
import 'package:modeltranslation/core/domain/gateways/record_repository.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';

class InMemoryRecordRepository implements RecordRepository {
  final List<TranslationRecord> records = <TranslationRecord>[];

  @override
  Future<void> save(TranslationRecord record) async {
    records.removeWhere((existing) => existing.id == record.id);
    records.add(record);
  }

  @override
  Future<void> clearAll() async {
    records.clear();
  }

  @override
  Future<void> deleteById(String id) async {
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<TranslationRecord?> getById(String id) async {
    for (final record in records) {
      if (record.id == id) {
        return record;
      }
    }

    return null;
  }

  @override
  Future<List<TranslationRecord>> listRecent({int limit = 50}) async {
    final sorted = List<TranslationRecord>.from(records)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    return records.where((record) {
      return record.sourceText.toLowerCase().contains(normalizedQuery) ||
          record.translatedText.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}

TranslationRecord buildRecord({
  required String id,
  required String sourceText,
  required String translatedText,
  required DateTime createdAt,
}) {
  return TranslationRecord(
    id: id,
    sourceText: sourceText,
    translatedText: translatedText,
    provider: 'openai-compatible',
    model: 'gpt-4o-mini',
    paramsJson: '{"temperature":0.2}',
    status: TranslationStatus.success,
    errorMessage: null,
    createdAt: createdAt,
  );
}

void main() {
  test('TranslationHistoryUseCaseImpl loads recent records and detail records', () async {
    final repository = InMemoryRecordRepository();
    final olderRecord = buildRecord(
      id: 'record-1',
      sourceText: 'Hello world',
      translatedText: '你好，世界',
      createdAt: DateTime(2026, 4, 11, 10),
    );
    final newerRecord = buildRecord(
      id: 'record-2',
      sourceText: 'Good morning',
      translatedText: '早上好',
      createdAt: DateTime(2026, 4, 11, 11),
    );

    await repository.save(olderRecord);
    await repository.save(newerRecord);

    final useCase = TranslationHistoryUseCaseImpl(repository: repository);

    final recent = await useCase.loadRecent(limit: 1);
    final detail = await useCase.getById('record-1');

    expect(recent.isSuccess, isTrue);
    expect(recent.value, [newerRecord]);
    expect(detail.isSuccess, isTrue);
    expect(detail.value, olderRecord);
  });

  test('TranslationHistoryUseCaseImpl searches, deletes, and clears records', () async {
    final repository = InMemoryRecordRepository();
    final firstRecord = buildRecord(
      id: 'record-1',
      sourceText: 'Hello world',
      translatedText: '你好，世界',
      createdAt: DateTime(2026, 4, 11, 10),
    );
    final secondRecord = buildRecord(
      id: 'record-2',
      sourceText: 'Good morning',
      translatedText: '早上好',
      createdAt: DateTime(2026, 4, 11, 11),
    );

    await repository.save(firstRecord);
    await repository.save(secondRecord);

    final useCase = TranslationHistoryUseCaseImpl(repository: repository);

    final searchResult = await useCase.search('世界');
    final deleteResult = await useCase.deleteById('record-1');
    final clearResult = await useCase.clearAll();

    expect(searchResult.isSuccess, isTrue);
    expect(searchResult.value, [firstRecord]);
    expect(deleteResult.isSuccess, isTrue);
    expect(deleteResult.value, 1);
    expect(clearResult.isSuccess, isTrue);
    expect(clearResult.value, 1);
    expect(await repository.listRecent(), isEmpty);
  });
}
