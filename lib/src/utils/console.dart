import 'dart:io';

/// Provides consistent terminal output and interactive selection prompts.
class Console {
  /// Prints [value] as a section heading.
  static void title(String value) {
    stdout.writeln('\n$value');
    stdout.writeln('=' * value.length);
  }

  /// Prints an informational [value] to standard output.
  static void info(String value) => stdout.writeln('ℹ  $value');

  /// Prints a successful operation message.
  static void success(String value) => stdout.writeln('✓  $value');

  /// Prints an error [value] to standard error.
  static void error(String value) => stderr.writeln('✗  $value');

  /// Prompts for one of [options] and returns the selected label.
  ///
  /// [defaults] is the zero-based option selected when the user presses Enter.
  static String choose(String question, List<String> options,
      {int defaults = 0}) {
    stdout.writeln('\n$question');
    for (var i = 0; i < options.length; i++) {
      final marker = i == defaults ? ' (default)' : '';
      stdout.writeln('  ${i + 1}. ${options[i]}$marker');
    }
    while (true) {
      stdout.write('Select [${defaults + 1}]: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input.isEmpty) return options[defaults];
      final index = int.tryParse(input);
      if (index != null && index >= 1 && index <= options.length) {
        return options[index - 1];
      }
      error('Enter a number between 1 and ${options.length}.');
    }
  }
}
