import 'dart:async';

import '../bridge/bridge_event.dart';
import 'bridge_event_router.dart';

class BridgeRuntime {
  BridgeRuntime({
    required Stream<BridgeEvent> events,
    required BridgeEventProcessor processor,
  })  : _events = events,
        _processor = processor;

  final Stream<BridgeEvent> _events;
  final BridgeEventProcessor _processor;
  StreamSubscription<BridgeEvent>? _subscription;

  Future<void> start() async {
    if (_subscription != null) {
      return;
    }

    _subscription = _events.listen((event) {
      unawaited(_processor.route(event));
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}