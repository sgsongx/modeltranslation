import '../llm_config.dart';

abstract class LlmConfigRepository {
  Future<LlmConfig?> loadActive();

  Future<void> saveActive(LlmConfig config);
}
