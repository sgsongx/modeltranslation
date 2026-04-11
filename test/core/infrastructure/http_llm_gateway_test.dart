import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';
import 'package:modeltranslation/infrastructure/http_llm_gateway.dart';

class FakeDioClient implements DioHttpClient {
  FakeDioClient(this._responses);

  final List<Object> _responses;
  int callCount = 0;
  RequestOptions? lastOptions;
  Map<String, Object?>? lastBody;

  @override
  Future<Response<Map<String, dynamic>>> postJson({
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required int timeoutMs,
  }) async {
    callCount++;
    lastBody = body;
    lastOptions = RequestOptions(path: url, headers: headers)
      ..connectTimeout = Duration(milliseconds: timeoutMs)
      ..receiveTimeout = Duration(milliseconds: timeoutMs);

    final current = _responses[callCount - 1];
    if (current is Exception) {
      throw current;
    }

    return Response<Map<String, dynamic>>(
      requestOptions: lastOptions!,
      statusCode: 200,
      data: current as Map<String, dynamic>,
    );
  }
}

TranslationRequest _buildRequest() {
  return TranslationRequest(
    sourceText: 'Hello world',
    sourceLang: 'en',
    targetLang: 'zh',
    stylePreset: 'concise',
    configSnapshot: LlmConfig(
      id: 'cfg-1',
      provider: 'openai-compatible',
      baseUrl: 'https://api.example.com/v1',
      apiKeyRef: null,
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 256,
      timeoutMs: 3000,
      systemPrompt: 'Translate accurately.',
      updatedAt: DateTime(2026, 4, 11),
    ),
  );
}

void main() {
  test('HttpLlmGateway parses translated text from OpenAI-compatible response', () async {
    final client = FakeDioClient([
      <String, dynamic>{
        'choices': [
          {
            'message': {'content': '你好，世界'}
          }
        ]
      }
    ]);

    final gateway = HttpLlmGateway(client: client, apiKeyProvider: (_) async => 'test-api-key');

    final result = await gateway.translate(_buildRequest());

    expect(result, '你好，世界');
    expect(client.callCount, 1);
    expect(client.lastBody?['model'], 'gpt-4o-mini');
  });

  test('HttpLlmGateway retries once on timeout and succeeds', () async {
    final client = FakeDioClient([
      DioException(
        requestOptions: RequestOptions(path: '/chat/completions'),
        type: DioExceptionType.connectionTimeout,
      ),
      <String, dynamic>{
        'choices': [
          {
            'message': {'content': '重试成功'}
          }
        ]
      }
    ]);

    final gateway = HttpLlmGateway(client: client, apiKeyProvider: (_) async => 'test-api-key', maxRetries: 1);

    final result = await gateway.translate(_buildRequest());

    expect(result, '重试成功');
    expect(client.callCount, 2);
  });

  test('HttpLlmGateway throws when response payload is invalid', () async {
    final client = FakeDioClient([
      <String, dynamic>{
        'choices': []
      }
    ]);
    final gateway = HttpLlmGateway(client: client, apiKeyProvider: (_) async => 'test-api-key');

    await expectLater(
      gateway.translate(_buildRequest()),
      throwsA(isA<FormatException>()),
    );
  });

  test('HttpLlmGateway throws SocketException after retries exhausted', () async {
    final client = FakeDioClient([
      DioException(
        requestOptions: RequestOptions(path: '/chat/completions'),
        type: DioExceptionType.connectionTimeout,
      ),
      DioException(
        requestOptions: RequestOptions(path: '/chat/completions'),
        type: DioExceptionType.connectionTimeout,
      ),
    ]);
    final gateway = HttpLlmGateway(client: client, apiKeyProvider: (_) async => 'test-api-key', maxRetries: 1);

    await expectLater(
      gateway.translate(_buildRequest()),
      throwsA(isA<SocketException>()),
    );
    expect(client.callCount, 2);
  });

  test('HttpLlmGateway fails fast when API key is missing', () async {
    final client = FakeDioClient(const <Object>[]);
    final gateway = HttpLlmGateway(client: client, apiKeyProvider: (_) async => null);

    await expectLater(
      gateway.translate(_buildRequest()),
      throwsA(isA<StateError>()),
    );
    expect(client.callCount, 0);
  });
}
