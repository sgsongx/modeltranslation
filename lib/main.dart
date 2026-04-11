import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/bridge/method_channel_platform_bridge_gateway.dart';
import 'core/domain/gateways/platform_bridge_gateway.dart';
import 'core/application/translation_history_use_case.dart';
import 'core/domain/translation_record.dart';
import 'core/domain/gateways/llm_config_repository.dart';
import 'core/domain/llm_config.dart';

void main() {
  runApp(ModelTranslationApp());
}

class ModelTranslationApp extends StatelessWidget {
  ModelTranslationApp({
    super.key,
    PlatformBridgeGateway? platformBridgeGateway,
    TranslationHistoryUseCase? translationHistoryUseCase,
      LlmConfigRepository? llmConfigRepository,
  })  : platformBridgeGateway = platformBridgeGateway ?? _DefaultPlatformBridgeGateway(),
      translationHistoryUseCase = translationHistoryUseCase,
      llmConfigRepository = llmConfigRepository;

  final PlatformBridgeGateway platformBridgeGateway;
  final TranslationHistoryUseCase? translationHistoryUseCase;
    final LlmConfigRepository? llmConfigRepository;

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
  });

  final PlatformBridgeGateway platformBridgeGateway;
  final TranslationHistoryUseCase? translationHistoryUseCase;
  final LlmConfigRepository? llmConfigRepository;

  @override
  State<TranslationShell> createState() => _TranslationShellState();
}

class _TranslationShellState extends State<TranslationShell> {
  String? clipboardText;
  String statusMessage = 'Ready';
  bool supportsFloatingBubble = false;
  BridgeCapabilities? capabilities;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final bridgeCapabilities = await widget.platformBridgeGateway.getCapabilities();
    if (!mounted) {
      return;
    }

    setState(() {
      capabilities = bridgeCapabilities;
      supportsFloatingBubble = bridgeCapabilities.supportsFloatingBubble;
      statusMessage = 'Bridge connected';
    });

    _eventSubscription = widget.platformBridgeGateway.watchActionEvents().listen((event) {
      setState(() {
        statusMessage = 'Action event: ${event.actionId}';
      });
    });
  }

  Future<void> _startBubble() async {
    await widget.platformBridgeGateway.startFloatingBubble();
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
                onStartBubble: _startBubble,
                onStopBubble: _stopBubble,
                onReadClipboard: _readClipboard,
              ),
              _SettingsSection(
                capabilities: capabilities,
                llmConfigRepository: widget.llmConfigRepository,
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
    required this.onStartBubble,
    required this.onStopBubble,
    required this.onReadClipboard,
  });

  final ColorScheme colorScheme;
  final String? clipboardText;
  final String statusMessage;
  final bool supportsFloatingBubble;
  final Future<void> Function() onStartBubble;
  final Future<void> Function() onStopBubble;
  final Future<void> Function() onReadClipboard;

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
                      onPressed: supportsFloatingBubble ? onStartBubble : null,
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
                  ],
                ),
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
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.capabilities,
    required this.llmConfigRepository,
  });

  final BridgeCapabilities? capabilities;
  final LlmConfigRepository? llmConfigRepository;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyRefController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _topPController = TextEditingController();
  final TextEditingController _maxTokensController = TextEditingController();
  final TextEditingController _timeoutMsController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
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
    _apiKeyRefController.dispose();
    _modelController.dispose();
    _temperatureController.dispose();
    _topPController.dispose();
    _maxTokensController.dispose();
    _timeoutMsController.dispose();
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
      statusMessage = 'Loaded saved configuration';
    }

    setState(() {
      _loading = false;
    });
  }

  void _applyConfig(LlmConfig config) {
    _baseUrlController.text = config.baseUrl;
    _apiKeyRefController.text = config.apiKeyRef ?? '';
    _modelController.text = config.model;
    _temperatureController.text = config.temperature.toString();
    _topPController.text = config.topP.toString();
    _maxTokensController.text = config.maxTokens.toString();
    _timeoutMsController.text = config.timeoutMs.toString();
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

    final config = LlmConfig(
      id: 'active-config',
      provider: 'openai-compatible',
      baseUrl: _baseUrlController.text.trim(),
      apiKeyRef: _apiKeyRefController.text.trim().isEmpty ? null : _apiKeyRefController.text.trim(),
      model: _modelController.text.trim(),
      temperature: double.parse(_temperatureController.text.trim()),
      topP: double.parse(_topPController.text.trim()),
      maxTokens: int.parse(_maxTokensController.text.trim()),
      timeoutMs: int.parse(_timeoutMsController.text.trim()),
      systemPrompt: _systemPromptController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await configRepository.saveActive(config);
    if (!mounted) {
      return;
    }

    setState(() {
      statusMessage = 'Configuration saved';
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
                  _TextFieldRow(controller: _apiKeyRefController, label: 'API Key Ref', validator: _optionalText),
                  _TextFieldRow(controller: _modelController, label: 'Model', validator: _requiredText),
                  _TextFieldRow(controller: _temperatureController, label: 'Temperature', validator: _doubleText),
                  _TextFieldRow(controller: _topPController, label: 'Top P', validator: _doubleText),
                  _TextFieldRow(controller: _maxTokensController, label: 'Max Tokens', validator: _intText),
                  _TextFieldRow(controller: _timeoutMsController, label: 'Timeout (ms)', validator: _intText),
                  _TextFieldRow(controller: _systemPromptController, label: 'System Prompt', validator: _requiredText, maxLines: 3),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saveConfig,
                    child: const Text('Save configuration'),
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
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.controller,
    required this.label,
    required this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: validator,
        maxLines: maxLines,
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

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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