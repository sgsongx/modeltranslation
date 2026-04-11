import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';

class InMemoryLlmConfigRepository implements LlmConfigRepository {
  LlmConfig? _activeConfig;

  @override
  Future<LlmConfig?> loadActive() async => _activeConfig;

  @override
  Future<void> saveActive(LlmConfig config) async {
    _activeConfig = config;
  }
}
