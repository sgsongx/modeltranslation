enum BridgeCommandKind {
  showOverlay,
  hideOverlay,
  requestClipboard,
}

class BridgeCommand {
  const BridgeCommand._({
    required this.kind,
    required this.title,
    required this.message,
    required this.payload,
  });

  const BridgeCommand.showOverlay({
    required String title,
    required String message,
    Map<String, Object?>? payload,
  }) : this._(
          kind: BridgeCommandKind.showOverlay,
          title: title,
          message: message,
          payload: payload ?? const <String, Object?>{},
        );

  const BridgeCommand.hideOverlay({Map<String, Object?>? payload})
      : this._(
          kind: BridgeCommandKind.hideOverlay,
          title: null,
          message: null,
          payload: payload ?? const <String, Object?>{},
        );

  const BridgeCommand.requestClipboard({Map<String, Object?>? payload})
      : this._(
          kind: BridgeCommandKind.requestClipboard,
          title: null,
          message: null,
          payload: payload ?? const <String, Object?>{},
        );

  final BridgeCommandKind kind;
  final String? title;
  final String? message;
  final Map<String, Object?> payload;
}
