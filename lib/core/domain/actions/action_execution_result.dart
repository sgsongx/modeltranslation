class ActionExecutionResult {
  const ActionExecutionResult._({
    required this.isSuccess,
    required this.message,
    required this.errorCode,
    required this.errorMessage,
    required this.payload,
  });

  const ActionExecutionResult.success({
    required String message,
    Map<String, Object?>? payload,
  }) : this._(
          isSuccess: true,
          message: message,
          errorCode: null,
          errorMessage: null,
          payload: payload,
        );

  const ActionExecutionResult.failure({
    required String errorCode,
    required String errorMessage,
  }) : this._(
          isSuccess: false,
          message: null,
          errorCode: errorCode,
          errorMessage: errorMessage,
          payload: null,
        );

  final bool isSuccess;
  final String? message;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, Object?>? payload;
}
