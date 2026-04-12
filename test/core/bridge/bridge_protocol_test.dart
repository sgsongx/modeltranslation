import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/bridge/bridge_command.dart';
import 'package:modeltranslation/core/bridge/bridge_event.dart';
import 'package:modeltranslation/core/bridge/bridge_protocol.dart';

void main() {
  test('BridgeProtocol encodes and decodes action events', () {
    final event = BridgeEvent.action(
      actionId: 'translate_clipboard',
      payload: {'text': 'Hello world'},
      createdAt: DateTime(2026, 4, 11, 12, 30),
    );

    final encoded = BridgeProtocol.encodeEvent(event);
    final decoded = BridgeProtocol.decodeEvent(encoded);

    expect(decoded.kind, BridgeEventKind.action);
    expect(decoded.actionId, 'translate_clipboard');
    expect(decoded.payload['text'], 'Hello world');
    expect(decoded.createdAt, DateTime(2026, 4, 11, 12, 30));
  });

  test('BridgeProtocol encodes overlay commands', () {
    final command = BridgeCommand.showOverlay(
      title: 'Translation ready',
      message: '你好，世界',
    );

    final encoded = BridgeProtocol.encodeCommand(command);
    final decoded = BridgeProtocol.decodeCommand(encoded);

    expect(decoded.kind, BridgeCommandKind.showOverlay);
    expect(decoded.title, 'Translation ready');
    expect(decoded.message, '你好，世界');
  });

  test('BridgeProtocol decodes action events with epoch millis createdAt', () {
    final decoded = BridgeProtocol.decodeEvent(<String, Object?>{
      'kind': 'action',
      'actionId': 'translate_clipboard',
      'payload': <String, Object?>{'source': 'floating_bubble'},
      'createdAt': '1775962818715',
    });

    expect(decoded.kind, BridgeEventKind.action);
    expect(decoded.actionId, 'translate_clipboard');
    expect(decoded.payload['source'], 'floating_bubble');
    expect(decoded.createdAt.millisecondsSinceEpoch, 1775962818715);
  });

  test('BridgeProtocol rejects invalid payloads', () {
    expect(
      () => BridgeProtocol.decodeEvent(<String, Object?>{'kind': 'unknown'}),
      throwsFormatException,
    );
  });
}
