import 'dart:io';

/// Helpers for validating and naming Flutter project resources.
class Project {
  /// Returns whether [root] contains a Flutter package manifest.
  static Future<bool> isFlutterProject(Directory root) async {
    final file = File('${root.path}/pubspec.yaml');
    if (!await file.exists()) {
      return false;
    }
    final content = await file.readAsString();
    return RegExp(r'^flutter\s*:', multiLine: true).hasMatch(content);
  }

  /// Converts [input] to a PascalCase Dart identifier.
  static String pascalCase(String input) {
    final words = input
        .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1 $2')
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((e) => e.isNotEmpty);
    return words.map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).join();
  }

  /// Converts [input] to a lowercase snake_case identifier.
  static String snakeCase(String input) => input
      .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1_$2')
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .toLowerCase()
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
