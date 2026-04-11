import '../domain/actions/action_definition.dart';
import '../domain/actions/action_execution_result.dart';
import '../domain/actions/action_invocation_context.dart';

class ActionRegistry {
  final Map<String, ActionDefinition> _actions = <String, ActionDefinition>{};

  void register(ActionDefinition definition) {
    _actions[definition.actionId] = definition;
  }

  ActionDefinition? resolve(String actionId) {
    return _actions[actionId];
  }

  Future<ActionExecutionResult> execute(
    String actionId, {
    required ActionInvocationContext context,
  }) async {
    final definition = _actions[actionId];
    if (definition == null) {
      return const ActionExecutionResult.failure(
        errorCode: 'action_not_found',
        errorMessage: 'Action was not found.',
      );
    }

    if (!definition.enabled) {
      return const ActionExecutionResult.failure(
        errorCode: 'action_disabled',
        errorMessage: 'Action is disabled.',
      );
    }

    return definition.execute(context);
  }
}
