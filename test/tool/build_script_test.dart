import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'android platform maps to flutter build apk and forwards dart-defines',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'flutter_utools_build_script_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final argsFile = File('${tempDir.path}\\captured_args.txt');
      final flutterShim = File('${tempDir.path}\\flutter.cmd');

      await flutterShim.writeAsString('''\
@echo off
setlocal
if "%FAKE_FLUTTER_ARGS_FILE%"=="" (
  exit /b 11
)
echo %*> "%FAKE_FLUTTER_ARGS_FILE%"
exit /b 0
''');

      final environment = Map<String, String>.from(Platform.environment);
      final pathKey = environment.keys.firstWhere(
        (key) => key.toLowerCase() == 'path',
        orElse: () => 'Path',
      );
      final currentPath = environment[pathKey] ?? '';
      environment
        ..[pathKey] = '${tempDir.path};$currentPath'
        ..['BANGUMI_CLIENT_ID'] = 'test-client-id'
        ..['BANGUMI_CLIENT_SECRET'] = 'test-client-secret'
        ..['FAKE_FLUTTER_ARGS_FILE'] = argsFile.path;

      final result = await Process.run(
        'cmd',
        ['/c', 'dart', 'run', 'tool/build.dart', '--platform', 'android'],
        workingDirectory: Directory.current.path,
        environment: environment,
      );

      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      expect(
        await argsFile.exists(),
        isTrue,
        reason: 'Fake flutter executable did not receive any arguments.',
      );

      final forwardedArgs = (await argsFile.readAsString()).trim();

      expect(forwardedArgs, startsWith('build apk'));
      expect(
        forwardedArgs,
        contains('--dart-define=BANGUMI_CLIENT_ID=test-client-id'),
      );
      expect(
        forwardedArgs,
        contains('--dart-define=BANGUMI_CLIENT_SECRET=test-client-secret'),
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'windows build copies Visual C++ runtime DLLs into release bundle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'flutter_utools_build_script_windows_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final argsFile = File('${tempDir.path}\\captured_args.txt');
      final flutterShim = File('${tempDir.path}\\flutter.cmd');
      final vcRuntimeDir = Directory('${tempDir.path}\\vc_runtime');
      final releaseDir = Directory(
        '${tempDir.path}\\project\\build\\windows\\x64\\runner\\Release',
      );

      await vcRuntimeDir.create(recursive: true);
      await releaseDir.create(recursive: true);

      for (final dllName in [
        'msvcp140.dll',
        'vcruntime140.dll',
        'vcruntime140_1.dll',
      ]) {
        await File('${vcRuntimeDir.path}\\$dllName').writeAsString(dllName);
      }

      await flutterShim.writeAsString('''\
@echo off
setlocal
if "%FAKE_FLUTTER_ARGS_FILE%"=="" (
  exit /b 11
)
echo %*> "%FAKE_FLUTTER_ARGS_FILE%"
exit /b 0
''');

      final environment = Map<String, String>.from(Platform.environment);
      final pathKey = environment.keys.firstWhere(
        (key) => key.toLowerCase() == 'path',
        orElse: () => 'Path',
      );
      final currentPath = environment[pathKey] ?? '';
      environment
        ..[pathKey] = '${tempDir.path};$currentPath'
        ..['FAKE_FLUTTER_ARGS_FILE'] = argsFile.path
        ..['FLUTTER_UTOOLS_VC_RUNTIME_DIR'] = vcRuntimeDir.path;

      final result = await Process.run(
        'cmd',
        [
          '/c',
          'dart',
          'run',
          '${Directory.current.path}\\tool\\build.dart',
          '--platform',
          'windows',
        ],
        workingDirectory: '${tempDir.path}\\project',
        environment: environment,
      );

      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      for (final dllName in [
        'msvcp140.dll',
        'vcruntime140.dll',
        'vcruntime140_1.dll',
      ]) {
        final copiedDll = File('${releaseDir.path}\\$dllName');
        expect(await copiedDll.exists(), isTrue, reason: '$dllName not copied');
        expect(await copiedDll.readAsString(), dllName);
      }
    },
    skip: !Platform.isWindows,
  );
}
