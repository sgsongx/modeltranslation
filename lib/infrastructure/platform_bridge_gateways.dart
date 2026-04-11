import 'package:modeltranslation/core/domain/gateways/clipboard_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/overlay_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/platform_bridge_gateway.dart';

class PlatformClipboardGateway implements ClipboardGateway {
  PlatformClipboardGateway(this._platformBridgeGateway);

  final PlatformBridgeGateway _platformBridgeGateway;

  @override
  Future<String?> readText() async {
    return _platformBridgeGateway.getClipboardText();
  }
}

class PlatformOverlayGateway implements OverlayGateway {
  PlatformOverlayGateway(this._platformBridgeGateway);

  final PlatformBridgeGateway _platformBridgeGateway;

  @override
  Future<void> showError(String message) async {
    await _platformBridgeGateway.showOverlay(
      title: 'Translation Error',
      message: message,
    );
  }

  @override
  Future<void> showResult(String translatedText) async {
    await _platformBridgeGateway.showOverlay(
      title: 'Translation Result',
      message: translatedText,
    );
  }
}
