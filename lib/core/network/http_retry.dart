import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'logging.dart';

Future<http.Response> sendWithRetry({
  required Logger logger,
  required Future<http.Response> Function() request,
  int maxRetries = 2,
  Duration baseDelay = const Duration(milliseconds: 400),
  bool Function(http.Response response)? shouldRetry,
  String? label,
}) async {
  var attempt = 0;
  while (true) {
    try {
      final response = await request();
      final retryable = shouldRetry?.call(response) ?? _defaultRetry(response);
      if (!retryable || attempt >= maxRetries) {
        return response;
      }

      final delay = _computeDelay(baseDelay, attempt);
      logger.info(
        '${label ?? 'request'} retry ${attempt + 1}/$maxRetries '
        'after ${delay.inMilliseconds}ms (status=${response.statusCode})',
      );
      await Future.delayed(delay);
    } on TimeoutException catch (e) {
      if (attempt >= maxRetries) {
        rethrow;
      }
      final delay = _computeDelay(baseDelay, attempt);
      logger.info(
        '${label ?? 'request'} timeout, retry ${attempt + 1}/$maxRetries '
        'after ${delay.inMilliseconds}ms (${e.message ?? 'timeout'})',
      );
      await Future.delayed(delay);
    } on SocketException catch (e) {
      if (attempt >= maxRetries) {
        rethrow;
      }
      final delay = _computeDelay(baseDelay, attempt);
      logger.info(
        '${label ?? 'request'} socket error, retry ${attempt + 1}/$maxRetries '
        'after ${delay.inMilliseconds}ms (${e.message})',
      );
      await Future.delayed(delay);
    }
    attempt += 1;
  }
}

bool _defaultRetry(http.Response response) {
  return response.statusCode == 429 || response.statusCode >= 500;
}

Duration _computeDelay(Duration base, int attempt) {
  final jitterMs = Random().nextInt(120);
  final multiplier = pow(2, attempt).toInt();
  return Duration(
    milliseconds: base.inMilliseconds * multiplier + jitterMs,
  );
}
