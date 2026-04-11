import 'action_execution_result.dart';
import 'action_invocation_context.dart';
import 'action_trigger_type.dart';

typedef ActionExecutor = Future<ActionExecutionResult> Function(
  ActionInvocationContext context,
);

class ActionDefinition {
  const ActionDefinition({
    required this.actionId,
    required this.triggerType,
    required this.enabled,
    required this.execute,
  });

  final String actionId;
  final ActionTriggerType triggerType;
  final bool enabled;
  final ActionExecutor execute;
}
