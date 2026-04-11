import '../config/connection_test_result.dart';
import '../llm_config.dart';

abstract class LlmConnectionTester {
  Future<ConnectionTestResult> test(LlmConfig config);
}
