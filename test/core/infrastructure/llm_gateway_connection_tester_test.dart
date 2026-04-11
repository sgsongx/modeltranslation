import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/infrastructure/llm_gateway_connection_tester.dart';

class SuccessLlmGateway implements LlmGateway {
  @override
  Future<String> translate(TranslationRequest request) async {
    return 'ok';
  }
}

class FailureLlmGateway implements LlmGateway {
  @override
  Future<String> translate(TranslationRequest request) async {
    throw StateError('network down');
  }
}

LlmConfig _config() {
  return LlmConfig(
    id: 'cfg-1',
    provider: 'openai-compatible',
    baseUrl: 'https://api.example.com/v1',
    apiKeyRef: 'vault-ref-1',
    model: 'gpt-4o-mini',
    temperature: 0.2,
    topP: 0.9,
    maxTokens: 256,
    timeoutMs: 5000,
    systemPrompt: 'Translate accurately.',
    updatedAt: DateTime(2026, 4, 11),
  );
}

void main() {
  test('LlmGatewayConnectionTester returns success for reachable gateway', () async {
    final tester = LlmGatewayConnectionTester(llmGateway: SuccessLlmGateway());

    final result = await tester.test(_config());

    expect(result.isSuccess, isTrue);
    expect(result.message, 'Connection verified.');
    expect(result.latencyMs, isNotNull);
  });

  test('LlmGatewayConnectionTester returns generic failure for gateway errors', () async {
    final tester = LlmGatewayConnectionTester(llmGateway: FailureLlmGateway());

    final result = await tester.test(_config());

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, 'Connection failed.');
  });
}
