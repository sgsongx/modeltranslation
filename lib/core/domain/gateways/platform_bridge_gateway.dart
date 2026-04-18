import '../../bridge/bridge_event.dart';

class BridgeCapabilities {
  const BridgeCapabilities({
    required this.methodChannelName,
    required this.eventChannelName,
    required this.supportsClipboard,
    required this.supportsOverlay,
    required this.supportsFloatingBubble,
  });

  final String methodChannelName;
  final String eventChannelName;
  final bool supportsClipboard;
  final bool supportsOverlay;
  final bool supportsFloatingBubble;
}

abstract class PlatformBridgeGateway {
  Future<BridgeCapabilities> getCapabilities();

  Future<String?> getClipboardText();

  Future<bool> hasOverlayPermissionGranted();

  Future<void> openOverlayPermissionSettings();

  Future<void> setDiagnosticsEnabled(bool enabled);

  Future<double> getOverlayFontSizeSp();

  Future<void> setOverlayFontSizeSp(double value);

  Future<void> startFloatingBubble();

  Future<void> stopFloatingBubble();

  Future<void> moveAppToBackground();

  Future<void> showOverlay({required String title, required String message});

  Future<void> hideOverlay();

  Stream<BridgeEvent> watchActionEvents();
}