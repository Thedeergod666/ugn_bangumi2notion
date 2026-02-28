import 'dart:collection';

import 'package:flutter/foundation.dart';

enum LogLevel {
  off,
  error,
  info,
  debug,
}

class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String get formattedTime {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final h = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('[$formattedTime] [${level.name.toUpperCase()}] $message');
    if (error != null) {
      buffer.writeln('Error: $error');
    }
    if (stackTrace != null) {
      buffer.writeln('StackTrace:\n$stackTrace');
    }
    return buffer.toString().trimRight();
  }
}

class Logger extends ChangeNotifier {
  Logger({LogLevel? level, int maxEntries = 300})
      : level = level ?? (kDebugMode ? LogLevel.debug : LogLevel.error),
        _maxEntries = maxEntries;

  final LogLevel level;
  final int _maxEntries;
  final List<LogEntry> _entries = [];

  UnmodifiableListView<LogEntry> get entries =>
      UnmodifiableListView(_entries);

  bool get _canDebug => level.index >= LogLevel.debug.index;
  bool get _canInfo => level.index >= LogLevel.info.index;
  bool get _canError => level.index >= LogLevel.error.index;

  void debug(String message) {
    if (!_canDebug) {
      return;
    }
    _add(LogLevel.debug, message);
    debugPrint(message);
  }

  void info(String message) {
    if (!_canInfo) {
      return;
    }
    _add(LogLevel.info, message);
    debugPrint(message);
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_canError) {
      return;
    }
    _add(LogLevel.error, message, error: error, stackTrace: stackTrace);
    if (error != null || stackTrace != null) {
      debugPrint('$message\n$error\n$stackTrace');
    } else {
      debugPrint(message);
    }
  }

  void clear() {
    if (_entries.isEmpty) {
      return;
    }
    _entries.clear();
    notifyListeners();
  }

  Iterable<LogEntry> entriesForLevel(LogLevel? level) {
    if (level == null) {
      return entries;
    }
    return entries.where((entry) => entry.level == level);
  }

  String exportText({LogLevel? level}) {
    final buffer = StringBuffer();
    final items = entriesForLevel(level);
    for (final entry in items) {
      buffer.writeln(entry.toPlainText());
      buffer.writeln('');
    }
    return buffer.toString().trimRight();
  }

  void _add(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _entries.add(
      LogEntry(
        level: level,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    notifyListeners();
  }
}
