import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/gateways/platform_bridge_gateway.dart';
import 'bridge_event.dart';
import 'bridge_protocol.dart';

class MethodChannelPlatformBridgeGateway implements PlatformBridgeGateway {
  MethodChannelPlatformBridgeGateway({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel('modeltranslation/platform'),
        _eventChannel = eventChannel ?? const EventChannel('modeltranslation/action_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Future<BridgeCapabilities> getCapabilities() async {
    final result = await _methodChannel.invokeMapMethod<String, Object?>(
      'getBridgeCapabilities',
    );
    final data = result ?? const <String, Object?>{};
    return BridgeCapabilities(
      methodChannelName: data['methodChannel'] as String? ?? 'modeltranslation/platform',
      eventChannelName: data['eventChannel'] as String? ?? 'modeltranslation/action_events',
      supportsClipboard: data['supportsClipboard'] as bool? ?? false,
      supportsOverlay: data['supportsOverlay'] as bool? ?? false,
      supportsFloatingBubble: data['supportsFloatingBubble'] as bool? ?? false,
    );
  }

  @override
  Future<String?> getClipboardText() async {
    return _methodChannel.invokeMethod<String>('getClipboardText');
  }

  @override
  Future<void> hideOverlay() async {
    await _methodChannel.invokeMethod<void>('hideOverlay');
  }

  @override
  Future<void> showOverlay({required String title, required String message}) async {
    await _methodChannel.invokeMethod<void>('showOverlay', <String, Object?>{
      'title': title,
      'message': message,
    });
  }

  @override
  Future<void> startFloatingBubble() async {
    await _methodChannel.invokeMethod<void>('startFloatingBubble');
  }

  @override
  Future<void> stopFloatingBubble() async {
    await _methodChannel.invokeMethod<void>('stopFloatingBubble');
  }

  @override
  Stream<BridgeEvent> watchActionEvents() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return BridgeProtocol.decodeEvent(Map<Object?, Object?>.from(event as Map));
    });
  }
}