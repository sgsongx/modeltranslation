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
    final sorted = List<TranslationRecord>.from(_records)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    final normalized = query.toLowerCase();
    return _records.where((record) {
      return record.sourceText.toLowerCase().contains(normalized) ||
          record.translatedText.toLowerCase().contains(normalized);
    }).toList();
  }
}
