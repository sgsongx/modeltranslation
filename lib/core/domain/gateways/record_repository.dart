import '../translation_record.dart';

abstract class RecordRepository {
  Future<void> save(TranslationRecord record);

  Future<List<TranslationRecord>> listRecent({int limit = 50});

  Future<TranslationRecord?> getById(String id);

  Future<List<TranslationRecord>> search(String query);

  Future<void> deleteById(String id);

  Future<void> clearAll();
}