import 'package:modeltranslation/core/domain/config/connection_test_result.dart';
import 'package:modeltranslation/core/domain/gateways/llm_connection_tester.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';
import 'package:modeltranslation/infrastructure/debug_trace_logger.dart';

class LlmGatewayConnectionTester implements LlmConnectionTester {
  LlmGatewayConnectionTester({
    required LlmGateway llmGateway,
    DateTime Function()? nowProvider,
    DebugTraceLogger? debugLogger,
  })  : _llmGateway = llmGateway,
        _nowProvider = nowProvider ?? DateTime.now,
        _debugLogger = debugLogger ?? DebugTraceLogger.disabled();

  final LlmGateway _llmGateway;
  final DateTime Function() _nowProvider;
  final DebugTraceLogger _debugLogger;

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
    } catch (error, stackTrace) {
      _debugLogger.log(
        'llm.connection-test:failure provider=${config.provider} model=${config.model} endpoint=${config.baseUrl} error=$error',
      );
      if (_debugLogger.enabled) {
        _debugLogger.log('llm.connection-test:stacktrace $stackTrace');
      }

      return ConnectionTestResult.failure(
        provider: config.provider,
        model: config.model,
        endpoint: config.baseUrl,
        errorMessage: _buildFailureMessage(error),
      );
    }
  }

  String _buildFailureMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'Connection failed.';
    }

    return 'Connection failed: $raw';
  }
}
