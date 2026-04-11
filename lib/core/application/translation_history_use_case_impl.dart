import '../domain/gateways/record_repository.dart';
import '../domain/translation_record.dart';
import 'translation_history_use_case.dart';
import 'use_case_result.dart';

class TranslationHistoryUseCaseImpl implements TranslationHistoryUseCase {
  TranslationHistoryUseCaseImpl({required RecordRepository repository})
      : _repository = repository;

  final RecordRepository _repository;

  @override
  Future<UseCaseResult<List<TranslationRecord>>> loadRecent({int limit = 50}) async {
    final records = await _repository.listRecent(limit: limit);
    return UseCaseResult.success(records);
  }

  @override
  Future<UseCaseResult<List<TranslationRecord>>> search(String query) async {
    final records = await _repository.search(query);
    return UseCaseResult.success(records);
  }

  @override
  Future<UseCaseResult<TranslationRecord?>> getById(String id) async {
    final record = await _repository.getById(id);
    if (record == null) {
      return UseCaseResult.failure(
        const UseCaseFailure(
          code: 'record_not_found',
          message: 'Translation record was not found.',
        ),
      );
    }

    return UseCaseResult.success(record);
  }

  @override
  Future<UseCaseResult<int>> deleteById(String id) async {
    final record = await _repository.getById(id);
    if (record == null) {
      return UseCaseResult.failure(
        const UseCaseFailure(
          code: 'record_not_found',
          message: 'Translation record was not found.',
        ),
      );
    }

    await _repository.deleteById(id);
    return UseCaseResult.success(1);
  }

  @override
  Future<UseCaseResult<int>> clearAll() async {
    final records = await _repository.listRecent(limit: 1000000);
    final count = records.length;
    await _repository.clearAll();
    return UseCaseResult.success(count);
  }
}
