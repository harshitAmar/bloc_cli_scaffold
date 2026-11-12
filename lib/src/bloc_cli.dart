import 'dart:convert';
import 'dart:io';

import 'config/project_config.dart';
import 'generators/application_generator.dart';
import 'generators/feature_generator.dart';
import 'generators/networking_generator.dart';
import 'generators/routing_generator.dart';
import 'generators/screen_generator.dart';
import 'utils/console.dart';
import 'utils/project.dart';

/// Runs the `bloc_cli` command-line interface.
///
/// Supported commands include project initialization and feature or screen
/// generation. Commands operate on the current working directory.
class BlocCli {
  /// Parses [args] and executes the requested CLI command.
  static Future<void> run(List<String> args) async {
    if (args.isEmpty ||
        args.first == 'help' ||
        args.first == '--help' ||
        args.first == '-h') {
      _help();
      return;
    }

    switch (args.first) {
      case 'init':
        await _init();
        return;
      case 'create':
        await _create(args.skip(1).toList());
        return;
      case 'version':
      case '--version':
      case '-v':
        Console.info('bloc_cli 1.0.1');
        return;
      default:
        Console.error('Unknown command: ${args.first}');
        _help();
    }
  }

  static Future<void> _init() async {
    final root = Directory.current;
    if (!await Project.isFlutterProject(root)) {
      Console.error(
          'Run this command from the root of an existing Flutter project (pubspec.yaml required).');
      return;
    }

    Console.title('bloc_cli — Clean Architecture setup');
    Console.info(
        'Choose the integrations for this project. Your choices are saved in .bloc_cli.json.');

    final state = Console.choose(
        'BLoC event/state classes',
        [
          'Equatable',
          'Freezed',
          'Plain Dart',
          'Custom',
        ],
        defaults: 0);
    final networking = Console.choose(
        'Networking',
        [
          'Dio',
          'HTTP',
          'Custom (I will provide networking)',
          'None',
        ],
        defaults: 0);
    final routing = Console.choose(
        'Routing',
        [
          'GoRouter',
          'Flutter Default Navigator',
          'Custom (I will provide routing)',
          'None',
        ],
        defaults: 0);

    var navigationStyle = 'both';
    if (routing == 'GoRouter' || routing == 'Flutter Default Navigator') {
      final selectedStyle = Console.choose(
          'Navigation constants',
          [
            'Route paths',
            'Route names',
            'Both',
          ],
          defaults: 2);
      navigationStyle = switch (selectedStyle) {
        'Route paths' => 'route_paths',
        'Route names' => 'route_names',
        _ => 'both',
      };
    }

    final di = Console.choose(
        'Dependency injection',
        [
          'GetIt',
          'GetIt + Injectable',
          'Manual',
          'Custom',
        ],
        defaults: 0);
    final dataSource = Console.choose(
        'Data source generation',
        [
          'Remote',
          'Local',
          'Both',
          'Custom',
          'None',
        ],
        defaults: 0);
    final serialization = Console.choose(
        'Model serialization',
        [
          'json_serializable',
          'Freezed',
          'Manual',
          'Custom',
        ],
        defaults: 0);

    final errorHandling = Console.choose(
        'API error handling',
        [
          'BaseRepository (centralized errors)',
          'Exceptions (throw ApiException)',
          'Custom',
          'None',
        ],
        defaults: 0);

    final config = ProjectConfig(
      stateStyle: switch (state) {
        'Freezed' => 'freezed',
        'Plain Dart' => 'plain_dart',
        'Custom' => 'custom',
        _ => 'equatable',
      },
      networking: switch (networking) {
        'HTTP' => 'http',
        'Custom (I will provide networking)' => 'custom',
        'None' => 'none',
        _ => 'dio',
      },
      routing: switch (routing) {
        'Flutter Default Navigator' => 'flutter_default_navigator',
        'Custom (I will provide routing)' => 'custom',
        'None' => 'none',
        _ => 'go_router',
      },
      navigationStyle: navigationStyle,
      dependencyInjection: switch (di) {
        'GetIt + Injectable' => 'getit_injectable',
        'Manual' => 'manual',
        'Custom' => 'custom',
        _ => 'getit',
      },
      dataSource: dataSource.toLowerCase(),
      serialization: serialization.toLowerCase(),
      errorHandling: switch (errorHandling) {
        'Exceptions (throw ApiException)' => 'exceptions',
        'Custom' => 'custom',
        'None' => 'none',
        _ => 'base_repository',
      },
    );

    final configFile = File('${root.path}/.bloc_cli.json');
    await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config.toJson()));
    await _addGitIgnoreEntry(root, '.bloc_cli.json');

    await _ensureCoreStructure(root);
    await NetworkingGenerator(root: root, config: config).generate();
    await RoutingGenerator(root: root, config: config).generateCoreFiles();
    await ApplicationGenerator(root: root, config: config).generateMain();
    Console.success('Configuration saved to .bloc_cli.json');
    Console.success('Initialization complete.');
    Console.info('Next: bloc_cli create feature auth');
  }

  static Future<void> _create(List<String> args) async {
    if (args.length < 2) {
      Console.error(
          'Usage: bloc_cli create feature <name> | create screen <name> --feature <feature>');
      return;
    }

    final type = args[0];
    final name = args[1];
    final flags = args.skip(2).toList();
    final overwrite =
        flags.contains('--force') || flags.contains('--overwrite');
    final withBloc = flags.contains('--with-bloc');
    final withRepository = flags.contains('--with-repository');
    String? featureName;
    for (var i = 0; i < flags.length; i++) {
      if (flags[i] == '--feature' && i + 1 < flags.length) {
        featureName = flags[i + 1];
      }
    }

    final root = Directory.current;
    final configFile = File('${root.path}/.bloc_cli.json');
    if (!await Project.isFlutterProject(root)) {
      Console.error('Run this command from the root of a Flutter project.');
      return;
    }
    if (!await configFile.exists()) {
      Console.error('Project is not initialized. Run: bloc_cli init');
      return;
    }

    final config = ProjectConfig.fromJson(
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>,
    );

    await NetworkingGenerator(root: root, config: config).generate();
    await RoutingGenerator(root: root, config: config).generateCoreFiles();

    switch (type) {
      case 'feature':
        await FeatureGenerator(root: root, config: config).generate(
          name,
          overwrite: overwrite,
        );
        await RoutingGenerator(root: root, config: config)
            .registerFeature(name);
        await NetworkingGenerator(root: root, config: config)
            .registerFeature(name);
        return;
      case 'screen':
        if (featureName == null || featureName.trim().isEmpty) {
          Console.error(
              'Missing --feature. Example: bloc_cli create screen profile --feature auth');
          return;
        }
        await ScreenGenerator(root: root, config: config).generate(
          name,
          rawFeatureName: featureName,
          withBloc: withBloc,
          withRepository: withRepository,
          force: overwrite,
        );
        return;
      default:
        Console.error('Unsupported generator: $type');
        Console.info('Supported generators: feature, screen');
    }
  }

  static Future<void> _ensureCoreStructure(Directory root) async {
    for (final path in [
      'lib/core/di',
      'lib/core/routes',
      'lib/core/network',
      'lib/core/error',
      'lib/features',
    ]) {
      await Directory('${root.path}/$path').create(recursive: true);
    }
  }

  static Future<void> _addGitIgnoreEntry(Directory root, String entry) async {
    final file = File('${root.path}/.gitignore');
    if (!await file.exists()) {
      return;
    }
    final content = await file.readAsString();
    if (!content.split('\n').contains(entry)) {
      await file.writeAsString('${content.trimRight()}\n$entry\n');
    }
  }

  static void _help() {
    Console.title('bloc_cli');
    stdout
        .writeln('A configurable Flutter BLoC Clean Architecture generator.\n');
    stdout.writeln('Commands:');
    stdout.writeln(
        '  bloc_cli init                         Configure a Flutter project');
    stdout.writeln(
        '  bloc_cli create feature <name> [--force]  Generate a Clean Architecture feature');
    stdout.writeln(
        '  bloc_cli create screen <name> --feature <feature> [--with-bloc] [--with-repository] [--force]');
    stdout.writeln(
        '                                         Generate a screen inside an existing feature');
    stdout.writeln('  bloc_cli help                         Show this help');
    stdout.writeln('  bloc_cli version                      Show version');
  }
}
