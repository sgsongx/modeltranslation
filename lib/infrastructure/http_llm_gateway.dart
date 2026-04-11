import 'dart:io';

import 'package:dio/dio.dart';
import 'package:modeltranslation/core/domain/gateways/llm_gateway.dart';
import 'package:modeltranslation/core/domain/translation_request.dart';

abstract class DioHttpClient {
  Future<Response<Map<String, dynamic>>> postJson({
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required int timeoutMs,
  });
}

class DioHttpClientImpl implements DioHttpClient {
  DioHttpClientImpl({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<Response<Map<String, dynamic>>> postJson({
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required int timeoutMs,
  }) {
    return _dio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(
        headers: headers,
        sendTimeout: Duration(milliseconds: timeoutMs),
        receiveTimeout: Duration(milliseconds: timeoutMs),
      ),
    );
  }
}

class HttpLlmGateway implements LlmGateway {
  HttpLlmGateway({
    DioHttpClient? client,
    required Future<String?> Function(TranslationRequest request) apiKeyProvider,
    this.maxRetries = 1,
  })  : _client = client ?? DioHttpClientImpl(),
        _apiKeyProvider = apiKeyProvider;

  final DioHttpClient _client;
  final Future<String?> Function(TranslationRequest request) _apiKeyProvider;
  final int maxRetries;

  @override
  Future<String> translate(TranslationRequest request) async {
    final config = request.configSnapshot;
    final endpoint = '${_trimTrailingSlash(config.baseUrl)}/chat/completions';
    final apiKey = await _apiKeyProvider(request);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('API key is missing.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiKey.trim()}',
    };

    final body = <String, Object?>{
      'model': config.model,
      'temperature': config.temperature,
      'top_p': config.topP,
      'max_tokens': config.maxTokens,
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': config.systemPrompt},
        <String, String>{
          'role': 'user',
          'content': 'Translate to ${request.targetLang}: ${request.sourceText}',
        },
      ],
    };

    var attempt = 0;
    while (true) {
      try {
        final response = await _client.postJson(
          url: endpoint,
          headers: headers,
          body: body,
          timeoutMs: config.timeoutMs,
        );
        final translatedText = _parseTranslatedText(response.data);
        if (translatedText.isEmpty) {
          throw const FormatException('Translated text is empty');
        }
        return translatedText;
      } on DioException catch (error) {
        final timeout = _isTimeout(error);
        if (!timeout || attempt >= maxRetries) {
          if (timeout) {
            throw const SocketException('LLM request timed out');
          }
          rethrow;
        }
        attempt++;
      }
    }
  }

  bool _isTimeout(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  String _parseTranslatedText(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Invalid LLM response: choices missing');
    }

    final first = choices.first;
    if (first is! Map) {
      throw const FormatException('Invalid LLM response: choice format');
    }

    final message = first['message'];
    if (message is! Map) {
      throw const FormatException('Invalid LLM response: message missing');
    }

    final content = message['content'];
    if (content is String) {
      return content.trim();
    }

    throw const FormatException('Invalid LLM response: content missing');
  }

  String _trimTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
