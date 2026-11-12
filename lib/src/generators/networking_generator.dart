import 'dart:io';

import '../config/project_config.dart';
import '../utils/console.dart';

/// Generates networking infrastructure and selected package dependencies.
class NetworkingGenerator {
  /// Creates a generator for [root] using [config].
  NetworkingGenerator({required this.root, required this.config});

  /// Root directory of the Flutter project being generated.
  final Directory root;

  /// Architecture and integration choices for the target project.
  final ProjectConfig config;

  /// Generates the selected networking client and updates dependencies.
  Future<void> generate() async {
    final networkingEnabled =
        config.networking == 'dio' || config.networking == 'http';
    if (!networkingEnabled) {
      Console.info('Networking files skipped (${config.networking}).');
    }
    final files = <String, String>{
      if (config.networking == 'dio') ..._dioFiles(),
      if (config.networking == 'http') ..._httpFiles(),
    };
    if (config.dependencyInjection == 'getit' ||
        config.dependencyInjection == 'getit_injectable') {
      files['../di/injection.dart'] = _injectionFile();
    }
    var created = 0;
    var preserved = 0;

    for (final entry in files.entries) {
      final file = File('${root.path}/lib/core/network/${entry.key}');
      await file.parent.create(recursive: true);
      if (await file.exists()) {
        preserved++;
        continue;
      }
      await file.writeAsString(entry.value);
      created++;
    }

    final dependencies = <String, String>{
      if (config.networking == 'dio') 'dio': '^5.8.0',
      if (config.networking == 'http') 'http': '^1.3.0',
      if (config.dependencyInjection == 'getit' ||
          config.dependencyInjection == 'getit_injectable')
        'get_it': '^8.0.3',
      'flutter_bloc': '^9.1.1',
      if (config.stateStyle == 'equatable') 'equatable': '^2.0.7',
      if (config.routing == 'go_router') 'go_router': '^15.1.2',
      if (config.serialization == 'json_serializable')
        'json_annotation': '^4.9.0',
      if (config.serialization == 'freezed') 'freezed_annotation': '^3.0.6',
    };
    final devDependencies = <String, String>{
      if (config.serialization == 'json_serializable') ...{
        'json_serializable': '^6.9.5',
        'build_runner': '^2.4.15',
      },
      if (config.serialization == 'freezed') ...{
        'freezed': '^3.0.6',
        'json_serializable': '^6.9.5',
        'build_runner': '^2.4.15',
      },
    };
    final dependencyAdded = await _addDependencies(dependencies);
    final devDependencyAdded = await _addDevDependencies(devDependencies);

    if (networkingEnabled) {
      Console.success('Networking files generated for ${config.networking}.');
    }
    Console.info(
        'Created $created file(s); preserved $preserved existing file(s).');
    if (dependencyAdded || devDependencyAdded) {
      Console.success('Updated pubspec.yaml dependencies.');
      await _runPubGet();
    } else {
      Console.info(
          'Required dependencies are already present or pubspec.yaml could not be updated.');
    }
  }

  Map<String, String> _dioFiles() => {
        'api_client.dart': r'''
import 'package:dio/dio.dart';

import 'interceptors/auth_interceptor.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    AuthInterceptor? authInterceptor,
    List<Interceptor> interceptors = const [],
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        ) {
    if (authInterceptor != null) {
      dio.interceptors.add(authInterceptor);
    }
    dio.interceptors.addAll(interceptors);
  }

  final Dio dio;
}
''',
        'api_endpoints.dart': r'''
class ApiEndpoints {
  ApiEndpoints._();

  static const String register = 'auth/register';
  static const String verifyOtp = 'auth/verify-otp';
  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String profile = 'profile';

  // Add application-specific endpoints here.
}
''',
        'api_exception.dart': r'''
import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final messages = <String>[];
        for (final value in errors.values) {
          if (value is List) {
            messages.addAll(value.map((item) => item.toString()));
          } else {
            messages.add(value.toString());
          }
        }
        if (messages.isNotEmpty) {
          return ApiException(messages.join('\n'), statusCode: statusCode);
        }
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return ApiException(message, statusCode: statusCode);
      }
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout => 'Connection timeout. Please try again.',
      DioExceptionType.sendTimeout => 'Send timeout. Please try again.',
      DioExceptionType.receiveTimeout => 'Receive timeout. Please try again.',
      DioExceptionType.badCertificate => 'Invalid certificate.',
      DioExceptionType.connectionError => 'Connection error. Check your internet.',
      DioExceptionType.cancel => 'Request cancelled.',
      DioExceptionType.badResponse => 'Received invalid status code: $statusCode',
      DioExceptionType.unknown => error.message ?? 'Something went wrong. Please try again.',
    };
    return ApiException(message, statusCode: statusCode);
  }

  @override
  String toString() => message;
}
''',
        'api_response.dart': r'''
class ApiResponse<T> {
  const ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  final bool status;
  final String message;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    final rawData = json['data'];
    return ApiResponse<T>(
      status: json['success'] as bool? ?? json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: T == bool
          ? json['success'] as T?
          : rawData != null
              ? fromJsonT(rawData)
              : fromJsonT(json),
    );
  }
}
''',
        'api_result.dart': r'''
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.failure(String message, {int? statusCode}) = ApiFailure<T>;

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(:final data) => success(data),
      ApiFailure<T>(:final message, :final statusCode) => failure(message, statusCode),
    };
  }
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}
''',
        'base_repository.dart': r'''
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'api_result.dart';

/// Shared API execution and error handling for Dio-backed data sources.
///
/// Inject the same configured [Dio] instance used by [ApiClient]. This avoids
/// hidden service-locator lookups and keeps request configuration consistent.
abstract class BaseRepository {
  const BaseRepository(this.dio);

  final Dio dio;

  /// Executes a request and maps transport/server errors to [ApiException].
  ///
  /// [fromJson] receives the `data` field when the server uses a standard
  /// `{ success/status, message, data }` envelope. Otherwise it receives the
  /// complete response body. Lists, maps, primitives and empty responses can
  /// be handled by supplying an appropriate decoder.
  Future<T> handleApiCall<T>({
    required Future<Response<dynamic>> Function() request,
    required T Function(dynamic json) fromJson,
    bool useEnvelope = true,
  }) async {
    try {
      final response = await request();
      final raw = response.data;
      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw ApiException(
          _messageFromBody(raw) ??
              'Request failed with status code ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }

      final payload = useEnvelope ? _unwrapEnvelope(raw) : raw;
      return fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDioError(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Returns an [ApiResult] instead of throwing mapped API failures.
  Future<ApiResult<T>> safeApiCall<T>(
    Future<T> Function() request,
  ) async {
    try {
      return ApiResult<T>.success(await request());
    } on ApiException catch (error) {
      return ApiResult<T>.failure(
        error.message,
        statusCode: error.statusCode,
      );
    } on DioException catch (error) {
      final mapped = ApiException.fromDioError(error);
      return ApiResult<T>.failure(
        mapped.message,
        statusCode: mapped.statusCode,
      );
    } catch (error) {
      return ApiResult<T>.failure(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  dynamic _unwrapEnvelope(dynamic body) {
    if (body is Map) {
      final status = body['success'] ?? body['status'];
      if (status == false) {
        throw ApiException(
          _messageFromBody(body) ?? 'Request failed.',
        );
      }
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }

  String? _messageFromBody(dynamic body) {
    if (body is! Map) return null;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          messages.addAll(value.map((item) => item.toString()));
        } else {
          messages.add(value.toString());
        }
      }
      if (messages.isNotEmpty) return messages.join('\\n');
    }
    final message = body['message']?.toString();
    return message == null || message.isEmpty ? null : message;
  }
}
''',
        'interceptors/auth_interceptor.dart': r'''
import 'package:dio/dio.dart';

typedef TokenProvider = Future<String?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenProvider,
    this.onUnauthorized,
    this.excludedPaths = const [],
  });

  final TokenProvider tokenProvider;
  final Future<void> Function()? onUnauthorized;
  final List<String> excludedPaths;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final excluded = excludedPaths.any(options.path.contains);
    if (!excluded) {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    options.headers['Accept'] ??= 'application/json';
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && onUnauthorized != null) {
      await onUnauthorized!();
    }
    handler.next(err);
  }
}
''',
      };

  Map<String, String> _httpFiles() => {
        'api_client.dart': r'''
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'interceptors/auth_interceptor.dart';

class ApiClient {
  ApiClient({
    required this.baseUri,
    http.Client? client,
    AuthInterceptor? authInterceptor,
    Map<String, String> defaultHeaders = const {},
  })  : _client = client ?? http.Client(),
        _authInterceptor = authInterceptor,
        _defaultHeaders = defaultHeaders;

  final Uri baseUri;
  final http.Client _client;
  final AuthInterceptor? _authInterceptor;
  final Map<String, String> _defaultHeaders;

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final requestHeaders = await _headers(path, headers);
    return _client.get(baseUri.resolve(path), headers: requestHeaders);
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = await _headers(path, headers);
    return _client.post(
      baseUri.resolve(path),
      headers: requestHeaders,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<Map<String, String>> _headers(
    String path,
    Map<String, String>? headers,
  ) async {
    final result = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ..._defaultHeaders,
      ...?headers,
    };
    final token = await _authInterceptor?.getTokenFor(path);
    if (token != null && token.isNotEmpty) {
      result['Authorization'] = 'Bearer $token';
    }
    return result;
  }

  void close() => _client.close();
}
''',
        'api_endpoints.dart': r'''
class ApiEndpoints {
  ApiEndpoints._();

  static const String register = 'auth/register';
  static const String verifyOtp = 'auth/verify-otp';
  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String profile = 'profile';

  // Add application-specific endpoints here.
}
''',
        'api_exception.dart': r'''
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromResponse(int statusCode, String body) {
    return ApiException(
      body.isEmpty ? 'Request failed with status code $statusCode.' : body,
      statusCode: statusCode,
    );
  }

  @override
  String toString() => message;
}
''',
        'api_response.dart': r'''
class ApiResponse<T> {
  const ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  final bool status;
  final String message;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    final rawData = json['data'];
    return ApiResponse<T>(
      status: json['success'] as bool? ?? json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: rawData == null ? null : fromJsonT(rawData),
    );
  }
}
''',
        'api_result.dart': r'''
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.failure(String message, {int? statusCode}) = ApiFailure<T>;

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(:final data) => success(data),
      ApiFailure<T>(:final message, :final statusCode) => failure(message, statusCode),
    };
  }
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}
''',
        'base_repository.dart': r'''
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../di/injection.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'api_result.dart';

abstract class BaseRepository {
  http.Client client = getIt<http.Client>();

  Future<ApiResult<T>> safeApiCall<T>(Future<T> Function() request) async {
    try {
      return ApiResult<T>.success(await request());
    } on ApiException catch (error) {
      debugPrint('API Error: ${error.message}');
      debugPrint('Status Code: ${error.statusCode}');
      return ApiResult<T>.failure(error.message, statusCode: error.statusCode);
    } catch (error) {
      debugPrint('Unexpected Error: $error');
      return ApiResult<T>.failure(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<ApiResult<T>> handleApiCall<T>(
    Future<http.Response> Function() request,
    T Function(dynamic json) fromJson,
  ) {
    return safeApiCall<T>(() async {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response.statusCode, response.body);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Invalid server response.');
      }

      final apiResponse = ApiResponse<T>.fromJson(decoded, fromJson);
      if (!apiResponse.status) {
        var message = apiResponse.message;
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final messages = <String>[];
          for (final value in errors.values) {
            if (value is List) {
              messages.addAll(value.map((item) => item.toString()));
            } else {
              messages.add(value.toString());
            }
          }
          if (messages.isNotEmpty) {
            message = messages.join('\n');
          }
        }
        throw ApiException(message.isEmpty ? 'Request failed.' : message);
      }

      final data = apiResponse.data;
      if (data == null) {
        throw const ApiException('Unexpected null data.');
      }
      return data;
    });
  }
}
''',
        'interceptors/auth_interceptor.dart': r'''
typedef TokenProvider = Future<String?> Function();

class AuthInterceptor {
  const AuthInterceptor({
    required this.tokenProvider,
    this.excludedPaths = const [],
  });

  final TokenProvider tokenProvider;
  final List<String> excludedPaths;

  Future<String?> getTokenFor(String path) async {
    if (excludedPaths.any(path.contains)) return null;
    return tokenProvider();
  }
}
''',
      };

  String _injectionFile() {
    if (config.networking == 'dio') {
      return '''
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';

final getIt = GetIt.instance;

// <bloc_cli:feature-imports>
// </bloc_cli:feature-imports>

Future<void> configureDependencies({required String baseUrl}) async {
  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerLazySingleton<ApiClient>(
      () => ApiClient(baseUrl: baseUrl),
    );
  }
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerSingleton<Dio>(getIt<ApiClient>().dio);
  }
  // <bloc_cli:feature-registrations>
  // </bloc_cli:feature-registrations>
}
''';
    }
    if (config.networking == 'http') {
      return '''
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

final getIt = GetIt.instance;

// <bloc_cli:feature-imports>
// </bloc_cli:feature-imports>

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<http.Client>()) {
    getIt.registerLazySingleton<http.Client>(() => http.Client());
  }
  // <bloc_cli:feature-registrations>
  // </bloc_cli:feature-registrations>
}
''';
    }

    return '''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

// <bloc_cli:feature-imports>
// </bloc_cli:feature-imports>

Future<void> configureDependencies() async {
  // <bloc_cli:feature-registrations>
  // </bloc_cli:feature-registrations>
}
''';
  }

  /// Adds the generated feature dependency module to the DI initializer.
  Future<void> registerFeature(String rawName) async {
    if (config.dependencyInjection != 'getit' &&
        config.dependencyInjection != 'getit_injectable') {
      return;
    }
    final feature = rawName
        .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1_$2')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .toLowerCase()
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (feature.isEmpty) {
      return;
    }
    final className = feature
        .split('_')
        .map((part) =>
            part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
        .join();
    final featureDi =
        File('${root.path}/lib/features/$feature/${feature}_di.dart');
    final remoteEnabled =
        config.dataSource == 'remote' || config.dataSource == 'both';
    final remoteImport = remoteEnabled
        ? "import 'data/datasources/${feature}_remote_datasource.dart';"
        : '';
    final datasourceRegistration = remoteEnabled && config.networking == 'dio'
        ? "if (!getIt.isRegistered<${className}RemoteDataSource>()) getIt.registerLazySingleton<${className}RemoteDataSource>(() => ${className}RemoteDataSourceImpl(getIt<Dio>()));"
        : remoteEnabled && config.networking == 'http'
            ? "if (!getIt.isRegistered<${className}RemoteDataSource>()) getIt.registerLazySingleton<${className}RemoteDataSource>(() => ${className}RemoteDataSourceImpl(getIt<http.Client>(), Uri.parse('https://example.com')));"
            : '';
    if (!await featureDi.exists()) {
      await featureDi.writeAsString('''
import 'package:get_it/get_it.dart';
${config.networking == 'dio' && remoteEnabled ? "import 'package:dio/dio.dart';" : ""}
${config.networking == 'http' && remoteEnabled ? "import 'package:http/http.dart' as http;" : ""}
$remoteImport
import 'data/repositories/${feature}_repository_impl.dart';
import 'domain/repositories/${feature}_repository.dart';
import 'domain/usecases/get_${feature}_usecase.dart';
import 'presentation/bloc/${feature}_bloc.dart';

void register${className}Dependencies(GetIt getIt) {
  ${datasourceRegistration}
  if (!getIt.isRegistered<${className}Repository>()) {
    getIt.registerLazySingleton<${className}Repository>(() => ${className}RepositoryImpl(${remoteEnabled ? "getIt<${className}RemoteDataSource>()" : ""}));
  }
  if (!getIt.isRegistered<Get${className}UseCase>()) {
    getIt.registerLazySingleton(() => Get${className}UseCase(getIt<${className}Repository>()));
  }
  if (!getIt.isRegistered<${className}Bloc>()) {
    getIt.registerFactory(() => ${className}Bloc(getIt<Get${className}UseCase>()));
  }
}
''');
    } else {
      Console.info(
          'Preserved existing lib/features/$feature/${feature}_di.dart.');
    }

    final injection = File('${root.path}/lib/core/di/injection.dart');
    if (!await injection.exists()) {
      return;
    }
    var source = await injection.readAsString();
    const importsMarker = '// <bloc_cli:feature-imports>';
    const registrationsMarker = '// <bloc_cli:feature-registrations>';
    if (!source.contains(importsMarker)) {
      source = source.replaceFirst(
        'final getIt = GetIt.instance;',
        'final getIt = GetIt.instance;\n\n$importsMarker\n// </bloc_cli:feature-imports>',
      );
    }
    if (!source.contains(registrationsMarker)) {
      source = source.replaceFirst(
        RegExp(r'\n}\\s*$'),
        '\n  $registrationsMarker\n  // </bloc_cli:feature-registrations>\n}',
      );
    }
    if (!source.contains(importsMarker) ||
        !source.contains(registrationsMarker)) {
      Console.error(
          'Could not add GetIt registration markers to injection.dart.');
      return;
    }
    final importLine = "import '../../features/$feature/${feature}_di.dart';";
    final registrationLine = '  register${className}Dependencies(getIt);';
    if (!source.contains(importLine)) {
      source =
          source.replaceFirst(importsMarker, '$importsMarker\n$importLine');
    }
    if (!source.contains(registrationLine)) {
      source = source.replaceFirst(
          registrationsMarker, '$registrationsMarker\n$registrationLine');
    }
    await injection.writeAsString(source);
    Console.success('Registered $feature dependencies in GetIt.');
  }

  Future<bool> _addDependencies(Map<String, String> dependencies) async {
    final pubspec = File('${root.path}/pubspec.yaml');
    if (!await pubspec.exists()) {
      return false;
    }

    var content = await pubspec.readAsString();
    final lines = content.split('\n');
    final dependencyIndex = lines.indexWhere(
        (line) => RegExp(r'^dependencies\s*:\s*(#.*)?$').hasMatch(line));
    if (dependencyIndex == -1) return false;

    final existing = <String>{};
    var end = dependencyIndex + 1;
    while (end < lines.length) {
      final line = lines[end];
      if (line.trim().isNotEmpty &&
          !line.trimLeft().startsWith('#') &&
          !line.startsWith(' ') &&
          !line.startsWith('\t')) {
        break;
      }
      final match = RegExp(r'^\s{2}([A-Za-z0-9_]+)\s*:').firstMatch(line);
      if (match != null) existing.add(match.group(1)!);
      end++;
    }

    final additions = <String>[];
    for (final entry in dependencies.entries) {
      if (!existing.contains(entry.key)) {
        additions.add('  ${entry.key}: ${entry.value}');
      }
    }
    if (additions.isEmpty) return false;

    lines.insertAll(end, additions);
    await pubspec.writeAsString(lines.join('\n'));
    return true;
  }

  Future<bool> _addDevDependencies(Map<String, String> dependencies) async {
    if (dependencies.isEmpty) return false;
    final pubspec = File('${root.path}/pubspec.yaml');
    if (!await pubspec.exists()) {
      return false;
    }
    final lines = (await pubspec.readAsString()).split('\n');
    final sectionIndex = lines.indexWhere(
      (line) => RegExp(r'^dev_dependencies\s*:\s*(#.*)?$').hasMatch(line),
    );
    if (sectionIndex == -1) return false;
    final existing = <String>{};
    var end = sectionIndex + 1;
    while (end < lines.length) {
      final line = lines[end];
      if (line.trim().isNotEmpty &&
          !line.trimLeft().startsWith('#') &&
          !line.startsWith(' ') &&
          !line.startsWith('\t')) {
        break;
      }
      final match = RegExp(r'^\s{2}([A-Za-z0-9_]+)\s*:').firstMatch(line);
      if (match != null) existing.add(match.group(1)!);
      end++;
    }
    final additions = <String>[];
    for (final entry in dependencies.entries) {
      if (!existing.contains(entry.key)) {
        additions.add('  ${entry.key}: ${entry.value}');
      }
    }
    if (additions.isEmpty) return false;
    lines.insertAll(end, additions);
    await pubspec.writeAsString(lines.join('\n'));
    return true;
  }

  Future<void> _runPubGet() async {
    Console.info('Running flutter pub get...');
    try {
      final result = await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: root.path,
        runInShell: Platform.isWindows,
      );
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      if (result.exitCode == 0) {
        Console.success('flutter pub get completed.');
      } else {
        Console.error(
            'flutter pub get failed (exit code ${result.exitCode}). Run it manually.');
      }
    } catch (error) {
      Console.error('Could not run flutter pub get: $error');
      Console.info('Run flutter pub get manually from the Flutter project.');
    }
  }
}
