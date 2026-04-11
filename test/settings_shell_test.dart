import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/bridge/bridge_event.dart';
import 'package:modeltranslation/core/domain/config/connection_test_result.dart';
import 'package:modeltranslation/core/application/api_key_security_use_case.dart';
import 'package:modeltranslation/core/application/use_case_result.dart';
import 'package:modeltranslation/core/domain/gateways/llm_connection_tester.dart';
import 'package:modeltranslation/core/domain/gateways/platform_bridge_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/main.dart';

class FakePlatformBridgeGateway implements PlatformBridgeGateway {
  final StreamController<BridgeEvent> _eventController = StreamController<BridgeEvent>.broadcast();

  @override
  Future<String?> getClipboardText() async => null;

  @override
  Future<bool> hasOverlayPermissionGranted() async => true;

  @override
  Future<BridgeCapabilities> getCapabilities() async {
    return const BridgeCapabilities(
      methodChannelName: 'modeltranslation/platform',
      eventChannelName: 'modeltranslation/action_events',
      supportsClipboard: true,
      supportsOverlay: true,
      supportsFloatingBubble: true,
    );
  }

  @override
  Future<void> hideOverlay() async {}

  @override
  Future<void> openOverlayPermissionSettings() async {}

  @override
  Future<void> showOverlay({required String title, required String message}) async {}

  @override
  Future<void> startFloatingBubble() async {}

  @override
  Future<void> stopFloatingBubble() async {}

  @override
  Stream<BridgeEvent> watchActionEvents() => _eventController.stream;
}

class FakeLlmConfigRepository implements LlmConfigRepository {
  LlmConfig? activeConfig;

  @override
  Future<LlmConfig?> loadActive() async => activeConfig;

  @override
  Future<void> saveActive(LlmConfig config) async {
    activeConfig = config;
  }
}

class FakeLlmConnectionTester implements LlmConnectionTester {
  @override
  Future<ConnectionTestResult> test(LlmConfig config) async {
    return ConnectionTestResult.success(
      provider: config.provider,
      model: config.model,
      endpoint: config.baseUrl,
      latencyMs: 125,
      message: 'Connection verified.',
    );
  }
}

class FakeApiKeySecurityUseCase implements ApiKeySecurityUseCase {
  int storeCalls = 0;
  String? lastApiKey;
  String? lastKeyRef;

  @override
  Future<UseCaseResult<bool>> delete(String keyRef) async {
    return UseCaseResult.success(true);
  }

  @override
  Future<UseCaseResult<String>> load(String keyRef) async {
    return UseCaseResult.success('secret-from-vault');
  }

  @override
  Future<UseCaseResult<String>> store(String apiKey, {String? keyRef}) async {
    storeCalls++;
    lastApiKey = apiKey;
    lastKeyRef = keyRef;
    return UseCaseResult.success(keyRef ?? 'vault-ref-1');
  }
}

void main() {
  testWidgets('Settings form saves the config through the repository', (WidgetTester tester) async {
    final platformGateway = FakePlatformBridgeGateway();
    final configRepository = FakeLlmConfigRepository();

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: platformGateway,
        translationHistoryUseCase: null,
        llmConfigRepository: configRepository,
        llmConnectionTester: FakeLlmConnectionTester(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Base URL'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Top P'), findsOneWidget);
    expect(find.text('Max Tokens'), findsOneWidget);
    expect(find.text('Timeout (ms)'), findsOneWidget);
    expect(find.text('System Prompt'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Base URL'), 'https://api.example.com/v1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Model'), 'gpt-4o-mini');
    await tester.enterText(find.widgetWithText(TextFormField, 'Temperature'), '0.2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Top P'), '0.9');
    await tester.enterText(find.widgetWithText(TextFormField, 'Max Tokens'), '1024');
    await tester.enterText(find.widgetWithText(TextFormField, 'Timeout (ms)'), '15000');
    await tester.enterText(find.widgetWithText(TextFormField, 'System Prompt'), 'Translate with a concise style.');

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save configuration'));
    await tester.pumpAndSettle();

    expect(configRepository.activeConfig, isNotNull);
    expect(configRepository.activeConfig!.baseUrl, 'https://api.example.com/v1');
    expect(configRepository.activeConfig!.apiKeyRef, isNull);
    expect(configRepository.activeConfig!.model, 'gpt-4o-mini');
    expect(find.text('Configuration saved'), findsOneWidget);
  });

  testWidgets('Settings form runs connection test and shows result', (WidgetTester tester) async {
    final platformGateway = FakePlatformBridgeGateway();
    final configRepository = FakeLlmConfigRepository();

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: platformGateway,
        translationHistoryUseCase: null,
        llmConfigRepository: configRepository,
        llmConnectionTester: FakeLlmConnectionTester(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Base URL'), 'https://api.example.com/v1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Model'), 'gpt-4o-mini');
    await tester.enterText(find.widgetWithText(TextFormField, 'Temperature'), '0.2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Top P'), '0.9');
    await tester.enterText(find.widgetWithText(TextFormField, 'Max Tokens'), '1024');
    await tester.enterText(find.widgetWithText(TextFormField, 'Timeout (ms)'), '15000');
    await tester.enterText(find.widgetWithText(TextFormField, 'System Prompt'), 'Translate with a concise style.');

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection verified.'), findsOneWidget);
    expect(find.textContaining('125 ms'), findsOneWidget);
  });

  testWidgets('Settings form stores API key securely and writes resolved key ref', (WidgetTester tester) async {
    final platformGateway = FakePlatformBridgeGateway();
    final configRepository = FakeLlmConfigRepository();
    final apiKeyUseCase = FakeApiKeySecurityUseCase();

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: platformGateway,
        translationHistoryUseCase: null,
        llmConfigRepository: configRepository,
        apiKeySecurityUseCase: apiKeyUseCase,
        llmConnectionTester: FakeLlmConnectionTester(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Base URL'), 'https://api.example.com/v1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Model'), 'gpt-4o-mini');
    await tester.enterText(find.widgetWithText(TextFormField, 'Temperature'), '0.2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Top P'), '0.9');
    await tester.enterText(find.widgetWithText(TextFormField, 'Max Tokens'), '1024');
    await tester.enterText(find.widgetWithText(TextFormField, 'Timeout (ms)'), '15000');
    await tester.enterText(find.widgetWithText(TextFormField, 'System Prompt'), 'Translate with a concise style.');
    await tester.enterText(find.widgetWithText(TextFormField, 'API Key'), 'secret-api-key');

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save configuration'));
    await tester.pumpAndSettle();

    expect(apiKeyUseCase.storeCalls, 1);
    expect(apiKeyUseCase.lastApiKey, 'secret-api-key');
    expect(configRepository.activeConfig?.apiKeyRef, 'vault-ref-1');
  });
}