import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

class MockLlmGateway implements LlmGateway {
  @override
  Future<String> translate(TranslationRequest request) async {
    final source = request.sourceText.trim();
    if (source.isEmpty) {
      return '';
    }

    return source;
  }
}
