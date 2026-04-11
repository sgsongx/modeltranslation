import '../domain/translation_record.dart';
import 'use_case_result.dart';

abstract class TranslateClipboardUseCase {
  Future<UseCaseResult<TranslationRecord>> execute();
}