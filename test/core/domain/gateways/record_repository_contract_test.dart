import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/gateways/record_repository.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';

class InMemoryRecordRepository implements RecordRepository {
  final List<TranslationRecord> _records = <TranslationRecord>[];

  @override
  Future<void> save(TranslationRecord record) async {
    _records.removeWhere((existing) => existing.id == record.id);
    _records.add(record);
  }

  @override
  Future<void> clearAll() async {
    _records.clear();
  }

  @override
  Future<void> deleteById(String id) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<TranslationRecord?> getById(String id) async {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }

    return null;
  }

  @override
  Future<List<TranslationRecord>> listRecent({int limit = 50}) async {
    final records = List<TranslationRecord>.from(_records)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return records.take(limit).toList();
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    return _records.where((record) {
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
  test('RecordRepository can save, load, and list recent records', () async {
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

    expect(await repository.getById('record-1'), olderRecord);
    expect(await repository.listRecent(limit: 1), [newerRecord]);
  });

  test('RecordRepository can search, delete, and clear records', () async {
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

    expect(await repository.search('世界'), [firstRecord]);

    await repository.deleteById('record-1');
    expect(await repository.getById('record-1'), isNull);

    await repository.clearAll();
    expect(await repository.listRecent(), isEmpty);
  });
}
