import 'dart:io';

const supportedPlatforms = <String>{
  'windows',
  'macos',
  'linux',
  'android',
  'ios',
  'web',
};

void main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed.showHelp) {
    _printUsage();
    exit(parsed.exitCode);
  }

  final platform = parsed.platform;
  if (platform == null || !supportedPlatforms.contains(platform)) {
    stderr.writeln('ERROR: 请使用 --platform 指定构建平台。');
    _printUsage();
    exit(64);
  }

  final clientId = Platform.environment['BANGUMI_CLIENT_ID']?.trim() ?? '';
  final clientSecret =
      Platform.environment['BANGUMI_CLIENT_SECRET']?.trim() ?? '';

  if (clientId.isEmpty || clientSecret.isEmpty) {
    stderr.writeln(
      'WARNING: BANGUMI_CLIENT_ID/BANGUMI_CLIENT_SECRET 未设置，'
      'Bangumi 授权功能不可用；需要重新打包并注入 dart-define。',
    );
  }

  final buildArgs = <String>['build', platform];
  if (parsed.mode != null) {
    buildArgs.add(parsed.mode!);
  }

  if (clientId.isNotEmpty) {
    buildArgs.add('--dart-define=BANGUMI_CLIENT_ID=$clientId');
  }
  if (clientSecret.isNotEmpty) {
    buildArgs.add('--dart-define=BANGUMI_CLIENT_SECRET=$clientSecret');
  }

  final process = await Process.start(
    'flutter',
    buildArgs,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  exit(exitCode);
}

void _printUsage() {
  stdout.writeln('''\
用法:
  dart run tool/build.dart --platform <windows|macos|linux|android|ios|web> [--release|--debug]

示例:
  dart run tool/build.dart --platform windows --release
  dart run tool/build.dart --platform macos
''');
}

class _ParsedArgs {
  _ParsedArgs({
    required this.platform,
    required this.mode,
    required this.showHelp,
    required this.exitCode,
  });

  final String? platform;
  final String? mode;
  final bool showHelp;
  final int exitCode;
}

_ParsedArgs _parseArgs(List<String> args) {
  String? platform;
  String? mode;
  var showHelp = false;
  var exitCode = 0;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }
    if (arg == '--release' || arg == '--debug') {
      if (mode != null && mode != arg) {
        stderr.writeln('ERROR: 不能同时指定 --release 和 --debug。');
        showHelp = true;
        exitCode = 64;
      }
      mode = arg;
      continue;
    }
    if (arg.startsWith('--platform=')) {
      platform = arg.split('=').last.trim();
      continue;
    }
    if (arg == '--platform') {
      if (i + 1 >= args.length) {
        stderr.writeln('ERROR: --platform 需要参数。');
        showHelp = true;
        exitCode = 64;
        break;
      }
      platform = args[i + 1].trim();
      i++;
      continue;
    }

    stderr.writeln('ERROR: 未识别参数: $arg');
    showHelp = true;
    exitCode = 64;
  }

  return _ParsedArgs(
    platform: platform,
    mode: mode,
    showHelp: showHelp,
    exitCode: exitCode,
  );
}
