import '../domain/gateways/secret_vault.dart';
import 'api_key_security_use_case.dart';
import 'use_case_result.dart';

class ApiKeySecurityUseCaseImpl implements ApiKeySecurityUseCase {
  ApiKeySecurityUseCaseImpl({
    required SecretVault vault,
    required String Function() keyRefProvider,
  })  : _vault = vault,
        _keyRefProvider = keyRefProvider;

  final SecretVault _vault;
  final String Function() _keyRefProvider;

  @override
  Future<UseCaseResult<String>> store(String apiKey, {String? keyRef}) async {
    final trimmedApiKey = apiKey.trim();
    if (trimmedApiKey.isEmpty) {
      return UseCaseResult.failure(
        const UseCaseFailure(
          code: 'api_key_empty',
          message: 'API key is empty.',
        ),
      );
    }

    final resolvedKeyRef = keyRef ?? _keyRefProvider();
    await _vault.write(resolvedKeyRef, trimmedApiKey);
    return UseCaseResult.success(resolvedKeyRef);
  }

  @override
  Future<UseCaseResult<String>> load(String keyRef) async {
    final apiKey = await _vault.read(keyRef);
    if (apiKey == null) {
      return UseCaseResult.failure(
        const UseCaseFailure(
          code: 'api_key_missing',
          message: 'API key was not found.',
        ),
      );
    }

    return UseCaseResult.success(apiKey);
  }

  @override
  Future<UseCaseResult<bool>> delete(String keyRef) async {
    final apiKey = await _vault.read(keyRef);
    if (apiKey == null) {
      return UseCaseResult.failure(
        const UseCaseFailure(
          code: 'api_key_missing',
          message: 'API key was not found.',
        ),
      );
    }

    await _vault.delete(keyRef);
    return UseCaseResult.success(true);
  }
}
