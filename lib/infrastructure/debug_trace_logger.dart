import 'dart:developer' as developer;

abstract class DebugTraceLogger {
  bool get enabled;

  void log(String message);

  factory DebugTraceLogger.enabled({String name = 'ModelTranslation'}) {
    return _DeveloperDebugTraceLogger(name: name);
  }

  factory DebugTraceLogger.disabled() {
    return _NoopDebugTraceLogger();
  }
}

class _DeveloperDebugTraceLogger implements DebugTraceLogger {
  _DeveloperDebugTraceLogger({required this.name});

  final String name;

  @override
  bool get enabled => true;

  @override
  void log(String message) {
    developer.log(message, name: name);
  }
}

class _NoopDebugTraceLogger implements DebugTraceLogger {
  @override
  bool get enabled => false;

  @override
  void log(String message) {}
}
