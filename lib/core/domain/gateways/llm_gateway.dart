import '../translation_request.dart';

abstract class LlmGateway {
  Future<String> translate(TranslationRequest request);
}