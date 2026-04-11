import 'package:modeltranslation/core/domain/gateways/clipboard_gateway.dart';

import 'debug_trace_logger.dart';

class DebugTranslateClipboardGateway implements ClipboardGateway {
  DebugTranslateClipboardGateway(
    ClipboardGateway innerGateway, {
    required DebugTraceLogger logger,
  })  : _innerGateway = innerGateway,
        _logger = logger;

  final ClipboardGateway _innerGateway;
  final DebugTraceLogger _logger;

  @override
  Future<String?> readText() async {
    _trace('clipboard.read:start');
    try {
      final value = await _innerGateway.readText();
      _trace('clipboard.read:success length=${value?.length ?? 0}');
      return value;
    } catch (error) {
      _trace('clipboard.read:error ${error.runtimeType}');
      rethrow;
    }
  }

  void _trace(String message) {
    if (_logger.enabled) {
      _logger.log(message);
    }
  }
}
