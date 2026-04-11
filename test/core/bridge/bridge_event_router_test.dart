import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/action_registry.dart';
import 'package:modeltranslation/core/application/bridge_event_router.dart';
import 'package:modeltranslation/core/bridge/bridge_event.dart';
import 'package:modeltranslation/core/domain/actions/action_definition.dart';
import 'package:modeltranslation/core/domain/actions/action_execution_result.dart';
import 'package:modeltranslation/core/domain/actions/action_invocation_context.dart';
import 'package:modeltranslation/core/domain/actions/action_trigger_type.dart';

void main() {
  test('BridgeEventRouter routes action events to the action registry', () async {
    final registry = ActionRegistry();
    registry.register(
      ActionDefinition(
        actionId: 'translate_clipboard',
        triggerType: ActionTriggerType.click,
        enabled: true,
        execute: (context) async {
          return ActionExecutionResult.success(
            message: 'handled',
            payload: {'actionId': context.actionId},
          );
        },
      ),
    );

    final router = BridgeEventRouter(actionRegistry: registry);
    final result = await router.route(
      BridgeEvent.action(
        actionId: 'translate_clipboard',
        payload: {'text': 'Hello world'},
        createdAt: DateTime(2026, 4, 11),
      ),
    );

    expect(result.handled, isTrue);
    expect(result.actionResult?.isSuccess, isTrue);
    expect(result.actionResult?.payload?['actionId'], 'translate_clipboard');
  });

  test('BridgeEventRouter ignores non-action events', () async {
    final registry = ActionRegistry();
    final router = BridgeEventRouter(actionRegistry: registry);

    final result = await router.route(
      BridgeEvent.lifecycle(
        payload: {'state': 'resumed'},
        createdAt: DateTime(2026, 4, 11),
      ),
    );

    expect(result.handled, isFalse);
    expect(result.message, 'event_ignored');
  });
}
