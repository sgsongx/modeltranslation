class LlmConfig {
  const LlmConfig({
    required this.id,
    required this.provider,
    required this.baseUrl,
    required this.apiKeyRef,
    required this.model,
    required this.temperature,
    required this.topP,
    required this.maxTokens,
    required this.timeoutMs,
    required this.systemPrompt,
    this.overlayFontSizeSp = 15.0,
    required this.updatedAt,
  });

  final String id;
  final String provider;
  final String baseUrl;
  final String? apiKeyRef;
  final String model;
  final double temperature;
  final double topP;
  final int maxTokens;
  final int timeoutMs;
  final String systemPrompt;
  final double overlayFontSizeSp;
  final DateTime updatedAt;
}