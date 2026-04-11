import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/bridge_runtime.dart';
import 'package:modeltranslation/core/application/bridge_event_router.dart';
import 'package:modeltranslation/core/bridge/bridge_event.dart';

class RecordingBridgeProcessor implements BridgeEventProcessor {
  final List<BridgeEvent> handledEvents = <BridgeEvent>[];

  @override
  Future<BridgeRouteResult> route(BridgeEvent event) async {
    handledEvents.add(event);
    return const BridgeRouteResult.ignored('recorded');
  }
}

void main() {
  test('BridgeRuntime forwards action events to the processor', () async {
    final controller = StreamController<BridgeEvent>();
    final processor = RecordingBridgeProcessor();
    final runtime = BridgeRuntime(
      events: controller.stream,
      processor: processor,
    );

    await runtime.start();
    controller.add(
      BridgeEvent.action(
        actionId: 'translate_clipboard',
        payload: {'text': 'Hello world'},
        createdAt: DateTime(2026, 4, 11),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(processor.handledEvents, hasLength(1));
    expect(processor.handledEvents.single.actionId, 'translate_clipboard');

    await runtime.dispose();
    controller.add(
      BridgeEvent.action(
        actionId: 'rewrite_clipboard',
        payload: {'text': 'Hello world'},
        createdAt: DateTime(2026, 4, 11),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(processor.handledEvents, hasLength(1));

    await controller.close();
  });
}
