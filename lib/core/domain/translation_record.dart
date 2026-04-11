enum TranslationStatus {
  pending,
  success,
  failure,
}

class TranslationRecord {
  const TranslationRecord({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.provider,
    required this.model,
    required this.paramsJson,
    required this.status,
    required this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String sourceText;
  final String translatedText;
  final String provider;
  final String model;
  final String paramsJson;
  final TranslationStatus status;
  final String? errorMessage;
  final DateTime createdAt;
}