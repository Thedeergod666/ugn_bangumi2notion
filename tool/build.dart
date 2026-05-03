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

  final buildArgs = <String>['build', _resolveBuildTarget(platform)];
  if (parsed.mode != null) {
    buildArgs.add(parsed.mode!);
  }

  if (clientId.isNotEmpty) {
    buildArgs.add('--dart-define=BANGUMI_CLIENT_ID=$clientId');
  }
  if (clientSecret.isNotEmpty) {
    buildArgs.add('--dart-define=BANGUMI_CLIENT_SECRET=$clientSecret');
  }

  final command = Platform.isWindows ? 'cmd' : 'flutter';
  final commandArgs =
      Platform.isWindows ? <String>['/c', 'flutter', ...buildArgs] : buildArgs;

  final process = await Process.start(
    command,
    commandArgs,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    exit(exitCode);
  }

  if (platform == 'windows' && parsed.mode != '--debug') {
    try {
      await _copyWindowsVcRuntimeDlls();
    } catch (error) {
      stderr.writeln('ERROR: $error');
      exit(70);
    }
  }

  exit(0);
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

String _resolveBuildTarget(String platform) {
  if (platform == 'android') {
    return 'apk';
  }
  return platform;
}

const _windowsVcRuntimeDlls = <String>[
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
];

Future<void> _copyWindowsVcRuntimeDlls() async {
  if (!Platform.isWindows) {
    return;
  }

  final releaseDir = Directory(
    _joinPath([
      Directory.current.path,
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
    ]),
  );
  if (!await releaseDir.exists()) {
    throw StateError(
      'Windows Release bundle not found at ${releaseDir.path}.',
    );
  }

  final sourceDirs = _windowsVcRuntimeSourceDirs();
  final missingDlls = <String>[];

  for (final dllName in _windowsVcRuntimeDlls) {
    final source = await _findFirstExistingFile(sourceDirs, dllName);
    if (source == null) {
      missingDlls.add(dllName);
      continue;
    }

    final destination = File(_joinPath([releaseDir.path, dllName]));
    await source.copy(destination.path);
    stdout.writeln('Copied $dllName into ${releaseDir.path}');
  }

  if (missingDlls.isNotEmpty) {
    throw StateError(
      'Missing Visual C++ runtime DLL(s): ${missingDlls.join(', ')}. '
      'Install the Microsoft Visual C++ Redistributable, or set '
      'FLUTTER_UTOOLS_VC_RUNTIME_DIR to a directory containing these DLLs.',
    );
  }
}

List<Directory> _windowsVcRuntimeSourceDirs() {
  final dirs = <Directory>[];
  final overrideDir = Platform.environment['FLUTTER_UTOOLS_VC_RUNTIME_DIR'];
  if (overrideDir != null && overrideDir.trim().isNotEmpty) {
    dirs.add(Directory(overrideDir.trim()));
  }

  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  dirs.add(Directory(_joinPath([windir, 'System32'])));

  for (final programFilesKey in ['ProgramFiles', 'ProgramFiles(x86)']) {
    final programFiles = Platform.environment[programFilesKey];
    if (programFiles == null || programFiles.isEmpty) {
      continue;
    }
    dirs.addAll(
      _findVcRedistDirectories(
        Directory(_joinPath([programFiles, 'Microsoft Visual Studio'])),
      ),
    );
  }

  return dirs;
}

List<Directory> _findVcRedistDirectories(Directory visualStudioDir) {
  if (!visualStudioDir.existsSync()) {
    return const [];
  }

  final dirs = <Directory>[];
  for (final entity in visualStudioDir.listSync(recursive: true)) {
    if (entity is! Directory) {
      continue;
    }
    final normalized = entity.path.toLowerCase();
    if (normalized.endsWith(r'\x64\microsoft.vc143.crt') ||
        normalized.endsWith(r'\x64\microsoft.vc142.crt')) {
      dirs.add(entity);
    }
  }
  return dirs;
}

Future<File?> _findFirstExistingFile(
  List<Directory> sourceDirs,
  String fileName,
) async {
  for (final dir in sourceDirs) {
    final file = File(_joinPath([dir.path, fileName]));
    if (await file.exists()) {
      return file;
    }
  }
  return null;
}

String _joinPath(List<String> parts) {
  return parts.join(Platform.pathSeparator);
}
