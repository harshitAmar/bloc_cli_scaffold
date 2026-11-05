import 'dart:io';

import '../config/project_config.dart';
import '../utils/console.dart';
import '../utils/project.dart';

class FeatureGenerator {
  FeatureGenerator({required this.root, required this.config});

  final Directory root;
  final ProjectConfig config;

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

  String _repository(String f, String c) => '''
import '../entities/${f}_entity.dart';

abstract interface class ${c}Repository {
  Future<${c}Entity> get${c}();
}
''';

  String _useCase(String f, String c) => '''
import '../entities/${f}_entity.dart';
import '../repositories/${f}_repository.dart';

class Get${c}UseCase {
  const Get${c}UseCase(this._repository);

  final ${c}Repository _repository;

  Future<${c}Entity> call() => _repository.get${c}();
}
''';

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
    final datasourceImport =
        (config.dataSource == 'remote' || config.dataSource == 'both')
            ? "import '../datasources/${f}_remote_datasource.dart';\n"
            : '';
    final ctor = (config.dataSource == 'remote' || config.dataSource == 'both')
        ? 'const ${c}RepositoryImpl(this._dataSource);\n\n  final ${c}RemoteDataSource _dataSource;'
        : 'const ${c}RepositoryImpl();';
    final body = (config.dataSource == 'remote' || config.dataSource == 'both')
        ? 'final model = await _dataSource.get${c}();\n    return model;'
        : "throw UnimplementedError('Connect your selected datasource here.');";
    return '''
import '../../domain/entities/${f}_entity.dart';
import '../../domain/repositories/${f}_repository.dart';
\$d
import '../models/${f}_model.dart';

class ${c}RepositoryImpl implements ${c}Repository {
  $ctor

  @override
  Future<${c}Entity> get${c}() async {
    $body
  }
}
'''
        .replaceAll('\$d', datasourceImport);
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

  String _bloc(String f, String c) => '''
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_${f}_usecase.dart';
import '${f}_event.dart';
import '${f}_state.dart';

class ${c}Bloc extends Bloc<${c}Event, ${c}State> {
  ${c}Bloc(this._get${c})
      : super(const ${c}Initial()) {
    on<${c}Requested>(_onRequested);
  }

  final Get${c}UseCase _get${c};

  Future<void> _onRequested(
    ${c}Requested event,
    Emitter<${c}State> emit,
  ) async {
    emit(const ${c}Loading());
    try {
      final result = await _get${c}();
      emit(${c}Loaded(result));
    } catch (error) {
      emit(${c}Failure(error.toString()));
    }
  }
}
''';

  String _page(String f, String c) => '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/${f}_bloc.dart';
import '../bloc/${f}_event.dart';
import '../bloc/${f}_state.dart';

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
    return ${c}Model.fromJson(response.data as Map<String, dynamic>);
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
