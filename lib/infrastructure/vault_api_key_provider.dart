import 'package:modeltranslation/core/domain/gateways/secret_vault.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

class VaultApiKeyProvider {
  VaultApiKeyProvider(this._secretVault);

  final SecretVault _secretVault;

  Future<String?> resolve(TranslationRequest request) async {
    final keyRef = request.configSnapshot.apiKeyRef?.trim();
    if (keyRef == null || keyRef.isEmpty) {
      return null;
    }

    final apiKey = await _secretVault.read(keyRef);
    return apiKey?.trim();
  }
}
