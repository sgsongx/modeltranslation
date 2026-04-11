import 'package:modeltranslation/core/domain/config/connection_test_result.dart';
import 'package:modeltranslation/core/domain/gateways/llm_connection_tester.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';

class MockLlmConnectionTester implements LlmConnectionTester {
  @override
  Future<ConnectionTestResult> test(LlmConfig config) async {
    final hasBaseUrl = config.baseUrl.trim().isNotEmpty;
    final hasApiRef = (config.apiKeyRef ?? '').trim().isNotEmpty;
    final hasModel = config.model.trim().isNotEmpty;

    if (hasBaseUrl && hasApiRef && hasModel) {
      return ConnectionTestResult.success(
        provider: config.provider,
        model: config.model,
        endpoint: config.baseUrl,
        latencyMs: 120,
        message: 'Connection verified.',
      );
    }

    return ConnectionTestResult.failure(
      provider: config.provider,
      model: config.model,
      endpoint: config.baseUrl,
      errorMessage: 'Connection failed: missing required fields.',
    );
  }
}
