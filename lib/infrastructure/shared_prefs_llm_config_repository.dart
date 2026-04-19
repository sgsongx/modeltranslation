import 'dart:convert';

import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsLlmConfigRepository implements LlmConfigRepository {
  SharedPrefsLlmConfigRepository({this.initialConfig});

  static const String _activeConfigKey = 'llm.active_config.v1';

  final LlmConfig? initialConfig;

  @override
  Future<LlmConfig?> loadActive() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeConfigKey);
    if (raw == null || raw.trim().isEmpty) {
      return initialConfig;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return initialConfig;
      }
      return _fromMap(decoded);
    } catch (_) {
      return initialConfig;
    }
  }

  @override
  Future<void> saveActive(LlmConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeConfigKey, jsonEncode(_toMap(config)));
  }

  Map<String, Object?> _toMap(LlmConfig config) {
    return <String, Object?>{
      'id': config.id,
      'provider': config.provider,
      'baseUrl': config.baseUrl,
      'apiKeyRef': config.apiKeyRef,
      'model': config.model,
      'temperature': config.temperature,
      'topP': config.topP,
      'maxTokens': config.maxTokens,
      'timeoutMs': config.timeoutMs,
      'systemPrompt': config.systemPrompt,
      'overlayFontSizeSp': config.overlayFontSizeSp,
      'historyOverlayLimit': config.historyOverlayLimit,
      'updatedAt': config.updatedAt.toIso8601String(),
    };
  }

  LlmConfig _fromMap(Map<String, dynamic> map) {
    return LlmConfig(
      id: (map['id'] as String?) ?? 'active-config',
      provider: (map['provider'] as String?) ?? 'openai-compatible',
      baseUrl: (map['baseUrl'] as String?) ?? 'https://api.openai.com/v1',
      apiKeyRef: map['apiKeyRef'] as String?,
      model: (map['model'] as String?) ?? 'gpt-4o-mini',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.2,
      topP: (map['topP'] as num?)?.toDouble() ?? 0.9,
      maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 512,
      timeoutMs: (map['timeoutMs'] as num?)?.toInt() ?? 12000,
      systemPrompt: (map['systemPrompt'] as String?) ?? 'Translate the text accurately and keep formatting.',
      overlayFontSizeSp: (map['overlayFontSizeSp'] as num?)?.toDouble() ?? 15.0,
      historyOverlayLimit: (map['historyOverlayLimit'] as num?)?.toInt() ?? 3,
      updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}
