import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/action_registry.dart';
import 'package:modeltranslation/core/application/default_action_registry.dart';
import 'package:modeltranslation/core/application/translate_clipboard_use_case.dart';
import 'package:modeltranslation/core/application/use_case_result.dart';
import 'package:modeltranslation/core/domain/actions/action_invocation_context.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';

class FakeTranslateClipboardUseCase implements TranslateClipboardUseCase {
  @override
  Future<UseCaseResult<TranslationRecord>> execute() async {
    return UseCaseResult.success(
      TranslationRecord(
        id: 'record-1',
        sourceText: 'Hello world',
        translatedText: '你好，世界',
        provider: 'openai-compatible',
        model: 'gpt-4o-mini',
        paramsJson: '{"temperature":0.2}',
        status: TranslationStatus.success,
        errorMessage: null,
        createdAt: DateTime(2026, 4, 11),
      ),
    );
  }
}

void main() {
  test('Default action registry registers translate_clipboard', () async {
    final registry = buildDefaultActionRegistry(
      translateClipboardUseCase: FakeTranslateClipboardUseCase(),
    );

    final result = await registry.execute(
      'translate_clipboard',
      context: ActionInvocationContext(
        actionId: 'translate_clipboard',
        payload: const {},
        createdAt: DateTime(2026, 4, 11),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.payload?['recordId'], 'record-1');
    expect(result.payload?['translatedText'], '你好，世界');
  });

  test('Default action registry keeps future actions disabled by default', () {
    final registry = buildDefaultActionRegistry(
      translateClipboardUseCase: FakeTranslateClipboardUseCase(),
    );

    expect(registry.resolve('summarize_clipboard'), isNull);
    expect(registry.resolve('rewrite_clipboard'), isNull);
  });
}
