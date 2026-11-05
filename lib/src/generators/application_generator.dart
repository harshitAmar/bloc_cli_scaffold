import 'dart:io';

import '../config/project_config.dart';
import '../utils/console.dart';

/// Creates or safely integrates the application entry point.
class ApplicationGenerator {
  /// Creates a generator for [root] using [config].
  ApplicationGenerator({required this.root, required this.config});

  /// Root directory of the Flutter project being generated.
  final Directory root;
  /// Architecture and integration choices for the target project.
  final ProjectConfig config;

  /// Generates `lib/main.dart` or adds the initialization snippet to it.
  Future<void> generateMain() async {
    final file = File('${root.path}/lib/main.dart');
    if (await file.exists()) {
      await _integrateExistingMain(file);
      return;
    }

    final imports = <String>["import 'package:flutter/material.dart';"];
    if (config.dependencyInjection == 'getit' ||
        config.dependencyInjection == 'getit_injectable') {
      imports.add("import 'core/di/injection.dart';");
    }
    if (config.usesGoRouter) {
      imports.add("import 'core/routes/app_router.dart';");
    }
    if (config.usesNavigator) {
      imports.add("import 'core/routes/app_navigator.dart';");
    }

    final initialization = <String>[];
    if (config.dependencyInjection == 'getit' ||
        config.dependencyInjection == 'getit_injectable') {
      if (config.networking == 'dio') {
        initialization.add(
          "  await configureDependencies(baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://example.com'));",
        );
      } else {
        initialization.add('  await configureDependencies();');
      }
    }

    final app = config.usesGoRouter
        ? '''MaterialApp.router(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    )'''
        : config.usesNavigator
            ? '''MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: appRoutes,
    )'''
            : '''MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(child: Text('Configure your application home screen')),
      ),
    )''';

    await file.writeAsString('''${imports.join('\n')}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // <bloc_cli:main-initialization>
${initialization.isEmpty ? '  // Add your custom initialization here.' : initialization.join('\n')}
  // </bloc_cli:main-initialization>

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return $app;
  }
}
''');
    Console.success('Generated lib/main.dart with application initialization.');
    if (config.networking == 'dio' &&
        (config.dependencyInjection == 'getit' ||
            config.dependencyInjection == 'getit_injectable')) {
      Console.info('Set API_BASE_URL using --dart-define=API_BASE_URL=https://your-api.com.');
    }
  }

  Future<void> _integrateExistingMain(File file) async {
    var source = await file.readAsString();
    if (source.contains('// <bloc_cli:main-initialization>')) {
      Console.info('main.dart already contains bloc_cli initialization.');
      return;
    }

    final mainPattern = RegExp(
      r'(void|Future<void>)\s+main\s*\(\s*\)\s*(async\s*)?\{',
    );
    final match = mainPattern.firstMatch(source);
    if (match == null) {
      Console.info(
        'Preserved existing main.dart. Could not safely identify a simple main() function; add the initialization snippet manually.',
      );
      return;
    }

    final imports = <String>[];
    if (config.dependencyInjection == 'getit' ||
        config.dependencyInjection == 'getit_injectable') {
      imports.add("import 'core/di/injection.dart';");
    }

    for (final import in imports) {
      if (!source.contains(import)) {
        final importMatches = RegExp(r"import '[^']+';").allMatches(source).toList();
        if (importMatches.isNotEmpty) {
          final last = importMatches.last;
          source = source.replaceRange(last.end, last.end, '\n$import');
        } else {
          source = '$import\n$source';
        }
      }
    }

    // Imports change offsets, so locate main() again.
    final updatedMatch = mainPattern.firstMatch(source);
    if (updatedMatch == null) {
      return;
    }
    final isAsync = updatedMatch.group(2) != null;
    final signature = isAsync ? updatedMatch.group(0)! : 'Future<void> main() async {';
    source = source.replaceRange(updatedMatch.start, updatedMatch.end, signature);

    final initialization = <String>[
      '  WidgetsFlutterBinding.ensureInitialized();',
      if (config.dependencyInjection == 'getit' ||
          config.dependencyInjection == 'getit_injectable')
        if (config.networking == 'dio')
          "  await configureDependencies(baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://example.com'));"
        else
          '  await configureDependencies();',
    ].join('\n');

    final openBrace = source.indexOf('{', updatedMatch.start);
    source = source.replaceRange(
      openBrace + 1,
      openBrace + 1,
      '\n  // <bloc_cli:main-initialization>\n$initialization\n  // </bloc_cli:main-initialization>\n',
    );

    if (config.usesGoRouter) {
      if (source.contains('MaterialApp.router(') &&
          !source.contains('routerConfig:')) {
        source = source.replaceFirst(
          'MaterialApp.router(',
          "MaterialApp.router(\n      routerConfig: appRouter,",
        );
        if (!source.contains("import 'core/routes/app_router.dart';")) {
          source = "import 'core/routes/app_router.dart';\n$source";
        }
      } else if (!source.contains('MaterialApp.router(')) {
        Console.info(
          'Dependency initialization was added. Connect appRouter to your existing root widget using MaterialApp.router.',
        );
      }
    } else if (config.usesNavigator) {
      if (source.contains('MaterialApp(') && !source.contains('routes: appRoutes')) {
        source = source.replaceFirst(
          'MaterialApp(',
          "MaterialApp(\n      routes: appRoutes,",
        );
        if (!source.contains("import 'core/routes/app_navigator.dart';")) {
          source = "import 'core/routes/app_navigator.dart';\n$source";
        }
      }
    }

    await file.writeAsString(source);
    Console.success('Integrated bloc_cli initialization into existing lib/main.dart.');
  }

}
