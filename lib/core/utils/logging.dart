import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../database/settings_storage.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'errorString': error?.toString(),
      'stackTraceString': stackTrace?.toString(),
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final timestampText = json['timestamp']?.toString() ?? '';
    final levelText = json['level']?.toString() ?? '';
    final message = json['message']?.toString() ?? '';
    final errorText = json['errorString']?.toString() ?? '';
    final stackText = json['stackTraceString']?.toString() ?? '';

    final parsedTimestamp =
        DateTime.tryParse(timestampText)?.toLocal() ?? DateTime.now();
    final parsedLevel = LogLevel.values.firstWhere(
      (item) => item.name == levelText,
      orElse: () => LogLevel.error,
    );

    return LogEntry(
      timestamp: parsedTimestamp,
      level: parsedLevel,
      message: message,
      error: errorText.isEmpty ? null : errorText,
      stackTrace: stackText.isEmpty ? null : StackTrace.fromString(stackText),
    );
  }
}

class Logger extends ChangeNotifier {
  Logger({
    LogLevel? level,
    int maxEntries = 300,
    SettingsStorage? storage,
  })  : level = level ?? (kDebugMode ? LogLevel.debug : LogLevel.error),
        _maxEntries = maxEntries,
        _storage = storage ?? SettingsStorage();

  final LogLevel level;
  final int _maxEntries;
  final SettingsStorage _storage;
  final List<LogEntry> _entries = [];
  Future<void>? _pendingPersist;
  bool _restored = false;

  static const int _errorLogCacheVersion = 1;

  UnmodifiableListView<LogEntry> get entries => UnmodifiableListView(_entries);

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
      unawaited(_storage.clearErrorLogCache());
      return;
    }
    _entries.clear();
    unawaited(_storage.clearErrorLogCache());
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

  Future<void> restorePersistedErrors() async {
    if (_restored) {
      return;
    }
    _restored = true;

    final payload = await _storage.getErrorLogCache(
      minVersion: _errorLogCacheVersion,
    );
    if (payload == null) {
      return;
    }

    final rawEntries = payload['entries'];
    if (rawEntries is! List) {
      return;
    }

    var changed = false;
    for (final item in rawEntries) {
      if (item is! Map) {
        continue;
      }
      final map =
          item is Map<String, dynamic> ? item : item.cast<String, dynamic>();
      final entry = LogEntry.fromJson(map);
      if (entry.level != LogLevel.error) {
        continue;
      }
      _entries.add(entry);
      changed = true;
    }

    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> waitForPersistence() async {
    await _pendingPersist;
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
    if (level == LogLevel.error) {
      _pendingPersist = _enqueueErrorPersistence();
    }
    notifyListeners();
  }

  Future<void> _enqueueErrorPersistence() {
    final previous = _pendingPersist;
    if (previous == null) {
      return _persistErrorEntries();
    }
    return previous.catchError((_) {
      // Keep the queue alive if a previous write failed.
    }).then((_) => _persistErrorEntries());
  }

  Future<void> _persistErrorEntries() async {
    final errors = _entries.where((item) => item.level == LogLevel.error);
    final payload = errors.map((item) => item.toJson()).toList();
    if (payload.isEmpty) {
      await _storage.clearErrorLogCache();
      return;
    }
    await _storage.saveErrorLogCache(
      version: _errorLogCacheVersion,
      data: {
        'entries': payload,
      },
    );
  }
}
