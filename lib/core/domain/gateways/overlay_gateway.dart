abstract class OverlayGateway {
  Future<void> showResult(String translatedText);

  Future<void> showError(String message);
}