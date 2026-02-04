import 'package:flutter/foundation.dart';

enum LogLevel {
  off,
  error,
  info,
  debug,
}

class Logger {
  Logger({LogLevel? level})
      : level = level ?? (kDebugMode ? LogLevel.debug : LogLevel.error);

  final LogLevel level;

  bool get _canDebug => level.index >= LogLevel.debug.index;
  bool get _canInfo => level.index >= LogLevel.info.index;
  bool get _canError => level.index >= LogLevel.error.index;

  void debug(String message) {
    if (_canDebug) {
      debugPrint(message);
    }
  }

  void info(String message) {
    if (_canInfo) {
      debugPrint(message);
    }
  }

  void error(String message) {
    if (_canError) {
      debugPrint(message);
    }
  }
}
