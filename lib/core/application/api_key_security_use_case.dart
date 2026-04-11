import 'use_case_result.dart';

abstract class ApiKeySecurityUseCase {
  Future<UseCaseResult<String>> store(String apiKey, {String? keyRef});

  Future<UseCaseResult<String>> load(String keyRef);

  Future<UseCaseResult<bool>> delete(String keyRef);
}
