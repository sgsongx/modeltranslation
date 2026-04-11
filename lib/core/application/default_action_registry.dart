import 'action_registry.dart';
import 'translate_clipboard_use_case.dart';
import '../domain/actions/action_definition.dart';
import '../domain/actions/action_execution_result.dart';
import '../domain/actions/action_invocation_context.dart';
import '../domain/actions/action_trigger_type.dart';

ActionRegistry buildDefaultActionRegistry({
  required TranslateClipboardUseCase translateClipboardUseCase,
}) {
  final registry = ActionRegistry();
  registry.register(
    ActionDefinition(
      actionId: 'translate_clipboard',
      triggerType: ActionTriggerType.click,
      enabled: true,
      execute: (ActionInvocationContext context) async {
        final result = await translateClipboardUseCase.execute();
        if (!result.isSuccess || result.value == null) {
          final failure = result.failure;
          return ActionExecutionResult.failure(
            errorCode: failure?.code ?? 'translation_failed',
            errorMessage: failure?.message ?? 'Translation failed.',
          );
        }

        return ActionExecutionResult.success(
          message: 'translate_clipboard completed',
          payload: <String, Object?>{
            'recordId': result.value!.id,
            'translatedText': result.value!.translatedText,
            'actionId': context.actionId,
          },
        );
      },
    ),
  );

  return registry;
}
