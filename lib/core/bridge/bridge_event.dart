enum BridgeEventKind {
  action,
  overlay,
  lifecycle,
}

class BridgeEvent {
  const BridgeEvent._({
    required this.kind,
    required this.actionId,
    required this.payload,
    required this.createdAt,
  });

  const BridgeEvent.action({
    required String actionId,
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) : this._(
          kind: BridgeEventKind.action,
          actionId: actionId,
          payload: payload,
          createdAt: createdAt,
        );

  const BridgeEvent.overlay({
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) : this._(
          kind: BridgeEventKind.overlay,
          actionId: 'overlay',
          payload: payload,
          createdAt: createdAt,
        );

  const BridgeEvent.lifecycle({
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) : this._(
          kind: BridgeEventKind.lifecycle,
          actionId: 'lifecycle',
          payload: payload,
          createdAt: createdAt,
        );

  final BridgeEventKind kind;
  final String actionId;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}
