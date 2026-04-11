import '../bridge/bridge_event.dart';
import '../domain/actions/action_execution_result.dart';
import '../domain/actions/action_invocation_context.dart';
import 'action_registry.dart';

class BridgeRouteResult {
  const BridgeRouteResult._({
    required this.handled,
    required this.message,
    required this.actionResult,
  });

  const BridgeRouteResult.handled(ActionExecutionResult actionResult)
      : this._(
          handled: true,
          message: null,
          actionResult: actionResult,
        );

  const BridgeRouteResult.ignored(String message)
      : this._(
          handled: false,
          message: message,
          actionResult: null,
        );

  final bool handled;
  final String? message;
  final ActionExecutionResult? actionResult;
}

class BridgeEventRouter {
  BridgeEventRouter({required ActionRegistry actionRegistry})
      : _actionRegistry = actionRegistry;

  final ActionRegistry _actionRegistry;

  Future<BridgeRouteResult> route(BridgeEvent event) async {
    if (event.kind != BridgeEventKind.action) {
      return const BridgeRouteResult.ignored('event_ignored');
    }

    final actionResult = await _actionRegistry.execute(
      event.actionId,
      context: ActionInvocationContext(
        actionId: event.actionId,
        payload: event.payload,
        createdAt: event.createdAt,
      ),
    );

    return BridgeRouteResult.handled(actionResult);
  }
}
