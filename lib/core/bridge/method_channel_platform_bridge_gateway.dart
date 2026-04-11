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
  bool _diagnosticsEnabled = false;

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
    _trace('platform.clipboard.read:start');
    return _methodChannel.invokeMethod<String>('getClipboardText');
  }

  @override
  Future<bool> hasOverlayPermissionGranted() async {
    return await _methodChannel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  @override
  Future<void> hideOverlay() async {
    _trace('platform.overlay.hide:start');
    await _methodChannel.invokeMethod<void>('hideOverlay');
  }

  @override
  Future<void> openOverlayPermissionSettings() async {
    await _methodChannel.invokeMethod<void>('openOverlayPermissionSettings');
  }

  @override
  Future<void> setDiagnosticsEnabled(bool enabled) async {
    _diagnosticsEnabled = enabled;
    await _methodChannel.invokeMethod<void>('setDiagnosticsEnabled', enabled);
    _trace('diagnostics.enabled=$enabled');
  }

  @override
  Future<void> showOverlay({required String title, required String message}) async {
    _trace('platform.overlay.show:start title=$title messageLength=${message.length}');
    await _methodChannel.invokeMethod<void>('showOverlay', <String, Object?>{
      'title': title,
      'message': message,
    });
  }

  @override
  Future<void> startFloatingBubble() async {
    _trace('platform.bubble.start:start');
    await _methodChannel.invokeMethod<void>('startFloatingBubble');
  }

  @override
  Future<void> stopFloatingBubble() async {
    _trace('platform.bubble.stop:start');
    await _methodChannel.invokeMethod<void>('stopFloatingBubble');
  }

  @override
  Stream<BridgeEvent> watchActionEvents() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      _trace('platform.event.receive');
      return BridgeProtocol.decodeEvent(Map<Object?, Object?>.from(event as Map));
    });
  }

  void _trace(String message) {
    if (_diagnosticsEnabled) {
      // Keep platform traces simple and synchronous so they are safe during bridge calls.
      // ignore: avoid_print
      print(message);
    }
  }
}