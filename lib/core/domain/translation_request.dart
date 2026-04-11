import 'llm_config.dart';

class TranslationRequest {
  const TranslationRequest({
    required this.sourceText,
    required this.sourceLang,
    required this.targetLang,
    required this.stylePreset,
    required this.configSnapshot,
  });

  final String sourceText;
  final String? sourceLang;
  final String targetLang;
  final String? stylePreset;
  final LlmConfig configSnapshot;
}