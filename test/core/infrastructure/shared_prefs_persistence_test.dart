import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/infrastructure/shared_prefs_llm_config_repository.dart';
import 'package:modeltranslation/infrastructure/shared_prefs_secret_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

LlmConfig _config() {
  return LlmConfig(
    id: 'cfg-persistent',
    provider: 'openai-compatible',
    baseUrl: 'https://api.example.com/v1',
    apiKeyRef: 'active-api-key',
    model: 'gpt-4o-mini',
    temperature: 0.3,
    topP: 0.8,
    maxTokens: 640,
    timeoutMs: 18000,
    systemPrompt: 'Translate exactly.',
    updatedAt: DateTime(2026, 4, 12),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SharedPrefsLlmConfigRepository persists and reloads active config', () async {
    final writer = SharedPrefsLlmConfigRepository();
    final config = _config();

    await writer.saveActive(config);

    final reader = SharedPrefsLlmConfigRepository();
    final loaded = await reader.loadActive();

    expect(loaded, isNotNull);
    expect(loaded!.baseUrl, config.baseUrl);
    expect(loaded.apiKeyRef, config.apiKeyRef);
    expect(loaded.model, config.model);
    expect(loaded.maxTokens, config.maxTokens);
  });

  test('SharedPrefsSecretVault persists and reads secrets', () async {
    final writer = SharedPrefsSecretVault();
    await writer.write('active-api-key', 'secret-value');

    final reader = SharedPrefsSecretVault();
    final loaded = await reader.read('active-api-key');

    expect(loaded, 'secret-value');
  });
}
