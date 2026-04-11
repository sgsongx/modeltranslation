enum ActionResultStatus {
  pending,
  success,
  failure,
}

class ActionEvent {
  const ActionEvent({
    required this.id,
    required this.actionId,
    required this.payloadJson,
    required this.resultStatus,
    required this.createdAt,
  });

  final String id;
  final String actionId;
  final String payloadJson;
  final ActionResultStatus resultStatus;
  final DateTime createdAt;
}