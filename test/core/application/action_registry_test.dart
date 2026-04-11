import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/action_registry.dart';
import 'package:modeltranslation/core/domain/actions/action_definition.dart';
import 'package:modeltranslation/core/domain/actions/action_execution_result.dart';
import 'package:modeltranslation/core/domain/actions/action_invocation_context.dart';
import 'package:modeltranslation/core/domain/actions/action_trigger_type.dart';

void main() {
  test('ActionRegistry executes a registered action', () async {
    final registry = ActionRegistry();
    registry.register(
      ActionDefinition(
        actionId: 'translate_clipboard',
        triggerType: ActionTriggerType.click,
        enabled: true,
        execute: (context) async {
          final text = context.payload['text'] as String;
          return ActionExecutionResult.success(
            message: 'translated',
            payload: {'translatedText': '你好，世界: $text'},
          );
        },
      ),
    );

    final result = await registry.execute(
      'translate_clipboard',
      context: ActionInvocationContext(
        actionId: 'translate_clipboard',
        payload: {'text': 'Hello world'},
        createdAt: DateTime(2026, 4, 11),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.message, 'translated');
    expect(result.payload?['translatedText'], '你好，世界: Hello world');
  });

  test('ActionRegistry reports disabled actions', () async {
    final registry = ActionRegistry();
    registry.register(
      ActionDefinition(
        actionId: 'rewrite_clipboard',
        triggerType: ActionTriggerType.longPress,
        enabled: false,
        execute: (context) async {
          return ActionExecutionResult.success(message: 'should not run');
        },
      ),
    );

    final result = await registry.execute(
      'rewrite_clipboard',
      context: ActionInvocationContext(
        actionId: 'rewrite_clipboard',
        payload: const {},
        createdAt: DateTime(2026, 4, 11),
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, 'action_disabled');
  });

  test('ActionRegistry reports missing actions', () async {
    final registry = ActionRegistry();

    final result = await registry.execute(
      'missing_action',
      context: ActionInvocationContext(
        actionId: 'missing_action',
        payload: const {},
        createdAt: DateTime(2026, 4, 11),
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, 'action_not_found');
  });
}
