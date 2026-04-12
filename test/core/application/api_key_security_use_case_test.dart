import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/api_key_security_use_case_impl.dart';
import 'package:modeltranslation/core/domain/gateways/secret_vault.dart';

class InMemorySecretVault implements SecretVault {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

void main() {
  test('ApiKeySecurityUseCaseImpl stores and loads a secret key', () async {
    final vault = InMemorySecretVault();
    final useCase = ApiKeySecurityUseCaseImpl(
      vault: vault,
      keyRefProvider: () => 'api-key-1',
    );

    final storeResult = await useCase.store('secret-api-key');
    final loadResult = await useCase.load('api-key-1');

    expect(storeResult.isSuccess, isTrue);
    expect(storeResult.value, 'api-key-1');
    expect(loadResult.isSuccess, isTrue);
    expect(loadResult.value, 'secret-api-key');
  });

  test('ApiKeySecurityUseCaseImpl deletes a stored secret key', () async {
    final vault = InMemorySecretVault();
    final useCase = ApiKeySecurityUseCaseImpl(
      vault: vault,
      keyRefProvider: () => 'api-key-1',
    );

    await useCase.store('secret-api-key');
    final deleteResult = await useCase.delete('api-key-1');
    final loadAfterDelete = await useCase.load('api-key-1');

    expect(deleteResult.isSuccess, isTrue);
    expect(deleteResult.value, isTrue);
    expect(loadAfterDelete.isSuccess, isFalse);
    expect(loadAfterDelete.failure?.code, 'api_key_missing');
  });
}
