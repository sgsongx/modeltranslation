abstract class OverlayGateway {
  Future<void> showResult({
    required String sourceText,
    required String translatedText,
    required double fontSizeSp,
  });

  Future<void> showError(String message);
}