import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/action_event.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

void main() {
  test('LlmConfig exposes the configured values', () {
    final config = LlmConfig(
      id: 'config-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 1024,
      timeoutMs: 15000,
      systemPrompt: 'Translate with a concise style.',
      updatedAt: DateTime(2026, 4, 11),
    );

    expect(config.id, 'config-1');
    expect(config.provider, 'openai-compatible');
    expect(config.model, 'gpt-4o-mini');
    expect(config.timeoutMs, 15000);
  });

  test('TranslationRequest keeps the source text and config snapshot', () {
    final config = LlmConfig(
      id: 'config-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: 'secure-ref-1',
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 1024,
      timeoutMs: 15000,
      systemPrompt: 'Translate with a concise style.',
      updatedAt: DateTime(2026, 4, 11),
    );

    final request = TranslationRequest(
      sourceText: 'Hello world',
      sourceLang: 'en',
      targetLang: 'zh',
      stylePreset: 'concise',
      configSnapshot: config,
    );

    expect(request.sourceText, 'Hello world');
    expect(request.targetLang, 'zh');
    expect(request.configSnapshot, config);
  });

  test('TranslationRecord captures the outcome metadata', () {
    final record = TranslationRecord(
      id: 'record-1',
      sourceText: 'Hello world',
      translatedText: '你好，世界',
      provider: 'openai-compatible',
      model: 'gpt-4o-mini',
      paramsJson: '{"temperature":0.2}',
      status: TranslationStatus.success,
      errorMessage: null,
      createdAt: DateTime(2026, 4, 11),
    );

    expect(record.status, TranslationStatus.success);
    expect(record.translatedText, '你好，世界');
  });

  test('ActionEvent captures action execution metadata', () {
    final event = ActionEvent(
      id: 'event-1',
      actionId: 'translate_clipboard',
      payloadJson: '{"text":"Hello world"}',
      resultStatus: ActionResultStatus.success,
      createdAt: DateTime(2026, 4, 11),
    );

    expect(event.actionId, 'translate_clipboard');
    expect(event.resultStatus, ActionResultStatus.success);
  });
}