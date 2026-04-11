import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';
import 'package:modeltranslation/infrastructure/in_memory_secret_vault.dart';
import 'package:modeltranslation/infrastructure/vault_api_key_provider.dart';

TranslationRequest _requestWithKeyRef(String? keyRef) {
  return TranslationRequest(
    sourceText: 'Hello',
    sourceLang: 'en',
    targetLang: 'zh',
    stylePreset: null,
    configSnapshot: LlmConfig(
      id: 'cfg-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: keyRef,
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 256,
      timeoutMs: 3000,
      systemPrompt: 'Translate accurately.',
      updatedAt: DateTime(2026, 4, 11),
    ),
  );
}

void main() {
  test('VaultApiKeyProvider resolves key by apiKeyRef', () async {
    final vault = InMemorySecretVault();
    await vault.write('ref-1', 'secret-key-1');
    final provider = VaultApiKeyProvider(vault);

    final apiKey = await provider.resolve(_requestWithKeyRef('ref-1'));

    expect(apiKey, 'secret-key-1');
  });

  test('VaultApiKeyProvider returns null when apiKeyRef missing', () async {
    final provider = VaultApiKeyProvider(InMemorySecretVault());

    final apiKey = await provider.resolve(_requestWithKeyRef(null));

    expect(apiKey, isNull);
  });
}
