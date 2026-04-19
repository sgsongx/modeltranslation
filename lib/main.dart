import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/bridge/bridge_event.dart';
import 'core/bridge/method_channel_platform_bridge_gateway.dart';
import 'core/application/action_registry.dart';
import 'core/application/api_key_security_use_case.dart';
import 'core/application/api_key_security_use_case_impl.dart';
import 'core/application/default_action_registry.dart';
import 'core/application/translate_clipboard_use_case.dart';
import 'core/application/translate_clipboard_use_case_impl.dart';
import 'core/domain/gateways/platform_bridge_gateway.dart';
import 'core/application/translation_history_use_case.dart';
import 'core/domain/translation_record.dart';
import 'core/domain/gateways/llm_connection_tester.dart';
import 'core/domain/gateways/llm_gateway.dart';
import 'core/domain/gateways/llm_config_repository.dart';
import 'core/domain/gateways/secret_vault.dart';
import 'core/domain/llm_config.dart';
import 'core/domain/actions/action_invocation_context.dart';
import 'core/application/translation_history_use_case_impl.dart';
import 'infrastructure/debug_trace_logger.dart';
import 'infrastructure/http_llm_gateway.dart';
import 'infrastructure/in_memory_llm_config_repository.dart';
import 'infrastructure/in_memory_record_repository.dart';
import 'infrastructure/in_memory_secret_vault.dart';
import 'infrastructure/llm_gateway_connection_tester.dart';
import 'infrastructure/mock_llm_gateway.dart';
import 'infrastructure/mock_llm_connection_tester.dart';
import 'infrastructure/platform_bridge_gateways.dart';
import 'infrastructure/shared_prefs_llm_config_repository.dart';
import 'infrastructure/shared_prefs_record_repository.dart';
import 'infrastructure/shared_prefs_secret_vault.dart';
import 'infrastructure/vault_api_key_provider.dart';

void main() {
  runApp(ModelTranslationApp(enableHttpLlmGateway: true));
}

DebugTraceLogger _diagnosticsLogger(bool enabled) {
  return enabled ? DebugTraceLogger.enabled() : DebugTraceLogger.disabled();
}

class ModelTranslationApp extends StatelessWidget {
  static final SharedPrefsLlmConfigRepository _defaultConfigRepository = SharedPrefsLlmConfigRepository(
    initialConfig: LlmConfig(
      id: 'default-active-config',
      provider: 'openai-compatible',
      baseUrl: 'https://api.openai.com/v1',
      apiKeyRef: null,
      model: 'gpt-4o-mini',
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 512,
      timeoutMs: 12000,
      systemPrompt: 'Translate the text accurately and keep formatting.',
      updatedAt: DateTime(2026, 4, 11),
    ),
  );
  static final SharedPrefsRecordRepository _defaultRecordRepository = SharedPrefsRecordRepository();
  static final SharedPrefsSecretVault _defaultSecretVault = SharedPrefsSecretVault();

  ModelTranslationApp({
    super.key,
    PlatformBridgeGateway? platformBridgeGateway,
    TranslationHistoryUseCase? translationHistoryUseCase,
    LlmConfigRepository? llmConfigRepository,
    SecretVault? secretVault,
    LlmGateway? llmGateway,
    TranslateClipboardUseCase? translateClipboardUseCase,
    ActionRegistry? actionRegistry,
    ApiKeySecurityUseCase? apiKeySecurityUseCase,
    bool enableHttpLlmGateway = false,
    bool enableDiagnosticsLogging = const bool.fromEnvironment('MODELTRANSLATION_DEBUG_LOGGING'),
    LlmConnectionTester? llmConnectionTester,
  })  : platformBridgeGateway = platformBridgeGateway ?? _DefaultPlatformBridgeGateway(),
        llmConfigRepository = llmConfigRepository ?? _defaultConfigRepository,
        secretVault = secretVault ?? _defaultSecretVault,
      enableDiagnosticsLogging = enableDiagnosticsLogging,
        llmGateway = llmGateway ??
            (enableHttpLlmGateway
                ? HttpLlmGateway(
                    apiKeyProvider: VaultApiKeyProvider(secretVault ?? _defaultSecretVault).resolve,
                  )
                : MockLlmGateway()),
        translateClipboardUseCase = translateClipboardUseCase ??
            TranslateClipboardUseCaseImpl(
              clipboardGateway: PlatformClipboardGateway(platformBridgeGateway ?? _DefaultPlatformBridgeGateway()),
              configRepository: llmConfigRepository ?? _defaultConfigRepository,
              llmGateway: llmGateway ??
                  (enableHttpLlmGateway
                      ? HttpLlmGateway(
                          apiKeyProvider: VaultApiKeyProvider(secretVault ?? _defaultSecretVault).resolve,
                        )
                      : MockLlmGateway()),
              overlayGateway: PlatformOverlayGateway(platformBridgeGateway ?? _DefaultPlatformBridgeGateway()),
              recordRepository: _defaultRecordRepository,
              nowProvider: DateTime.now,
              idProvider: () => DateTime.now().microsecondsSinceEpoch.toString(),
              targetLang: 'zh',
              stylePreset: 'concise',
              debugLogger: _diagnosticsLogger(enableDiagnosticsLogging),
            ),
        actionRegistry = actionRegistry ??
            buildDefaultActionRegistry(
              translateClipboardUseCase: translateClipboardUseCase ??
                  TranslateClipboardUseCaseImpl(
                    clipboardGateway:
                        PlatformClipboardGateway(platformBridgeGateway ?? _DefaultPlatformBridgeGateway()),
                    configRepository: llmConfigRepository ?? _defaultConfigRepository,
                    llmGateway: llmGateway ??
                      (enableHttpLlmGateway
                        ? HttpLlmGateway(
                          apiKeyProvider: VaultApiKeyProvider(secretVault ?? _defaultSecretVault).resolve,
                          )
                        : MockLlmGateway()),
                    overlayGateway:
                        PlatformOverlayGateway(platformBridgeGateway ?? _DefaultPlatformBridgeGateway()),
                    recordRepository: _defaultRecordRepository,
                    nowProvider: DateTime.now,
                    idProvider: () => DateTime.now().microsecondsSinceEpoch.toString(),
                    targetLang: 'zh',
                    stylePreset: 'concise',
                    debugLogger: _diagnosticsLogger(enableDiagnosticsLogging),
                  ),
            ),
        apiKeySecurityUseCase = apiKeySecurityUseCase ??
            ApiKeySecurityUseCaseImpl(
              vault: secretVault ?? _defaultSecretVault,
              keyRefProvider: () => 'active-api-key',
            ),
        translationHistoryUseCase = translationHistoryUseCase ??
            TranslationHistoryUseCaseImpl(repository: _defaultRecordRepository),
        llmConnectionTester = llmConnectionTester ??
            (enableHttpLlmGateway
                ? LlmGatewayConnectionTester(
                    llmGateway: llmGateway ??
                        HttpLlmGateway(
                          apiKeyProvider: VaultApiKeyProvider(secretVault ?? _defaultSecretVault).resolve,
                        ),
                    debugLogger: _diagnosticsLogger(enableDiagnosticsLogging),
                  )
                : MockLlmConnectionTester());

  final PlatformBridgeGateway platformBridgeGateway;
  final TranslationHistoryUseCase? translationHistoryUseCase;
  final LlmConfigRepository? llmConfigRepository;
  final SecretVault? secretVault;
  final LlmGateway? llmGateway;
  final TranslateClipboardUseCase? translateClipboardUseCase;
  final ActionRegistry? actionRegistry;
  final ApiKeySecurityUseCase? apiKeySecurityUseCase;
  final bool enableDiagnosticsLogging;
  final LlmConnectionTester? llmConnectionTester;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Model Translation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: TranslationShell(
        platformBridgeGateway: platformBridgeGateway,
        translationHistoryUseCase: translationHistoryUseCase,
        llmConfigRepository: llmConfigRepository,
        actionRegistry: actionRegistry,
        apiKeySecurityUseCase: apiKeySecurityUseCase,
        enableDiagnosticsLogging: enableDiagnosticsLogging,
        llmConnectionTester: llmConnectionTester,
      ),
    );
  }
}

class TranslationShell extends StatefulWidget {
  const TranslationShell({
    super.key,
    required this.platformBridgeGateway,
    required this.translationHistoryUseCase,
    required this.llmConfigRepository,
    required this.actionRegistry,
    required this.apiKeySecurityUseCase,
    required this.enableDiagnosticsLogging,
    required this.llmConnectionTester,
  });

  final PlatformBridgeGateway platformBridgeGateway;
  final TranslationHistoryUseCase? translationHistoryUseCase;
  final LlmConfigRepository? llmConfigRepository;
  final ActionRegistry? actionRegistry;
  final ApiKeySecurityUseCase? apiKeySecurityUseCase;
  final bool enableDiagnosticsLogging;
  final LlmConnectionTester? llmConnectionTester;

  @override
  State<TranslationShell> createState() => _TranslationShellState();
}

class _TranslationShellState extends State<TranslationShell> {
  static const int _defaultHistoryOverlayLimit = 3;
  static const double _defaultOverlayFontSizeSp = 15.0;

  String? clipboardText;
  String statusMessage = 'Ready';
  bool supportsFloatingBubble = false;
  bool hasOverlayPermission = true;
  double overlayFontSizeSp = _defaultOverlayFontSizeSp;
  int historyOverlayLimit = _defaultHistoryOverlayLimit;
  BridgeCapabilities? capabilities;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _startBubble();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await widget.platformBridgeGateway.setDiagnosticsEnabled(widget.enableDiagnosticsLogging);
    final bridgeCapabilities = await widget.platformBridgeGateway.getCapabilities();
    final activeConfig = await widget.llmConfigRepository?.loadActive();
    final resolvedOverlayFontSize =
      activeConfig?.overlayFontSizeSp ?? await widget.platformBridgeGateway.getOverlayFontSizeSp();
    final resolvedHistoryOverlayLimit = activeConfig?.historyOverlayLimit ?? _defaultHistoryOverlayLimit;
    final overlayPermission = bridgeCapabilities.supportsOverlay
        ? await widget.platformBridgeGateway.hasOverlayPermissionGranted()
        : true;
    if (!mounted) {
      return;
    }

    setState(() {
      capabilities = bridgeCapabilities;
      supportsFloatingBubble = bridgeCapabilities.supportsFloatingBubble;
      hasOverlayPermission = overlayPermission;
      overlayFontSizeSp = resolvedOverlayFontSize;
      historyOverlayLimit = resolvedHistoryOverlayLimit;
      statusMessage = 'Bridge connected';
    });

    _eventSubscription = widget.platformBridgeGateway.watchActionEvents().listen((event) {
      unawaited(_handleBridgeEvent(event));
    });
  }

  Future<void> _handleBridgeEvent(BridgeEvent event) async {
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Action event: ${event.actionId}';
    });

    if (event.kind != BridgeEventKind.action) {
      return;
    }

    if (event.actionId == 'open_recent_history') {
      await _handleRecentHistoryAction(event);
      return;
    }

    if (event.actionId != 'translate_clipboard') {
      return;
    }

    final source = event.payload['source'] as String?;
    final shouldMoveToBackground = source == 'floating_bubble';

    if (event.payload['translatedText'] == null && event.payload['errorMessage'] == null) {
      final actionRegistry = widget.actionRegistry;
      if (actionRegistry != null) {
        final executionResult = await actionRegistry.execute(
          event.actionId,
          context: ActionInvocationContext(
            actionId: event.actionId,
            payload: event.payload,
            createdAt: event.createdAt,
          ),
        );

        if (!executionResult.isSuccess) {
          if (shouldMoveToBackground) {
            await widget.platformBridgeGateway.moveAppToBackground();
          }

          if (!mounted) {
            return;
          }

          setState(() {
            statusMessage = 'Translation error overlay shown from bubble action';
          });
          return;
        }

        if (!mounted) {
          return;
        }

        if (shouldMoveToBackground) {
          await widget.platformBridgeGateway.moveAppToBackground();
        }

        if (!mounted) {
          return;
        }

        setState(() {
          statusMessage = 'Translation overlay shown from bubble action';
        });
        return;
      }
    }

    final errorMessage = (event.payload['errorMessage'] as String?)?.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      if (shouldMoveToBackground) {
        await widget.platformBridgeGateway.moveAppToBackground();
      }

      await widget.platformBridgeGateway.showOverlay(
        title: 'Translation Error',
        message: errorMessage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        statusMessage = 'Translation error overlay shown from bubble action';
      });
      return;
    }

    final payloadText = event.payload['translatedText'] as String?;
    var message = payloadText?.trim();
    if (message == null || message.isEmpty) {
      message = (await widget.platformBridgeGateway.getClipboardText())?.trim();
    }

    if (message == null || message.isEmpty) {
      message = 'Clipboard is empty';
    }

    if (shouldMoveToBackground) {
      await widget.platformBridgeGateway.moveAppToBackground();
    }

    await widget.platformBridgeGateway.showOverlay(
      title: 'Translation Result',
      message: _buildTranslationResultOverlayPayload(
        sourceText: (event.payload['sourceText'] as String?) ??
            (event.payload['clipboardText'] as String?) ??
            'Source text unavailable',
        translatedText: message,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Translation overlay shown from bubble action';
    });
  }

  Future<void> _handleRecentHistoryAction(BridgeEvent event) async {
    final source = event.payload['source'] as String?;
    final shouldMoveToBackground = source == 'floating_bubble';
    final historyUseCase = widget.translationHistoryUseCase;

    String message;
    if (historyUseCase == null) {
      message = 'History source is not connected.';
    } else {
      final result = await historyUseCase.loadRecent(limit: historyOverlayLimit);
      if (!result.isSuccess || result.value == null) {
        message = result.failure?.message ?? 'Failed to load recent history.';
      } else if (result.value!.isEmpty) {
        message = 'No translation history yet. Tap the bubble once to translate first.';
      } else {
        message = _buildRecentHistoryOverlayPayload(result.value!);
      }
    }

    if (shouldMoveToBackground) {
      await widget.platformBridgeGateway.moveAppToBackground();
    }

    await widget.platformBridgeGateway.showOverlay(
      title: 'Recent History',
      message: message,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Recent history overlay shown from bubble action';
    });
  }

  String _buildRecentHistoryOverlayPayload(List<TranslationRecord> records) {
    final payload = <String, Object?>{
      'type': 'recent_history_v1',
      'fontSizeSp': overlayFontSizeSp,
      'interaction': <String, Object?>{
        'copySource': 'button',
        'copyTranslated': 'button',
      },
      'entries': records
          .map(
            (record) => <String, Object?>{
              'id': record.id,
              'sourceText': record.sourceText,
              'translatedText': record.translatedText,
              'createdAt': record.createdAt.toIso8601String(),
              'status': record.status.name,
            },
          )
          .toList(growable: false),
    };
    return jsonEncode(payload);
  }

  String _buildTranslationResultOverlayPayload({
    required String sourceText,
    required String translatedText,
  }) {
    final payload = <String, Object?>{
      'type': 'translation_result_v1',
      'sourceText': sourceText,
      'translatedText': translatedText,
      'fontSizeSp': overlayFontSizeSp,
    };
    return jsonEncode(payload);
  }

  Future<void> _startBubble() async {
    final overlayPermission = await widget.platformBridgeGateway.hasOverlayPermissionGranted();
    if (!mounted) {
      return;
    }

    if (hasOverlayPermission != overlayPermission) {
      setState(() {
        hasOverlayPermission = overlayPermission;
      });
    }

    if (!overlayPermission) {
      if (!mounted) {
        return;
      }

      setState(() {
        statusMessage = 'Overlay permission required to start floating bubble';
      });
      return;
    }

    try {
      await widget.platformBridgeGateway.startFloatingBubble();
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      final details = error.message?.trim();
      setState(() {
        statusMessage = details == null || details.isEmpty
            ? 'Failed to start floating bubble. Check overlay/floating window permission in system settings.'
            : 'Failed to start floating bubble: $details';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Floating bubble started';
    });
  }

  Future<void> _stopBubble() async {
    await widget.platformBridgeGateway.stopFloatingBubble();
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Floating bubble stopped';
    });
  }

  Future<void> _readClipboard() async {
    final text = await widget.platformBridgeGateway.getClipboardText();
    if (!mounted) {
      return;
    }

    setState(() {
      clipboardText = text;
      statusMessage = text == null ? 'Clipboard is empty' : 'Clipboard loaded';
    });
  }

  Future<void> _openOverlayPermissionSettings() async {
    await widget.platformBridgeGateway.openOverlayPermissionSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Opened overlay permission settings';
    });
  }

  Future<void> _showSampleOverlay() async {
    await widget.platformBridgeGateway.showOverlay(
      title: 'Translation Result',
      message: _buildTranslationResultOverlayPayload(
        sourceText: clipboardText ?? 'Sample source content',
        translatedText: clipboardText ?? 'Sample translated content. Tap Copy or Close in the overlay.',
      ),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Result overlay shown';
    });
  }

  Future<void> _hideResultOverlay() async {
    await widget.platformBridgeGateway.hideOverlay();
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Result overlay hidden';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Model Translation'),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Control'),
              Tab(text: 'Settings'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: TabBarView(
            children: [
              _ControlSection(
                colorScheme: colorScheme,
                clipboardText: clipboardText,
                statusMessage: statusMessage,
                supportsFloatingBubble: supportsFloatingBubble,
                hasOverlayPermission: hasOverlayPermission,
                onStartBubble: _startBubble,
                onStopBubble: _stopBubble,
                onReadClipboard: _readClipboard,
                onOpenOverlayPermissionSettings: _openOverlayPermissionSettings,
                onShowSampleOverlay: _showSampleOverlay,
                onHideResultOverlay: _hideResultOverlay,
              ),
              _SettingsSection(
                capabilities: capabilities,
                platformBridgeGateway: widget.platformBridgeGateway,
                llmConfigRepository: widget.llmConfigRepository,
                apiKeySecurityUseCase: widget.apiKeySecurityUseCase,
                llmConnectionTester: widget.llmConnectionTester,
                onOverlayFontSizeChanged: (value) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    overlayFontSizeSp = value;
                  });
                },
                onHistoryOverlayLimitChanged: (value) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    historyOverlayLimit = value;
                  });
                },
              ),
              _HistorySection(translationHistoryUseCase: widget.translationHistoryUseCase),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlSection extends StatelessWidget {
  const _ControlSection({
    required this.colorScheme,
    required this.clipboardText,
    required this.statusMessage,
    required this.supportsFloatingBubble,
    required this.hasOverlayPermission,
    required this.onStartBubble,
    required this.onStopBubble,
    required this.onReadClipboard,
    required this.onOpenOverlayPermissionSettings,
    required this.onShowSampleOverlay,
    required this.onHideResultOverlay,
  });

  final ColorScheme colorScheme;
  final String? clipboardText;
  final String statusMessage;
  final bool supportsFloatingBubble;
  final bool hasOverlayPermission;
  final Future<void> Function() onStartBubble;
  final Future<void> Function() onStopBubble;
  final Future<void> Function() onReadClipboard;
  final Future<void> Function() onOpenOverlayPermissionSettings;
  final Future<void> Function() onShowSampleOverlay;
  final Future<void> Function() onHideResultOverlay;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Core contracts ready.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Control the floating bubble and read clipboard content from the bridge.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: (supportsFloatingBubble && hasOverlayPermission) ? onStartBubble : null,
                        child: const Text('Start floating bubble'),
                      ),
                      OutlinedButton(
                        onPressed: supportsFloatingBubble ? onStopBubble : null,
                        child: const Text('Stop floating bubble'),
                      ),
                      TextButton(
                        onPressed: onReadClipboard,
                        child: const Text('Read clipboard'),
                      ),
                      OutlinedButton(
                        onPressed: onShowSampleOverlay,
                        child: const Text('Show result overlay'),
                      ),
                      TextButton(
                        onPressed: onHideResultOverlay,
                        child: const Text('Hide result overlay'),
                      ),
                    ],
                  ),
                  if (!hasOverlayPermission) ...[
                    const SizedBox(height: 12),
                    const Text('Overlay permission required to start floating bubble'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onOpenOverlayPermissionSettings,
                      child: const Text('Grant permission'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Status: $statusMessage'),
                  const SizedBox(height: 8),
                  Text(
                    clipboardText == null ? 'Clipboard: empty' : 'Clipboard: $clipboardText',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.capabilities,
    required this.platformBridgeGateway,
    required this.llmConfigRepository,
    required this.apiKeySecurityUseCase,
    required this.llmConnectionTester,
    required this.onOverlayFontSizeChanged,
    required this.onHistoryOverlayLimitChanged,
  });

  final BridgeCapabilities? capabilities;
  final PlatformBridgeGateway platformBridgeGateway;
  final LlmConfigRepository? llmConfigRepository;
  final ApiKeySecurityUseCase? apiKeySecurityUseCase;
  final LlmConnectionTester? llmConnectionTester;
  final ValueChanged<double> onOverlayFontSizeChanged;
  final ValueChanged<int> onHistoryOverlayLimitChanged;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _topPController = TextEditingController();
  final TextEditingController _maxTokensController = TextEditingController();
  final TextEditingController _timeoutMsController = TextEditingController();
  final TextEditingController _overlayFontSizeController = TextEditingController();
  final TextEditingController _historyOverlayLimitController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  String? _apiKeyRef;
  String statusMessage = 'Configuration not saved';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _temperatureController.dispose();
    _topPController.dispose();
    _maxTokensController.dispose();
    _timeoutMsController.dispose();
    _overlayFontSizeController.dispose();
    _historyOverlayLimitController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final configRepository = widget.llmConfigRepository;
    if (configRepository == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
      return;
    }

    final activeConfig = await configRepository.loadActive();
    if (!mounted) {
      return;
    }

    if (activeConfig != null) {
      _applyConfig(activeConfig);
      widget.onOverlayFontSizeChanged(activeConfig.overlayFontSizeSp);
      widget.onHistoryOverlayLimitChanged(activeConfig.historyOverlayLimit);
      statusMessage = 'Loaded saved configuration';
    } else {
      final fontSizeSp = await widget.platformBridgeGateway.getOverlayFontSizeSp();
      _overlayFontSizeController.text = fontSizeSp.toStringAsFixed(1);
      widget.onOverlayFontSizeChanged(fontSizeSp);
      _historyOverlayLimitController.text = '3';
      widget.onHistoryOverlayLimitChanged(3);
    }

    setState(() {
      _loading = false;
    });
  }

  void _applyConfig(LlmConfig config) {
    _baseUrlController.text = config.baseUrl;
    _apiKeyRef = config.apiKeyRef;
    _modelController.text = config.model;
    _temperatureController.text = config.temperature.toString();
    _topPController.text = config.topP.toString();
    _maxTokensController.text = config.maxTokens.toString();
    _timeoutMsController.text = config.timeoutMs.toString();
    _overlayFontSizeController.text = config.overlayFontSizeSp.toStringAsFixed(1);
    _historyOverlayLimitController.text = config.historyOverlayLimit.toString();
    _systemPromptController.text = config.systemPrompt;
  }

  Future<void> _saveConfig() async {
    final configRepository = widget.llmConfigRepository;
    if (configRepository == null) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    var resolvedApiKeyRef = _apiKeyRef;
    final apiKeyValue = _apiKeyController.text.trim();

    if (apiKeyValue.isNotEmpty) {
      final apiKeySecurityUseCase = widget.apiKeySecurityUseCase;
      if (apiKeySecurityUseCase == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          statusMessage = 'API key store is unavailable';
        });
        return;
      }

      final storeResult = await apiKeySecurityUseCase.store(
        apiKeyValue,
        keyRef: resolvedApiKeyRef,
      );

      if (!storeResult.isSuccess || storeResult.value == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          statusMessage = storeResult.failure?.message ?? 'Failed to store API key';
        });
        return;
      }

      resolvedApiKeyRef = storeResult.value;
      _apiKeyRef = resolvedApiKeyRef;
    }

    final config = LlmConfig(
      id: 'active-config',
      provider: 'openai-compatible',
      baseUrl: _baseUrlController.text.trim(),
      apiKeyRef: resolvedApiKeyRef,
      model: _modelController.text.trim(),
      temperature: double.parse(_temperatureController.text.trim()),
      topP: double.parse(_topPController.text.trim()),
      maxTokens: int.parse(_maxTokensController.text.trim()),
      timeoutMs: int.parse(_timeoutMsController.text.trim()),
      overlayFontSizeSp: double.parse(_overlayFontSizeController.text.trim()),
      historyOverlayLimit: int.parse(_historyOverlayLimitController.text.trim()),
      systemPrompt: _systemPromptController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await configRepository.saveActive(config);
    await widget.platformBridgeGateway.setOverlayFontSizeSp(config.overlayFontSizeSp);
    widget.onOverlayFontSizeChanged(config.overlayFontSizeSp);
    widget.onHistoryOverlayLimitChanged(config.historyOverlayLimit);
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Configuration saved';
    });
  }

  Future<void> _testConnection() async {
    final tester = widget.llmConnectionTester;
    if (tester == null) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    var resolvedApiKeyRef = _apiKeyRef;
    final rawApiKey = _apiKeyController.text.trim();
    if (rawApiKey.isNotEmpty) {
      final apiKeySecurityUseCase = widget.apiKeySecurityUseCase;
      if (apiKeySecurityUseCase == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          statusMessage = 'Connection failed: API key storage unavailable.';
        });
        return;
      }

      final storeResult = await apiKeySecurityUseCase.store(
        rawApiKey,
        keyRef: resolvedApiKeyRef ?? 'active-api-key',
      );
      if (!storeResult.isSuccess || storeResult.value == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          statusMessage = storeResult.failure?.message ?? 'Connection failed: unable to store API key.';
        });
        return;
      }

      resolvedApiKeyRef = storeResult.value;
      _apiKeyRef = resolvedApiKeyRef;
    }

    if (resolvedApiKeyRef == null || resolvedApiKeyRef.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        statusMessage = 'Connection failed: API key is missing.';
      });
      return;
    }

    final config = LlmConfig(
      id: 'active-config',
      provider: 'openai-compatible',
      baseUrl: _baseUrlController.text.trim(),
      apiKeyRef: resolvedApiKeyRef,
      model: _modelController.text.trim(),
      temperature: double.parse(_temperatureController.text.trim()),
      topP: double.parse(_topPController.text.trim()),
      maxTokens: int.parse(_maxTokensController.text.trim()),
      timeoutMs: int.parse(_timeoutMsController.text.trim()),
      overlayFontSizeSp: double.parse(_overlayFontSizeController.text.trim()),
      historyOverlayLimit: int.parse(_historyOverlayLimitController.text.trim()),
      systemPrompt: _systemPromptController.text.trim(),
      updatedAt: DateTime.now(),
    );

    final result = await tester.test(config);
    if (!mounted) {
      return;
    }

    setState(() {
      if (result.isSuccess) {
        statusMessage = '${result.message ?? 'Connection success'} (${result.latencyMs ?? 0} ms)';
      } else {
        statusMessage = result.errorMessage ?? 'Connection failed';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.capabilities;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text('Model configuration and permissions will be edited here later.'),
        const SizedBox(height: 20),
        _SummaryCard(
          title: 'Bridge',
          lines: [
            'Method channel: ${bridge?.methodChannelName ?? 'pending'}',
            'Event channel: ${bridge?.eventChannelName ?? 'pending'}',
            'Clipboard: ${bridge?.supportsClipboard == true ? 'supported' : 'pending'}',
            'Overlay: ${bridge?.supportsOverlay == true ? 'supported' : 'pending'}',
            'Floating bubble: ${bridge?.supportsFloatingBubble == true ? 'supported' : 'pending'}',
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LLM Configuration', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _TextFieldRow(controller: _baseUrlController, label: 'Base URL', validator: _requiredText),
                  _TextFieldRow(controller: _apiKeyController, label: 'API Key', validator: _optionalText, obscureText: true),
                  _TextFieldRow(controller: _modelController, label: 'Model', validator: _requiredText),
                  _TextFieldRow(controller: _temperatureController, label: 'Temperature', validator: _doubleText),
                  _TextFieldRow(controller: _topPController, label: 'Top P', validator: _doubleText),
                  _TextFieldRow(controller: _maxTokensController, label: 'Max Tokens', validator: _intText),
                  _TextFieldRow(controller: _timeoutMsController, label: 'Timeout (ms)', validator: _intText),
                  _TextFieldRow(
                    controller: _overlayFontSizeController,
                    label: 'Overlay Font Size (sp)',
                    validator: _overlayFontSizeText,
                  ),
                  _TextFieldRow(
                    controller: _historyOverlayLimitController,
                    label: 'History Overlay Limit',
                    validator: _historyOverlayLimitText,
                  ),
                  _TextFieldRow(controller: _systemPromptController, label: 'System Prompt', validator: _requiredText, maxLines: 3),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saveConfig,
                    child: const Text('Save configuration'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _testConnection,
                    child: const Text('Test connection'),
                  ),
                  const SizedBox(height: 12),
                  Text(statusMessage),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _optionalText(String? value) => null;

  String? _doubleText(String? value) {
    final parsedValue = double.tryParse(value ?? '');
    if (parsedValue == null) {
      return 'Enter a number';
    }
    return null;
  }

  String? _intText(String? value) {
    final parsedValue = int.tryParse(value ?? '');
    if (parsedValue == null) {
      return 'Enter an integer';
    }
    return null;
  }

  String? _overlayFontSizeText(String? value) {
    final parsedValue = double.tryParse(value ?? '');
    if (parsedValue == null) {
      return 'Enter a number';
    }

    if (parsedValue < 12 || parsedValue > 28) {
      return 'Use 12-28';
    }

    return null;
  }

  String? _historyOverlayLimitText(String? value) {
    final parsedValue = int.tryParse(value ?? '');
    if (parsedValue == null) {
      return 'Enter an integer';
    }

    if (parsedValue < 1 || parsedValue > 50) {
      return 'Use 1-50';
    }

    return null;
  }
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.controller,
    required this.label,
    required this.validator,
    this.maxLines = 1,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final int maxLines;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: validator,
        maxLines: maxLines,
        obscureText: obscureText,
      ),
    );
  }
}

class _HistorySection extends StatefulWidget {
  const _HistorySection({required this.translationHistoryUseCase});

  final TranslationHistoryUseCase? translationHistoryUseCase;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  String statusMessage = 'History source not connected';
  List<TranslationRecord> records = const <TranslationRecord>[];
  bool loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final historyUseCase = widget.translationHistoryUseCase;
    if (historyUseCase == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });
      return;
    }

    final result = await historyUseCase.loadRecent(limit: 20);
    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
      if (result.isSuccess && result.value != null) {
        records = result.value!;
        statusMessage = records.isEmpty ? 'No history yet' : 'Loaded ${records.length} records';
      } else {
        statusMessage = result.failure?.message ?? 'History failed to load';
      }
    });
  }

  Future<void> _searchHistory() async {
    final historyUseCase = widget.translationHistoryUseCase;
    if (historyUseCase == null) {
      return;
    }

    final query = _searchController.text.trim();
    final result = query.isEmpty
        ? await historyUseCase.loadRecent(limit: 20)
        : await historyUseCase.search(query);

    if (!mounted) {
      return;
    }

    setState(() {
      if (result.isSuccess && result.value != null) {
        records = result.value!;
        if (query.isEmpty) {
          statusMessage = records.isEmpty ? 'No history yet' : 'Loaded ${records.length} records';
        } else {
          statusMessage = 'Search found ${records.length} records';
        }
      } else {
        statusMessage = result.failure?.message ?? 'History search failed';
      }
    });
  }

  Future<void> _clearAll() async {
    final historyUseCase = widget.translationHistoryUseCase;
    if (historyUseCase == null) {
      return;
    }

    final result = await historyUseCase.clearAll();
    if (!mounted) {
      return;
    }

    setState(() {
      if (result.isSuccess) {
        final deleted = result.value ?? 0;
        records = const <TranslationRecord>[];
        statusMessage = 'Cleared $deleted records';
      } else {
        statusMessage = result.failure?.message ?? 'Failed to clear history';
      }
    });
  }

  Future<void> _deleteRecord(String id) async {
    final historyUseCase = widget.translationHistoryUseCase;
    if (historyUseCase == null) {
      return;
    }

    final result = await historyUseCase.deleteById(id);
    if (!mounted) {
      return;
    }

    setState(() {
      if (result.isSuccess) {
        records = records.where((record) => record.id != id).toList();
        statusMessage = 'Deleted 1 record';
      } else {
        statusMessage = result.failure?.message ?? 'Failed to delete record';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Text(
          'History',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(statusMessage),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search history',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _searchHistory,
              child: const Text('Search'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: records.isEmpty ? null : _clearAll,
              child: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (records.isEmpty)
          const _SummaryCard(
            title: 'Empty state',
            lines: [
              'Translation records will appear here after the first successful run.',
            ],
          )
        else
          ...records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SummaryCard(
                title: record.sourceText,
                lines: [
                  record.translatedText,
                  'Status: ${record.status.name}',
                  'Model: ${record.model}',
                ],
                trailing: TextButton(
                  onPressed: () => _deleteRecord(record.id),
                  child: const Text('Delete'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines, this.trailing});

  final String title;
  final List<String> lines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}

class _DefaultPlatformBridgeGateway extends MethodChannelPlatformBridgeGateway {
  _DefaultPlatformBridgeGateway()
      : super(
          methodChannel: const MethodChannel('modeltranslation/platform'),
          eventChannel: const EventChannel('modeltranslation/action_events'),
        );
}