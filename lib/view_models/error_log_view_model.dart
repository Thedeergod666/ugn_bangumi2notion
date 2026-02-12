import 'package:flutter/foundation.dart';

import '../services/logging.dart';

class ErrorLogViewModel extends ChangeNotifier {
  ErrorLogViewModel({required Logger logger}) : _logger = logger {
    _logger.addListener(_handleLoggerChanged);
  }

  final Logger _logger;

  List<LogEntry> get entries =>
      _logger.entriesForLevel(LogLevel.error).toList().reversed.toList();

  bool get canCopy => entries.isNotEmpty;

  String exportText() => _logger.exportText(level: LogLevel.error);

  void clear() => _logger.clear();

  void _handleLoggerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.removeListener(_handleLoggerChanged);
    super.dispose();
  }
}
