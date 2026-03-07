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
}
