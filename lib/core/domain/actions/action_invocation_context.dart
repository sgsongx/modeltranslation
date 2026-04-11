class ActionInvocationContext {
  const ActionInvocationContext({
    required this.actionId,
    required this.payload,
    required this.createdAt,
  });

  final String actionId;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}
