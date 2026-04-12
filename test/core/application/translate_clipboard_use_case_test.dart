import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/application/translate_clipboard_use_case.dart';
import 'package:modeltranslation/core/application/use_case_result.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';

class FakeTranslateClipboardUseCase implements TranslateClipboardUseCase {
  @override
  Future<UseCaseResult<TranslationRecord>> execute({String? sourceTextOverride}) async {
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

class FailingTranslateClipboardUseCase implements TranslateClipboardUseCase {
  @override
  Future<UseCaseResult<TranslationRecord>> execute({String? sourceTextOverride}) async {
    return UseCaseResult.failure(
      const UseCaseFailure(
        code: 'clipboard_empty',
        message: 'Clipboard text is empty.',
      ),
    );
  }
}

void main() {
  test('TranslateClipboardUseCase can return a successful record result', () async {
    final useCase = FakeTranslateClipboardUseCase();

    final result = await useCase.execute();

    expect(result.isSuccess, isTrue);
    expect(result.value?.translatedText, '你好，世界');
  });

  test('TranslateClipboardUseCase can return a structured failure', () async {
    final useCase = FailingTranslateClipboardUseCase();

    final result = await useCase.execute();

    expect(result.isSuccess, isFalse);
    expect(result.failure?.code, 'clipboard_empty');
  });
}