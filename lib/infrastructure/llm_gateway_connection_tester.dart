import 'package:modeltranslation/core/domain/config/connection_test_result.dart';
import 'package:modeltranslation/core/domain/gateways/llm_connection_tester.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

class LlmGatewayConnectionTester implements LlmConnectionTester {
  LlmGatewayConnectionTester({
    required LlmGateway llmGateway,
    DateTime Function()? nowProvider,
  })  : _llmGateway = llmGateway,
        _nowProvider = nowProvider ?? DateTime.now;

  final LlmGateway _llmGateway;
  final DateTime Function() _nowProvider;

  @override
  Future<ConnectionTestResult> test(LlmConfig config) async {
    final startedAt = _nowProvider();
    try {
      await _llmGateway.translate(
        TranslationRequest(
          sourceText: 'Connection test',
          sourceLang: 'en',
          targetLang: 'zh',
          stylePreset: 'concise',
          configSnapshot: config,
        ),
      );
      final latency = _nowProvider().difference(startedAt).inMilliseconds;
      return ConnectionTestResult.success(
        provider: config.provider,
        model: config.model,
        endpoint: config.baseUrl,
        latencyMs: latency,
        message: 'Connection verified.',
      );
    } catch (_) {
      // Placeholder for future granular error mapping and user-facing diagnostics.
      return ConnectionTestResult.failure(
        provider: config.provider,
        model: config.model,
        endpoint: config.baseUrl,
        errorMessage: 'Connection failed.',
      );
    }
  }
}
