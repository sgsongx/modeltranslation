import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/config/connection_test_result.dart';
import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/gateways/llm_connection_tester.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';

class FakeLlmConfigRepository implements LlmConfigRepository {
  final List<LlmConfig> savedConfigs = <LlmConfig>[];

  @override
  Future<LlmConfig?> loadActive() async {
    if (savedConfigs.isEmpty) {
      return null;
    }

    return savedConfigs.last;
  }

  @override
  Future<void> saveActive(LlmConfig config) async {
    savedConfigs.add(config);
  }
}

class FakeLlmConnectionTester implements LlmConnectionTester {
  @override
  Future<ConnectionTestResult> test(LlmConfig config) async {
    return ConnectionTestResult.success(
      provider: config.provider,
      model: config.model,
      endpoint: config.baseUrl,
      latencyMs: 128,
      message: 'Connection verified.',
    );
  }
}

void main() {
  test('LlmConfigRepository saves and loads the active config', () async {
    final repository = FakeLlmConfigRepository();
    final firstConfig = LlmConfig(
      id: 'config-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 1024,
      timeoutMs: 15000,
      systemPrompt: 'Translate with a concise style.',
      updatedAt: DateTime(2026, 4, 11),
    );
    final secondConfig = LlmConfig(
      id: 'config-2',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-2',
      model: 'gpt-4.1-mini',
      temperature: 0.1,
      topP: 1.0,
      maxTokens: 2048,
      timeoutMs: 12000,
      systemPrompt: 'Translate naturally.',
      updatedAt: DateTime(2026, 4, 11),
    );

    await repository.saveActive(firstConfig);
    await repository.saveActive(secondConfig);

    expect(await repository.loadActive(), secondConfig);
    expect(repository.savedConfigs, hasLength(2));
  });

  test('LlmConnectionTester returns a structured result', () async {
    final tester = FakeLlmConnectionTester();
    final config = LlmConfig(
      id: 'config-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 1024,
      timeoutMs: 15000,
      systemPrompt: 'Translate with a concise style.',
      updatedAt: DateTime(2026, 4, 11),
    );

    final result = await tester.test(config);

    expect(result.isSuccess, isTrue);
    expect(result.provider, 'openai-compatible');
    expect(result.model, 'gpt-4o-mini');
    expect(result.latencyMs, 128);
  });
}
