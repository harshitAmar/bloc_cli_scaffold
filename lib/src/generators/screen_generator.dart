import 'dart:io';

import '../config/project_config.dart';
import '../utils/console.dart';
import '../utils/project.dart';

/// Generates a page and optional screen-scoped BLoC and data/domain layers.
class ScreenGenerator {
  /// Creates a generator for [root] using [config].
  ScreenGenerator({required this.root, required this.config});

  /// Root directory of the Flutter project being generated.
  final Directory root;

  /// Architecture and integration choices for the target project.
  final ProjectConfig config;

  /// Adds [rawScreenName] to the existing [rawFeatureName] feature.
  ///
  /// When [withBloc] is enabled, the route creates a fresh BLoC instance.
  /// When [withRepository] is enabled, the related domain and data templates
  /// are generated as reusable feature dependencies.
  Future<void> generate(
    String rawScreenName, {
    required String rawFeatureName,
    bool withBloc = false,
    bool withRepository = false,
    bool force = false,
  }) async {
    final feature = Project.snakeCase(rawFeatureName);
    final screen = Project.snakeCase(rawScreenName);
    if (feature.isEmpty || screen.isEmpty) {
      Console.error(
          'Feature and screen names must contain letters or numbers.');
      return;
    }

    final featureRoot = Directory('${root.path}/lib/features/$feature');
    if (!await featureRoot.exists()) {
      Console.error(
          'Feature "$feature" does not exist. Create it first with: bloc_cli create feature $feature');
      return;
    }

    withBloc = withBloc || withRepository;
    final screenClass = Project.pascalCase(screen);
    final files = <String, String>{
      'presentation/pages/${screen}_page.dart':
          _page(screen, screenClass, withBloc),
    };

    if (withBloc) {
      files['presentation/bloc/${screen}/${screen}_event.dart'] =
          _event(screenClass);
      files['presentation/bloc/${screen}/${screen}_state.dart'] =
          _state(screenClass);
      files['presentation/bloc/${screen}/${screen}_bloc.dart'] =
          _bloc(screen, screenClass, withRepository);
    }

    if (withRepository) {
      files.addAll(_repositoryFiles(screen, screenClass));
    }

    var created = 0;
    var preserved = 0;
    for (final entry in files.entries) {
      final file = File('${featureRoot.path}/${entry.key}');
      await file.parent.create(recursive: true);
      if (await file.exists() && !force) {
        preserved++;
        continue;
      }
      await file.writeAsString(entry.value);
      created++;
    }

    await _registerRoute(feature, screen, screenClass, withBloc);
    if (withBloc && _usesGetIt) {
      await _registerDependencies(feature, screen, screenClass, withRepository);
    }

    Console.success('Screen "$screen" generated in lib/features/$feature.');
    Console.info(
        'Created $created file(s); preserved $preserved existing file(s).');
    if (withRepository) {
      Console.info(
          'Generated the screen repository chain. Connect the endpoint and response model to your API.');
    }
  }

  bool get _usesGetIt =>
      config.dependencyInjection == 'getit' ||
      config.dependencyInjection == 'getit_injectable';

  String _page(String screen, String c, bool withBloc) {
    final imports = withBloc
        ? "import 'package:flutter_bloc/flutter_bloc.dart';\nimport '../bloc/$screen/${screen}_bloc.dart';\nimport '../bloc/$screen/${screen}_event.dart';\nimport '../bloc/$screen/${screen}_state.dart';\n"
        : '';
    final body = withBloc
        ? '''body: BlocBuilder<${c}Bloc, ${c}State>(
        builder: (context, state) {
          if (state is ${c}Loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ${c}Failure) {
            return Center(child: Text(state.message));
          }
          return Center(
            child: ElevatedButton(
              onPressed: () => context.read<${c}Bloc>().add(const ${c}Started()),
              child: const Text('Load $c'),
            ),
          );
        },
      ),'''
        : "body: const Center(child: Text('$c screen')),";
    return '''import 'package:flutter/material.dart';
$imports
/// Presentation page generated for the $c screen.
class ${c}Page extends StatelessWidget {
  const ${c}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$c')),
      $body
    );
  }
}
''';
  }

  String _event(String c) => '''
sealed class ${c}Event {
  const ${c}Event();
}

final class ${c}Started extends ${c}Event {
  const ${c}Started();
}
''';

  String _state(String c) => '''
sealed class ${c}State {
  const ${c}State();
}

final class ${c}Initial extends ${c}State {
  const ${c}Initial();
}

final class ${c}Loading extends ${c}State {
  const ${c}Loading();
}

final class ${c}Loaded extends ${c}State {
  const ${c}Loaded();
}

final class ${c}Failure extends ${c}State {
  const ${c}Failure(this.message);
  final String message;
}
''';

  String _bloc(String screen, String c, bool withRepository) {
    final useCaseImport = withRepository && _usesGetIt
        ? "import '../../../domain/usecases/get_${screen}_usecase.dart';\n"
        : '';
    final constructor = withRepository && _usesGetIt
        ? '''${c}Bloc(this._useCase) : super(const ${c}Initial()) {
    on<${c}Started>(_onStarted);
  }

  final Get${c}UseCase _useCase;

  Future<void> _onStarted(${c}Started event, Emitter<${c}State> emit) async {
    emit(const ${c}Loading());
    try {
      await _useCase();
      emit(const ${c}Loaded());
    } catch (error) {
      emit(${c}Failure(error.toString()));
    }
  }'''
        : '''${c}Bloc() : super(const ${c}Initial()) {
    on<${c}Started>((event, emit) => emit(const ${c}Loaded()));
  }''';
    return '''import 'package:flutter_bloc/flutter_bloc.dart';
$useCaseImport
import '${screen}_event.dart';
import '${screen}_state.dart';

/// Handles presentation events and state for the $c screen.
class ${c}Bloc extends Bloc<${c}Event, ${c}State> {
  $constructor
}
''';
  }

  Map<String, String> _repositoryFiles(String screen, String c) {
    final remote = config.dataSource == 'remote' || config.dataSource == 'both';
    final entity = '''class ${c}Entity {
  const ${c}Entity({required this.id});
  final String id;
}
''';
    final repository = '''import '../entities/${screen}_entity.dart';

/// Domain contract for retrieving $c data.
abstract interface class ${c}Repository {
  Future<${c}Entity> get${c}();
}
''';
    final useCase = '''import '../entities/${screen}_entity.dart';
import '../repositories/${screen}_repository.dart';

/// Executes the $c retrieval use case.
class Get${c}UseCase {
  const Get${c}UseCase(this._repository);
  final ${c}Repository _repository;

  Future<${c}Entity> call() => _repository.get${c}();
}
''';
    final model = '''import '../../domain/entities/${screen}_entity.dart';

class ${c}Model extends ${c}Entity {
  const ${c}Model({required super.id});

  factory ${c}Model.fromJson(Map<String, dynamic> json) =>
      ${c}Model(id: json['id']?.toString() ?? '');

  Map<String, dynamic> toJson() => {'id': id};
}
''';
    final ds = config.networking == 'dio'
        ? config.errorHandling == 'base_repository'
            ? '''import 'package:dio/dio.dart';
import '../../../../core/network/base_repository.dart';
import '../models/${screen}_model.dart';

class ${c}RemoteDataSource extends BaseRepository {
  const ${c}RemoteDataSource(super.dio);

  Future<${c}Model> get${c}() {
    return handleApiCall<${c}Model>(
      request: () => dio.get('/${screen}'),
      fromJson: (json) =>
          ${c}Model.fromJson(json as Map<String, dynamic>),
    );
  }
}
'''
            : '''import 'package:dio/dio.dart';
import '../models/${screen}_model.dart';

class ${c}RemoteDataSource {
  const ${c}RemoteDataSource(this._dio);
  final Dio _dio;

  Future<${c}Model> get${c}() async {
    final response = await _dio.get('/${screen}');
    final raw = response.data is Map && (response.data as Map).containsKey('data')
        ? (response.data as Map)['data']
        : response.data;
    return ${c}Model.fromJson(raw as Map<String, dynamic>);
  }
}
'''
        : '''import '../models/${screen}_model.dart';

abstract interface class ${c}RemoteDataSource {
  Future<${c}Model> get${c}();
}

// TODO: Implement this datasource using the configured networking client.
''';
    final repoImpl = remote && config.networking == 'dio'
        ? '''import '../../domain/entities/${screen}_entity.dart';
import '../../domain/repositories/${screen}_repository.dart';
import '../datasources/${screen}_remote_datasource.dart';

class ${c}RepositoryImpl implements ${c}Repository {
  const ${c}RepositoryImpl(this._dataSource);
  final ${c}RemoteDataSource _dataSource;

  @override
  Future<${c}Entity> get${c}() => _dataSource.get${c}();
}
'''
        : '''import '../../domain/entities/${screen}_entity.dart';
import '../../domain/repositories/${screen}_repository.dart';

class ${c}RepositoryImpl implements ${c}Repository {
  const ${c}RepositoryImpl();

  @override
  Future<${c}Entity> get${c}() =>
      throw UnimplementedError('Connect the selected datasource/networking client.');
}
''';
    return {
      'domain/entities/${screen}_entity.dart': entity,
      'domain/repositories/${screen}_repository.dart': repository,
      'domain/usecases/get_${screen}_usecase.dart': useCase,
      'data/models/${screen}_model.dart': model,
      'data/repositories/${screen}_repository_impl.dart': repoImpl,
      if (remote) 'data/datasources/${screen}_remote_datasource.dart': ds,
      if (config.dataSource == 'local' || config.dataSource == 'both')
        'data/datasources/${screen}_local_datasource.dart':
            '''import '../models/${screen}_model.dart';

abstract interface class ${c}LocalDataSource {
  Future<${c}Model?> read();
  Future<void> write(${c}Model model);
}

// TODO: Implement with your selected local storage package.
''',
    };
  }

  Future<void> _registerRoute(
    String feature,
    String screen,
    String c,
    bool withBloc,
  ) async {
    final routes =
        File('${root.path}/lib/features/$feature/${feature}_routes.dart');
    if (!await routes.exists()) {
      Console.info(
          'Feature route file not found; skipped automatic screen route registration.');
      return;
    }
    var source = await routes.readAsString();
    final pageImport = "import 'presentation/pages/${screen}_page.dart';";
    if (!source.contains(pageImport)) {
      final importMatches =
          RegExp(r"import '[^']+';").allMatches(source).toList();
      if (importMatches.isNotEmpty) {
        final lastImport = importMatches.last;
        source = source.replaceRange(
            lastImport.end, lastImport.end, '\n$pageImport');
      } else {
        source = '$pageImport\n$source';
      }
    }
    final routeName = '${feature}_${screen}';
    final pathName =
        config.hasRoutePaths ? 'AppRoutes.$routeName' : "'/$feature/$screen'";
    final nameValue =
        config.hasRouteNames ? 'AppRouteNames.$routeName' : "'$routeName'";
    final blocFactory = _usesGetIt ? 'getIt<${c}Bloc>()' : '${c}Bloc()';
    final builder = withBloc
        ? '''builder: (context, state) => BlocProvider(
        create: (_) => $blocFactory,
        child: const ${c}Page(),
      ),'''
        : 'builder: (context, state) => const ${c}Page(),';

    if (withBloc) {
      if (!source
          .contains("import 'package:flutter_bloc/flutter_bloc.dart';")) {
        source = "import 'package:flutter_bloc/flutter_bloc.dart';\n$source";
      }
      if (_usesGetIt &&
          !source.contains("import '../../core/di/injection.dart';")) {
        source = "import '../../core/di/injection.dart';\n$source";
      }
      if (!source.contains(
          "import 'presentation/bloc/$screen/${screen}_bloc.dart';")) {
        source =
            "import 'presentation/bloc/$screen/${screen}_bloc.dart';\n$source";
      }
    }
    if (config.usesGoRouter) {
      final route = '''
  GoRoute(
    path: $pathName,
    name: $nameValue,
    $builder
  ),''';
      if (!source.contains('name: $nameValue')) {
        source = source.replaceFirst(RegExp(r'\];\s*$'), '$route\n];');
      }
    } else if (config.usesNavigator) {
      final navigatorBuilder = withBloc
          ? '(context) => BlocProvider(create: (_) => $blocFactory, child: const ${c}Page())'
          : '(context) => const ${c}Page()';
      final route = '  $pathName: $navigatorBuilder,';
      if (!source.contains('$pathName:')) {
        source = source.replaceFirst(RegExp(r'};\s*$'), '$route\n};');
      }
    }
    await routes.writeAsString(source);

    final constants = File('${root.path}/lib/core/routes/app_routes.dart');
    if (await constants.exists()) {
      var routeSource = await constants.readAsString();
      if (config.hasRoutePaths) {
        routeSource = _insertConstant(
            routeSource, '_Routes', routeName, "'/$feature/$screen'");
        routeSource = _insertConstant(
            routeSource, 'AppRoutes', routeName, '_Routes.$routeName');
      }
      if (config.hasRouteNames) {
        routeSource = _insertConstant(
            routeSource, 'AppRouteNames', routeName, "'$routeName'");
      }
      await constants.writeAsString(routeSource);
    }
  }

  String _insertConstant(
      String source, String className, String name, String value) {
    if (source.contains('static const String $name =')) return source;
    final pattern = RegExp('class $className \\{([\\s\\S]*?)\n\\}');
    final match = pattern.firstMatch(source);
    if (match == null) return source;
    final replacement =
        'class $className {${match.group(1)}\n  static const String $name = $value;\n}';
    return source.replaceRange(match.start, match.end, replacement);
  }

  Future<void> _registerDependencies(
    String feature,
    String screen,
    String c,
    bool withRepository,
  ) async {
    final di = File('${root.path}/lib/features/$feature/${feature}_di.dart');
    if (!await di.exists()) {
      Console.info(
          'Feature DI file not found; skipped automatic BLoC registration.');
      return;
    }

    var source = await di.readAsString();
    final imports = <String>[
      "import 'presentation/bloc/$screen/${screen}_bloc.dart';",
      if (withRepository) ...[
        if (config.networking == 'dio' &&
            (config.dataSource == 'remote' || config.dataSource == 'both'))
          "import 'package:dio/dio.dart';",
        if (config.dataSource == 'remote' || config.dataSource == 'both')
          "import 'data/datasources/${screen}_remote_datasource.dart';",
        "import 'data/repositories/${screen}_repository_impl.dart';",
        "import 'domain/repositories/${screen}_repository.dart';",
        "import 'domain/usecases/get_${screen}_usecase.dart';",
      ],
    ];

    final declarationIndex = source.indexOf(RegExp(r'void register'));
    for (final line in imports) {
      if (!source.contains(line)) {
        source = declarationIndex >= 0
            ? source.replaceRange(declarationIndex, declarationIndex, '$line\n')
            : '$line\n$source';
      }
    }

    final registrations = <String>[];
    final remoteEnabled =
        config.dataSource == 'remote' || config.dataSource == 'both';
    final dioRemote = remoteEnabled && config.networking == 'dio';

    if (withRepository) {
      if (dioRemote) {
        registrations.add(
          '  if (!getIt.isRegistered<${c}RemoteDataSource>()) getIt.registerLazySingleton<${c}RemoteDataSource>(() => ${c}RemoteDataSource(getIt<Dio>()));',
        );
        registrations.add(
          '  if (!getIt.isRegistered<${c}Repository>()) getIt.registerLazySingleton<${c}Repository>(() => ${c}RepositoryImpl(getIt<${c}RemoteDataSource>()));',
        );
      } else {
        registrations.add(
          '  if (!getIt.isRegistered<${c}Repository>()) getIt.registerLazySingleton<${c}Repository>(() => ${c}RepositoryImpl());',
        );
      }
      registrations.add(
        '  if (!getIt.isRegistered<Get${c}UseCase>()) getIt.registerLazySingleton<Get${c}UseCase>(() => Get${c}UseCase(getIt<${c}Repository>()));',
      );
    }

    final blocFactory = withRepository ? 'getIt<Get${c}UseCase>()' : '';
    registrations.add(
      withRepository && dioRemote
          ? '  if (!getIt.isRegistered<${c}Bloc>()) getIt.registerFactory<${c}Bloc>(() => ${c}Bloc($blocFactory));'
          : withRepository && _usesGetIt
              ? '  if (!getIt.isRegistered<${c}Bloc>()) getIt.registerFactory<${c}Bloc>(() => ${c}Bloc(getIt<Get${c}UseCase>()));'
              : '  if (!getIt.isRegistered<${c}Bloc>()) getIt.registerFactory<${c}Bloc>(() => ${c}Bloc());',
    );

    final functionPattern = RegExp(
      r'(void register[A-Za-z0-9]+Dependencies\(GetIt getIt\) \{)([\s\S]*?)\n\}',
    );
    final match = functionPattern.firstMatch(source);
    if (match == null) {
      Console.info(
          'Could not locate feature DI registration function; add screen registrations manually.');
      return;
    }

    var body = match.group(2)!;
    for (final line in registrations) {
      if (!body.contains(line.substring(line.indexOf('getIt.')))) {
        body = '$body\n$line';
      }
    }
    source = source.replaceRange(
      match.start,
      match.end,
      '${match.group(1)}$body\n}',
    );
    await di.writeAsString(source);
    Console.success(
        'Registered $c screen dependencies with factory-scoped BLoC lifecycle.');
  }
}
