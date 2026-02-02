import 'dart:io';

class BangumiOAuthConfig {
  static String get clientId {
    final runtime = Platform.environment['BANGUMI_CLIENT_ID']?.trim() ?? '';
    if (runtime.isNotEmpty) {
      return runtime;
    }
    return const String.fromEnvironment('BANGUMI_CLIENT_ID');
  }

  static String get clientSecret {
    final runtime = Platform.environment['BANGUMI_CLIENT_SECRET']?.trim() ?? '';
    if (runtime.isNotEmpty) {
      return runtime;
    }
    return const String.fromEnvironment(
      'BANGUMI_CLIENT_SECRET',
      defaultValue: '',
    );
  }

  static const String redirectUri = 'http://localhost:8080/auth/callback';

  static List<String> get missingKeys {
    final missing = <String>[];
    if (clientId.isEmpty) {
      missing.add('BANGUMI_CLIENT_ID');
    }
    return missing;
  }

  static bool get isConfigured => missingKeys.isEmpty;

  static String get missingMessage {
    if (missingKeys.isEmpty) {
      return '';
    }
    return '缺少 Bangumi OAuth 配置：${missingKeys.join('、')}';
  }

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        '缺少 Bangumi OAuth 配置：请在运行/打包时传入 '
        '--dart-define=BANGUMI_CLIENT_ID=... '
        '--dart-define=BANGUMI_CLIENT_SECRET=...（可选）。',
      );
    }
  }
}
