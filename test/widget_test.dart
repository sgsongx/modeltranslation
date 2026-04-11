import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/core/bridge/bridge_event.dart';
import 'package:modeltranslation/core/application/translation_history_use_case.dart';
import 'package:modeltranslation/core/application/use_case_result.dart';
import 'package:modeltranslation/core/domain/gateways/platform_bridge_gateway.dart';
import 'package:modeltranslation/core/domain/translation_record.dart';
import 'package:modeltranslation/main.dart';

class FakePlatformBridgeGateway implements PlatformBridgeGateway {
  final StreamController<BridgeEvent> _eventController = StreamController<BridgeEvent>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  int openOverlaySettingsCalls = 0;
  String? clipboardText;
  bool hasOverlayPermission = true;

  @override
  Future<String?> getClipboardText() async => clipboardText;

  @override
  Future<bool> hasOverlayPermissionGranted() async => hasOverlayPermission;

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
  Future<void> openOverlayPermissionSettings() async {
    openOverlaySettingsCalls++;
  }

  @override
  Future<void> showOverlay({required String title, required String message}) async {}

  @override
  Future<void> startFloatingBubble() async {
    startCalls++;
  }

  @override
  Future<void> stopFloatingBubble() async {
    stopCalls++;
  }

  @override
  Stream<BridgeEvent> watchActionEvents() => _eventController.stream;
}

class FakeHistoryUseCase implements TranslationHistoryUseCase {
  FakeHistoryUseCase(List<TranslationRecord> records)
      : _records = List<TranslationRecord>.from(records);

  final List<TranslationRecord> _records;

  @override
  Future<UseCaseResult<int>> clearAll() async {
    final deleted = _records.length;
    _records.clear();
    return UseCaseResult.success(deleted);
  }

  @override
  Future<UseCaseResult<int>> deleteById(String id) async {
    _records.removeWhere((record) => record.id == id);
    return UseCaseResult.success(1);
  }

  @override
  Future<UseCaseResult<TranslationRecord?>> getById(String id) async {
    final record = _records.firstWhere((entry) => entry.id == id, orElse: () => throw StateError('missing'));
    return UseCaseResult.success(record);
  }

  @override
  Future<UseCaseResult<List<TranslationRecord>>> loadRecent({int limit = 50}) async {
    return UseCaseResult.success(_records.take(limit).toList());
  }

  @override
  Future<UseCaseResult<List<TranslationRecord>>> search(String query) async {
    final normalized = query.toLowerCase();
    final results = _records.where((record) {
      return record.sourceText.toLowerCase().contains(normalized) ||
          record.translatedText.toLowerCase().contains(normalized);
    }).toList();
    return UseCaseResult.success(results);
  }
}

void main() {
  testWidgets('ModelTranslation app exposes bubble controls', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway();

    await tester.pumpWidget(ModelTranslationApp(platformBridgeGateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Model Translation'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Start floating bubble'), findsOneWidget);
    expect(find.text('Stop floating bubble'), findsOneWidget);
    expect(find.text('Read clipboard'), findsOneWidget);

    await tester.tap(find.text('Start floating bubble'));
    await tester.pump();
    await tester.tap(find.text('Stop floating bubble'));
    await tester.pump();

    expect(gateway.startCalls, 1);
    expect(gateway.stopCalls, 1);
  });

  testWidgets('ModelTranslation app renders clipboard text from the gateway', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway()
      ..clipboardText = 'Hello world';

    await tester.pumpWidget(ModelTranslationApp(platformBridgeGateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read clipboard'));
    await tester.pump();

    expect(find.textContaining('Hello world'), findsOneWidget);
  });

  testWidgets('ModelTranslation app guides overlay permission and opens settings', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway()
      ..hasOverlayPermission = false;

    await tester.pumpWidget(ModelTranslationApp(platformBridgeGateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Overlay permission required to start floating bubble'), findsOneWidget);
    expect(find.text('Grant permission'), findsOneWidget);

    await tester.tap(find.text('Grant permission'));
    await tester.pump();

    expect(gateway.openOverlaySettingsCalls, 1);
  });

  testWidgets('ModelTranslation app switches to settings and history tabs', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway();

    await tester.pumpWidget(ModelTranslationApp(platformBridgeGateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Bridge'), findsOneWidget);
    expect(find.text('LLM Configuration'), findsOneWidget);
    expect(find.text('Save configuration'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsWidgets);
    expect(find.text('Empty state'), findsOneWidget);
    expect(find.text('Translation records will appear here after the first successful run.'), findsOneWidget);
  });

  testWidgets('ModelTranslation app shows history records from the use case', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway();
    final historyUseCase = FakeHistoryUseCase(
      [
        TranslationRecord(
          id: 'record-1',
          sourceText: 'Hello world',
          translatedText: '你好，世界',
          provider: 'openai-compatible',
          model: 'gpt-4o-mini',
          paramsJson: '{"temperature":0.2}',
          status: TranslationStatus.success,
          errorMessage: null,
          createdAt: DateTime(2026, 4, 11),
        ),
      ],
    );

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: gateway,
        translationHistoryUseCase: historyUseCase,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Loaded 1 records'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('你好，世界'), findsOneWidget);
  });

  testWidgets('ModelTranslation app searches history records', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway();
    final historyUseCase = FakeHistoryUseCase(
      [
        TranslationRecord(
          id: 'record-1',
          sourceText: 'Hello world',
          translatedText: '你好，世界',
          provider: 'openai-compatible',
          model: 'gpt-4o-mini',
          paramsJson: '{"temperature":0.2}',
          status: TranslationStatus.success,
          errorMessage: null,
          createdAt: DateTime(2026, 4, 11, 10),
        ),
        TranslationRecord(
          id: 'record-2',
          sourceText: 'Good night',
          translatedText: '晚安',
          provider: 'openai-compatible',
          model: 'gpt-4o-mini',
          paramsJson: '{"temperature":0.2}',
          status: TranslationStatus.success,
          errorMessage: null,
          createdAt: DateTime(2026, 4, 11, 11),
        ),
      ],
    );

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: gateway,
        translationHistoryUseCase: historyUseCase,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Search history'), '晚安');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Good night'), findsOneWidget);
    expect(find.text('Hello world'), findsNothing);
  });

  testWidgets('ModelTranslation app clears history records', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway();
    final historyUseCase = FakeHistoryUseCase(
      [
        TranslationRecord(
          id: 'record-1',
          sourceText: 'Hello world',
          translatedText: '你好，世界',
          provider: 'openai-compatible',
          model: 'gpt-4o-mini',
          paramsJson: '{"temperature":0.2}',
          status: TranslationStatus.success,
          errorMessage: null,
          createdAt: DateTime(2026, 4, 11),
        ),
      ],
    );

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: gateway,
        translationHistoryUseCase: historyUseCase,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('Cleared 1 records'), findsOneWidget);
    expect(find.text('Empty state'), findsOneWidget);
  });

  testWidgets('ModelTranslation app deletes a single history record', (WidgetTester tester) async {
    final gateway = FakePlatformBridgeGateway();
    final historyUseCase = FakeHistoryUseCase(
      [
        TranslationRecord(
          id: 'record-1',
          sourceText: 'Hello world',
          translatedText: '你好，世界',
          provider: 'openai-compatible',
          model: 'gpt-4o-mini',
          paramsJson: '{"temperature":0.2}',
          status: TranslationStatus.success,
          errorMessage: null,
          createdAt: DateTime(2026, 4, 11, 10),
        ),
        TranslationRecord(
          id: 'record-2',
          sourceText: 'Good night',
          translatedText: '晚安',
          provider: 'openai-compatible',
          model: 'gpt-4o-mini',
          paramsJson: '{"temperature":0.2}',
          status: TranslationStatus.success,
          errorMessage: null,
          createdAt: DateTime(2026, 4, 11, 11),
        ),
      ],
    );

    await tester.pumpWidget(
      ModelTranslationApp(
        platformBridgeGateway: gateway,
        translationHistoryUseCase: historyUseCase,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Deleted 1 record'), findsOneWidget);
    expect(find.text('Hello world'), findsNothing);
    expect(find.text('Good night'), findsOneWidget);
  });
}