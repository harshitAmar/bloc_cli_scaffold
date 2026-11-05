import 'dart:io';

/// Example usage of bloc_cli.
///
/// Run this example from the root of an existing Flutter project:
///
/// dart run example/main.dart
///
/// The example demonstrates:
/// 1. Checking whether the current directory is a Flutter project.
/// 2. Running bloc_cli init.
/// 3. Generating an auth feature.

Future<void> main() async {
  stdout.writeln('bloc_cli example');
  stdout.writeln('================');

  final currentDirectory = Directory.current;

  final pubspecFile = File('${currentDirectory.path}/pubspec.yaml');

  if (!await pubspecFile.exists()) {
    stderr.writeln(
      'Error: No pubspec.yaml found. '
      'Run this example from a Flutter project root.',
    );
    exitCode = 1;
    return;
  }

  final pubspecContent = await pubspecFile.readAsString();

  if (!pubspecContent.contains('flutter:')) {
    stderr.writeln('Error: The current directory is not a Flutter project.');
    exitCode = 1;
    return;
  }

  stdout.writeln('Flutter project detected.');
  stdout.writeln();

  await _runCommand('bloc_cli', ['--version']);

  stdout.writeln('\nInitializing project architecture...');

  await _runCommand('bloc_cli', ['init']);

  stdout.writeln('\nGenerating auth feature...');

  await _runCommand('bloc_cli', ['create', 'feature', 'auth']);

  stdout.writeln('\nExample completed.');
}

Future<void> _runCommand(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments, runInShell: true);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Command failed with exit code ${result.exitCode}',
      result.exitCode,
    );
  }
}
