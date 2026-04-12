import 'bridge_command.dart';
import 'bridge_event.dart';

class BridgeProtocol {
  static Map<String, Object?> encodeEvent(BridgeEvent event) {
    return <String, Object?>{
      'kind': event.kind.name,
      'actionId': event.actionId,
      'payload': event.payload,
      'createdAt': event.createdAt.toIso8601String(),
    };
  }

  static BridgeEvent decodeEvent(Map<Object?, Object?> data) {
    final kindValue = data['kind'];
    final actionId = data['actionId'] as String?;
    final payload = _readPayload(data['payload']);
    final createdAtValue = data['createdAt'];

    if (kindValue is! String || actionId == null || createdAtValue == null) {
      throw const FormatException('Invalid bridge event payload.');
    }

    final createdAt = _parseCreatedAt(createdAtValue);
    switch (kindValue) {
      case 'action':
        return BridgeEvent.action(
          actionId: actionId,
          payload: payload,
          createdAt: createdAt,
        );
      case 'overlay':
        return BridgeEvent.overlay(
          payload: payload,
          createdAt: createdAt,
        );
      case 'lifecycle':
        return BridgeEvent.lifecycle(
          payload: payload,
          createdAt: createdAt,
        );
      default:
        throw const FormatException('Unknown bridge event kind.');
    }
  }

  static Map<String, Object?> encodeCommand(BridgeCommand command) {
    return <String, Object?>{
      'kind': command.kind.name,
      'title': command.title,
      'message': command.message,
      'payload': command.payload,
    };
  }

  static BridgeCommand decodeCommand(Map<Object?, Object?> data) {
    final kindValue = data['kind'];
    final title = data['title'] as String?;
    final message = data['message'] as String?;
    final payload = _readPayload(data['payload']);

    if (kindValue is! String) {
      throw const FormatException('Invalid bridge command payload.');
    }

    switch (kindValue) {
      case 'showOverlay':
        if (title == null || message == null) {
          throw const FormatException('Overlay command is missing fields.');
        }
        return BridgeCommand.showOverlay(
          title: title,
          message: message,
          payload: payload,
        );
      case 'hideOverlay':
        return BridgeCommand.hideOverlay(payload: payload);
      case 'requestClipboard':
        return BridgeCommand.requestClipboard(payload: payload);
      default:
        throw const FormatException('Unknown bridge command kind.');
    }
  }

  static Map<String, Object?> _readPayload(Object? payload) {
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value as Object?));
    }

    return <String, Object?>{};
  }

  static DateTime _parseCreatedAt(Object value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        throw const FormatException('Invalid date format');
      }

      final epochMillis = int.tryParse(normalized);
      if (epochMillis != null) {
        return DateTime.fromMillisecondsSinceEpoch(epochMillis);
      }

      return DateTime.parse(normalized);
    }

    throw const FormatException('Invalid date format');
  }
}
