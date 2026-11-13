import 'dart:io';

import '../config/project_config.dart';
import '../utils/console.dart';
import '../utils/project.dart';

/// Generates Clean Architecture layers for a feature.
class FeatureGenerator {
  /// Creates a generator for [root] using [config].
  FeatureGenerator({required this.root, required this.config});

  /// Root directory of the Flutter project being generated.
  final Directory root;

  /// Architecture and integration choices for the target project.
  final ProjectConfig config;

  /// Whether Dio BaseRepository generation returns typed API results.
  bool get _usesApiResult =>
      config.errorHandling == 'base_repository' &&
      config.networking == 'dio' &&
      (config.dataSource == 'remote' || config.dataSource == 'both');

  /// Creates the feature named [rawName]. Existing files are preserved unless
  /// [overwrite] is true.
  Future<void> generate(String rawName, {bool overwrite = false}) async {
    final feature = Project.snakeCase(rawName);
    if (feature.isEmpty) {
      Console.error('Feature name cannot be empty.');
      return;
    }

    final base = '${root.path}/lib/features/$feature';
    final featureDir = Directory(base);
    await featureDir.create(recursive: true);

    final className = Project.pascalCase(feature);
    final files = <String, String>{
      'domain/entities/${feature}_entity.dart': _entity(feature, className),
      'domain/repositories/${feature}_repository.dart':
          _repository(feature, className),
      'domain/usecases/get_${feature}_usecase.dart':
          _useCase(feature, className),
      'data/models/${feature}_model.dart': _model(feature, className),
      'data/repositories/${feature}_repository_impl.dart':
          _repositoryImpl(feature, className),
      'presentation/bloc/${feature}_event.dart': _event(feature, className),
      'presentation/bloc/${feature}_state.dart': _state(feature, className),
      'presentation/bloc/${feature}_bloc.dart': _bloc(feature, className),
      'presentation/pages/${feature}_page.dart': _page(feature, className),
      'presentation/widgets/.gitkeep': '',
    };

    if (config.dataSource == 'remote' || config.dataSource == 'both') {
      files['data/datasources/${feature}_remote_datasource.dart'] =
          _remoteDataSource(feature, className);
    }
    if (config.dataSource == 'local' || config.dataSource == 'both') {
      files['data/datasources/${feature}_local_datasource.dart'] =
          _localDataSource(feature, className);
    }

    var created = 0;
    var skipped = 0;
    for (final entry in files.entries) {
      final file = File('$base/${entry.key}');
      await file.parent.create(recursive: true);
      if (await file.exists() && !overwrite) {
        skipped++;
        continue;
      }
      await file.writeAsString(entry.value);
      created++;
    }

    Console.success('Feature "$feature" generated at lib/features/$feature');
    Console.info(
        'Created $created file(s); preserved $skipped existing file(s).');
    Console.info(overwrite
        ? 'Existing feature files were regenerated (--force). Review local custom changes.'
        : 'Existing files were preserved. Use --force to regenerate CLI-owned feature files.');
  }

  String _entity(String f, String c) => '''
class ${c}Entity {
  const ${c}Entity({required this.id});

  final String id;
}
''';

  String _repository(String f, String c) {
    if (_usesApiResult) {
      return '''
import '../../../../core/network/api_result.dart';
import '../entities/${f}_entity.dart';

/// Domain contract for ${f} feature data operations.
abstract interface class ${c}Repository {
  Future<ApiResult<${c}Entity>> get${c}();
}
''';
    }
    return '''
import '../entities/${f}_entity.dart';

/// Domain contract for ${f} feature data operations.
abstract interface class ${c}Repository {
  Future<${c}Entity> get${c}();
}
''';
  }

  String _useCase(String f, String c) {
    if (_usesApiResult) {
      return '''
import '../../../../core/network/api_result.dart';
import '../entities/${f}_entity.dart';
import '../repositories/${f}_repository.dart';

/// Retrieves the primary ${f} feature entity and preserves its typed outcome.
class Get${c}UseCase {
  const Get${c}UseCase(this._repository);
  final ${c}Repository _repository;

  Future<ApiResult<${c}Entity>> call() => _repository.get${c}();
}
''';
    }
    return '''
import '../entities/${f}_entity.dart';
import '../repositories/${f}_repository.dart';

/// Retrieves the primary ${f} feature entity.
class Get${c}UseCase {
  const Get${c}UseCase(this._repository);
  final ${c}Repository _repository;

  Future<${c}Entity> call() => _repository.get${c}();
}
''';
  }

  String _model(String f, String c) => '''
import '../../domain/entities/${f}_entity.dart';

class ${c}Model extends ${c}Entity {
  const ${c}Model({required super.id});

  factory ${c}Model.fromJson(Map<String, dynamic> json) {
    return ${c}Model(id: json['id'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id};

  factory ${c}Model.fromEntity(${c}Entity entity) {
    return ${c}Model(id: entity.id);
  }
}
''';

  String _repositoryImpl(String f, String c) {
    final hasRemote =
        config.dataSource == 'remote' || config.dataSource == 'both';
    if (hasRemote && config.networking == 'dio' && _usesApiResult) {
      return '''
import '../../../../core/network/api_result.dart';
import '../../domain/entities/${f}_entity.dart';
import '../../domain/repositories/${f}_repository.dart';
import '../datasources/${f}_remote_datasource.dart';

/// Maps data models to domain entities without discarding API failures.
class ${c}RepositoryImpl implements ${c}Repository {
  const ${c}RepositoryImpl(this._dataSource);
  final ${c}RemoteDataSource _dataSource;

  @override
  Future<ApiResult<${c}Entity>> get${c}() async {
    final result = await _dataSource.get${c}();
    return result.when(
      success: (model) => ApiResult<${c}Entity>.success(model),
      failure: (message, statusCode) => ApiResult<${c}Entity>.failure(
        message,
        statusCode: statusCode,
      ),
    );
  }
}
''';
    }
    final datasourceImport = hasRemote
        ? "import '../datasources/${f}_remote_datasource.dart';\n"
        : '';
    final ctor = hasRemote
        ? 'const ${c}RepositoryImpl(this._dataSource);\n\n  final ${c}RemoteDataSource _dataSource;'
        : 'const ${c}RepositoryImpl();';
    final resultMode = _usesApiResult;
    final returnType = resultMode ? 'ApiResult<${c}Entity>' : '${c}Entity';
    final resultImport = resultMode
        ? "import '../../../../core/network/api_result.dart';\n"
        : '';
    final body = hasRemote
        ? 'return _dataSource.get${c}();'
        : "throw UnimplementedError('Connect your selected datasource here.');";
    return '''
$resultImport
import '../../domain/entities/${f}_entity.dart';
import '../../domain/repositories/${f}_repository.dart';
$datasourceImport
class ${c}RepositoryImpl implements ${c}Repository {
  $ctor

  @override
  Future<$returnType> get${c}() async {
    $body
  }
}
''';
  }

  String _event(String f, String c) {
    if (config.stateStyle == 'freezed') {
      return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${f}_event.freezed.dart';

@freezed
sealed class ${c}Event with _\$${c}Event {
  const factory ${c}Event.requested() = ${c}Requested;
}
''';
    }
    if (config.stateStyle == 'equatable') {
      return '''
import 'package:equatable/equatable.dart';

sealed class ${c}Event extends Equatable {
  const ${c}Event();

  @override
  List<Object?> get props => [];
}

final class ${c}Requested extends ${c}Event {
  const ${c}Requested();
}
''';
    }
    return '''
sealed class ${c}Event {
  const ${c}Event();
}

final class ${c}Requested extends ${c}Event {
  const ${c}Requested();
}
''';
  }

  String _state(String f, String c) {
    if (config.stateStyle == 'freezed') {
      return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${f}_state.freezed.dart';

@freezed
sealed class ${c}State with _\$${c}State {
  const factory ${c}State.initial() = ${c}Initial;
  const factory ${c}State.loading() = ${c}Loading;
  const factory ${c}State.loaded(${c}Entity data) = ${c}Loaded;
  const factory ${c}State.failure(String message) = ${c}Failure;
}
'''
          .replaceFirst(
              "import 'package:freezed_annotation/freezed_annotation.dart';",
              "import 'package:freezed_annotation/freezed_annotation.dart';\nimport '../../domain/entities/${f}_entity.dart';");
    }
    if (config.stateStyle == 'equatable') {
      return '''
import 'package:equatable/equatable.dart';
import '../../domain/entities/${f}_entity.dart';

sealed class ${c}State extends Equatable {
  const ${c}State();

  @override
  List<Object?> get props => [];
}

final class ${c}Initial extends ${c}State {
  const ${c}Initial();
}

final class ${c}Loading extends ${c}State {
  const ${c}Loading();
}

final class ${c}Loaded extends ${c}State {
  const ${c}Loaded(this.data);
  final ${c}Entity data;

  @override
  List<Object?> get props => [data];
}

final class ${c}Failure extends ${c}State {
  const ${c}Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
''';
    }
    return '''
import '../../domain/entities/${f}_entity.dart';

sealed class ${c}State {
  const ${c}State();
}

final class ${c}Initial extends ${c}State { const ${c}Initial(); }
final class ${c}Loading extends ${c}State { const ${c}Loading(); }
final class ${c}Loaded extends ${c}State {
  const ${c}Loaded(this.data);
  final ${c}Entity data;
}
final class ${c}Failure extends ${c}State {
  const ${c}Failure(this.message);
  final String message;
}
''';
  }

  String _bloc(String f, String c) {
    final resultBranch = _usesApiResult
        ? '''
    final result = await _get${c}();
    result.when(
      success: (data) => emit(${c}Loaded(data)),
      failure: (message, statusCode) => emit(${c}Failure(message)),
    );'''
        : '''
    try {
      final result = await _get${c}();
      emit(${c}Loaded(result));
    } catch (error) {
      emit(${c}Failure(error.toString()));
    }''';
    return '''
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_${f}_usecase.dart';
import '${f}_event.dart';
import '${f}_state.dart';

/// Coordinates ${f} feature events and presentation state.
class ${c}Bloc extends Bloc<${c}Event, ${c}State> {
  ${c}Bloc(this._get${c}) : super(const ${c}Initial()) {
    on<${c}Requested>(_onRequested);
  }

  final Get${c}UseCase _get${c};

  Future<void> _onRequested(
    ${c}Requested event,
    Emitter<${c}State> emit,
  ) async {
    emit(const ${c}Loading());
$resultBranch
  }
}
''';
  }

  String _page(String f, String c) => '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/${f}_bloc.dart';
import '../bloc/${f}_event.dart';
import '../bloc/${f}_state.dart';

/// Default page generated for the ${f} feature.
class ${c}Page extends StatelessWidget {
  const ${c}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$c')),
      body: BlocBuilder<${c}Bloc, ${c}State>(
        builder: (context, state) {
          if (state is ${c}Loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ${c}Failure) {
            return Center(child: Text(state.message));
          }
          if (state is ${c}Loaded) {
            return Center(child: Text('Loaded ID: \${state.data.id}'));
          }
          return Center(
            child: ElevatedButton(
              onPressed: () => context.read<${c}Bloc>().add(const ${c}Requested()),
              child: const Text('Load $c'),
            ),
          );
        },
      ),
    );
  }
}
''';

  String _remoteDataSource(String f, String c) {
    if (config.networking == 'dio') {
      if (config.errorHandling == 'base_repository') {
        return '''
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../models/${f}_model.dart';

abstract interface class ${c}RemoteDataSource {
  Future<ApiResult<${c}Model>> get${c}();
}

/// Uses the shared BaseRepository request/error pipeline.
class ${c}RemoteDataSourceImpl extends BaseRepository
    implements ${c}RemoteDataSource {
  const ${c}RemoteDataSourceImpl(super.dio);

  @override
  Future<ApiResult<${c}Model>> get${c}() {
    return safeApiCall<${c}Model>(
      () => handleApiCall<${c}Model>(
        request: () => dio.get('/${f}'),
        fromJson: (json) =>
            ${c}Model.fromJson(json as Map<String, dynamic>),
      ),
    );
  }
}
''';
      }
      return '''
import 'package:dio/dio.dart';
import '../models/${f}_model.dart';

abstract interface class ${c}RemoteDataSource {
  Future<${c}Model> get${c}();
}

class ${c}RemoteDataSourceImpl implements ${c}RemoteDataSource {
  const ${c}RemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<${c}Model> get${c}() async {
    final response = await _dio.get('/${f}');
    final raw = response.data is Map && (response.data as Map).containsKey('data')
        ? (response.data as Map)['data']
        : response.data;
    return ${c}Model.fromJson(raw as Map<String, dynamic>);
  }
}
''';
    }
    if (config.networking == 'http') {
      return '''
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/${f}_model.dart';

abstract interface class ${c}RemoteDataSource {
  Future<${c}Model> get${c}();
}

class ${c}RemoteDataSourceImpl implements ${c}RemoteDataSource {
  const ${c}RemoteDataSourceImpl(this._client, this._baseUri);

  final http.Client _client;
  final Uri _baseUri;

  @override
  Future<${c}Model> get${c}() async {
    final response = await _client.get(_baseUri.resolve('/${f}'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: \${response.statusCode}');
    }
    return ${c}Model.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
''';
    }
    return '''
import '../models/${f}_model.dart';

abstract interface class ${c}RemoteDataSource {
  Future<${c}Model> get${c}();
}

// TODO: Implement this datasource using your networking solution.
''';
  }

  String _localDataSource(String f, String c) => '''
import '../models/${f}_model.dart';

abstract interface class ${c}LocalDataSource {
  Future<${c}Model?> get${c}();
  Future<void> cache${c}(${c}Model model);
}

// TODO: Implement using your preferred local storage package.
''';
}
