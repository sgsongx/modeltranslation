class ConnectionTestResult {
  const ConnectionTestResult.success({
    required this.provider,
    required this.model,
    required this.endpoint,
    required this.latencyMs,
    required this.message,
  })  : errorMessage = null,
        isSuccess = true;

  const ConnectionTestResult.failure({
    required this.provider,
    required this.model,
    required this.endpoint,
    required this.errorMessage,
  })  : latencyMs = null,
        message = null,
        isSuccess = false;

  final String provider;
  final String model;
  final String endpoint;
  final int? latencyMs;
  final String? message;
  final String? errorMessage;
  final bool isSuccess;
}
