
import 'dart:io';

import '../config/project_config.dart';
import '../utils/console.dart';
import '../utils/project.dart';

class RoutingGenerator {
  RoutingGenerator({required this.root, required this.config});

  final Directory root;
  final ProjectConfig config;

  Future<void> generateCoreFiles() async {
    if (!config.usesBuiltInRouting) {
      Console.info('Routing files skipped (${config.routing}); routing is managed by the project.');
      return;
    }

    final routesFile = File('${root.path}/lib/core/routes/app_routes.dart');
    await routesFile.parent.create(recursive: true);
    final routeMap = <String, String>{
      'splash': '/',
      'home': '/home',
      'profile': '/profile',
      'login': '/login',
    };
    final out = StringBuffer();
    if (config.hasRoutePaths) {
      out.writeln('class _Routes {');
      out.writeln('  _Routes._();');
      for (final entry in routeMap.entries) {
        out.writeln("  static const String ${entry.key} = '${entry.value}';");
      }
      out.writeln('}');
      out.writeln();
      out.writeln('class AppRoutes {');
      out.writeln('  AppRoutes._();');
      for (final entry in routeMap.entries) {
        out.writeln('  static const String ${entry.key} = _Routes.${entry.key};');
      }
      out.writeln('}');
      out.writeln();
    }
    if (config.hasRouteNames) {
      out.writeln('class AppRouteNames {');
      out.writeln('  AppRouteNames._();');
      for (final entry in routeMap.entries) {
        out.writeln("  static const String ${entry.key} = '${entry.key}';");
      }
      out.writeln('}');
    }
    if (!await routesFile.exists()) {
      await routesFile.writeAsString(out.toString());
      Console.success('Generated lib/core/routes/app_routes.dart');
    } else {
      Console.info('Preserved existing lib/core/routes/app_routes.dart.');
    }

    if (config.usesGoRouter) {
      final router = File('${root.path}/lib/core/routes/app_router.dart');
      if (!await router.exists()) {
        await router.writeAsString(_goRouterTemplate);
        Console.success('Generated lib/core/routes/app_router.dart');
      } else {
        await _ensureMarkers(router, goRouter: true);
      }
    } else {
      final navigator = File('${root.path}/lib/core/routes/app_navigator.dart');
      if (!await navigator.exists()) {
        await navigator.writeAsString(_navigatorTemplate);
        Console.success('Generated lib/core/routes/app_navigator.dart');
      } else {
        await _ensureMarkers(navigator, goRouter: false);
      }
    }
  }

  static const String _goRouterTemplate = '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// <bloc_cli:feature-imports>
// </bloc_cli:feature-imports>

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const _RoutePlaceholder(title: 'Splash'),
    ),
    // <bloc_cli:feature-routes>
    // </bloc_cli:feature-routes>
  ],
);

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(title)),
  );
}
''';

  static const String _navigatorTemplate = '''
import 'package:flutter/material.dart';

// <bloc_cli:feature-imports>
// </bloc_cli:feature-imports>

final Map<String, WidgetBuilder> appRoutes = {
  // <bloc_cli:feature-routes>
  // </bloc_cli:feature-routes>
};
''';

  Future<void> _ensureMarkers(File file, {required bool goRouter}) async {
    var source = await file.readAsString();
    if (!source.contains('// <bloc_cli:feature-imports>')) {
      source = source.replaceFirst(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\n// <bloc_cli:feature-imports>\n// </bloc_cli:feature-imports>",
      );
    }
    if (!source.contains('// <bloc_cli:feature-routes>')) {
      source = source.replaceFirst(
        goRouter ? 'routes: [' : 'final Map<String, WidgetBuilder> appRoutes = {',
        goRouter
            ? 'routes: [\n    // <bloc_cli:feature-routes>\n    // </bloc_cli:feature-routes>'
            : 'final Map<String, WidgetBuilder> appRoutes = {\n  // <bloc_cli:feature-routes>\n  // </bloc_cli:feature-routes>',
      );
    }
    await file.writeAsString(source);
  }

  Future<void> registerFeature(String rawName) async {
    if (!config.usesBuiltInRouting) return;
    final feature = Project.snakeCase(rawName);
    if (feature.isEmpty) return;
    final className = Project.pascalCase(feature);
    final appRoutesFile = File('${root.path}/lib/core/routes/app_routes.dart');
    if (await appRoutesFile.exists()) {
      var routeSource = await appRoutesFile.readAsString();
      if (config.hasRoutePaths && !routeSource.contains('static const String $feature =')) {
        routeSource = routeSource.replaceFirst(
          'class _Routes {',
          "class _Routes {\n  static const String $feature = '/$feature';",
        );
        routeSource = routeSource.replaceFirst(
          'class AppRoutes {',
          'class AppRoutes {\n  static const String $feature = _Routes.$feature;',
        );
      }
      if (config.hasRouteNames &&
          !routeSource.contains("static const String $feature = '$feature';")) {
        routeSource = routeSource.replaceFirst(
          'class AppRouteNames {',
          "class AppRouteNames {\n  static const String $feature = '$feature';",
        );
      }
      await appRoutesFile.writeAsString(routeSource);
    }
    final routesFile = File('${root.path}/lib/features/$feature/${feature}_routes.dart');
    await routesFile.parent.create(recursive: true);

    if (!await routesFile.exists()) {
      if (config.usesGoRouter) {
        await routesFile.writeAsString('''
import 'package:go_router/go_router.dart';
${config.hasRoutePaths || config.hasRouteNames ? "import '../../core/routes/app_routes.dart';" : ""}
import 'presentation/pages/${feature}_page.dart';

final List<RouteBase> ${feature}Routes = [
  GoRoute(
    path: ${config.hasRoutePaths ? 'AppRoutes.$feature' : "'/$feature'"},
    name: ${config.hasRouteNames ? 'AppRouteNames.$feature' : "'$feature'" },
    builder: (context, state) => const ${className}Page(),
  ),
];
''');
      } else {
        await routesFile.writeAsString('''
import 'package:flutter/material.dart';
${config.hasRoutePaths ? "import '../../core/routes/app_routes.dart';" : ""}
import 'presentation/pages/${feature}_page.dart';

final Map<String, WidgetBuilder> ${feature}Routes = {
  ${config.hasRoutePaths ? 'AppRoutes.$feature' : "'/$feature'"}: (context) => const ${className}Page(),
};
''');
      }
    }

    final router = File('${root.path}/lib/core/routes/${config.usesGoRouter ? 'app_router.dart' : 'app_navigator.dart'}');
    if (!await router.exists()) {
      await generateCoreFiles();
    }
    await _ensureMarkers(router, goRouter: config.usesGoRouter);
    var source = await router.readAsString();
    const importsMarker = '// <bloc_cli:feature-imports>';
    const routesMarker = '// <bloc_cli:feature-routes>';
    final importLine = "import '../../features/$feature/${feature}_routes.dart';";
    final routeLine = config.usesGoRouter ? '    ...${feature}Routes,' : '  ...${feature}Routes,';
    if (!source.contains(importLine)) {
      source = source.replaceFirst(importsMarker, '$importsMarker\n$importLine');
    }
    if (!source.contains(routeLine)) {
      source = source.replaceFirst(routesMarker, '$routesMarker\n$routeLine');
    }
    await router.writeAsString(source);
    Console.success('Registered $feature routes.');
  }
}
