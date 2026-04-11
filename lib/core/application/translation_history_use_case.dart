import '../domain/translation_record.dart';
import 'use_case_result.dart';

abstract class TranslationHistoryUseCase {
  Future<UseCaseResult<List<TranslationRecord>>> loadRecent({int limit = 50});

  Future<UseCaseResult<List<TranslationRecord>>> search(String query);

  Future<UseCaseResult<TranslationRecord?>> getById(String id);

  Future<UseCaseResult<int>> deleteById(String id);

  Future<UseCaseResult<int>> clearAll();
}
