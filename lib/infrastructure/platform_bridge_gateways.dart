import 'package:modeltranslation/core/domain/gateways/clipboard_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/overlay_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/platform_bridge_gateway.dart';
import 'dart:convert';

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
  Future<void> showResult({
    required String sourceText,
    required String translatedText,
    required double fontSizeSp,
  }) async {
    final payload = <String, Object?>{
      'type': 'translation_result_v1',
      'sourceText': sourceText,
      'translatedText': translatedText,
      'fontSizeSp': fontSizeSp,
    };

    await _platformBridgeGateway.showOverlay(
      title: 'Translation Result',
      message: jsonEncode(payload),
    );
  }
}
