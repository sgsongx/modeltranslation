import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

import 'debug_trace_logger.dart';

class DebugLlmGateway implements LlmGateway {
  DebugLlmGateway(
    LlmGateway innerGateway, {
    required DebugTraceLogger logger,
  })  : _innerGateway = innerGateway,
        _logger = logger;

  final LlmGateway _innerGateway;
  final DebugTraceLogger _logger;

  @override
  Future<String> translate(TranslationRequest request) async {
    _trace('llm.translate:start provider=${request.configSnapshot.provider} model=${request.configSnapshot.model} target=${request.targetLang} sourceLength=${request.sourceText.length}');
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _innerGateway.translate(request);
      stopwatch.stop();
      _trace('llm.translate:success durationMs=${stopwatch.elapsedMilliseconds} resultLength=${result.length}');
      return result;
    } catch (error) {
      stopwatch.stop();
      _trace('llm.translate:error durationMs=${stopwatch.elapsedMilliseconds} error=${error.runtimeType}');
      rethrow;
    }
  }

  void _trace(String message) {
    if (_logger.enabled) {
      _logger.log(message);
    }
  }
}
