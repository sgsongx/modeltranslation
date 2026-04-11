import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/bridge/bridge_event.dart';
import 'package:modeltranslation/core/domain/gateways/platform_bridge_gateway.dart';
import 'package:modeltranslation/core/domain/gateways/llm_config_repository.dart';
import 'package:modeltranslation/core/domain/llm_config.dart';
import 'package:modeltranslation/main.dart';

class FakePlatformBridgeGateway implements PlatformBridgeGateway {
  final StreamController<BridgeEvent> _eventController = StreamController<BridgeEvent>.broadcast();

  @override
  Future<String?> getClipboardText() async => null;

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

void main() {
  testWidgets('Settings form saves the config through the repository', (WidgetTester tester) async {
    final platformGateway = FakePlatformBridgeGateway();
    final configRepository = FakeLlmConfigRepository();

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: platformGateway,
        translationHistoryUseCase: null,
        llmConfigRepository: configRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Base URL'), findsOneWidget);
    expect(find.text('API Key Ref'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Top P'), findsOneWidget);
    expect(find.text('Max Tokens'), findsOneWidget);
    expect(find.text('Timeout (ms)'), findsOneWidget);
    expect(find.text('System Prompt'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Base URL'), 'https://api.example.com/v1');
    await tester.enterText(find.widgetWithText(TextFormField, 'API Key Ref'), 'secure-ref-1');
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
    expect(configRepository.activeConfig!.apiKeyRef, 'secure-ref-1');
    expect(configRepository.activeConfig!.model, 'gpt-4o-mini');
    expect(find.text('Configuration saved'), findsOneWidget);
  });
}