/// Stores the architecture and integration choices for a Flutter project.
///
/// Values are persisted in `.bloc_cli.json` and reused by subsequent
/// generation commands.
class ProjectConfig {
  /// Creates a project configuration from normalized integration choices.
  const ProjectConfig({
    required this.stateStyle,
    required this.networking,
    required this.routing,
    required this.navigationStyle,
    required this.dependencyInjection,
    required this.dataSource,
    required this.serialization,
    this.errorHandling = 'base_repository',
  });

  /// Selected event/state implementation: Equatable, Freezed, plain Dart, or custom.
  final String stateStyle;

  /// Selected networking integration, such as Dio, HTTP, custom, or none.
  final String networking;

  /// Selected navigation integration.
  final String routing;

  /// Whether route paths, route names, or both are generated.
  final String navigationStyle;

  /// Selected dependency registration strategy.
  final String dependencyInjection;

  /// Selected remote, local, combined, custom, or no datasource strategy.
  final String dataSource;

  /// Selected model serialization strategy.
  final String serialization;

  /// Centralized API error handling strategy.
  final String errorHandling;

  /// Converts this configuration to the stable on-disk JSON representation.
  Map<String, dynamic> toJson() => {
        'version': 1,
        'architecture': 'clean',
        'stateStyle': stateStyle,
        'networking': networking,
        'routing': routing,
        'navigationStyle': navigationStyle,
        'dependencyInjection': dependencyInjection,
        'dataSource': dataSource,
        'serialization': serialization,
        'errorHandling': errorHandling,
      };

  /// Creates a configuration from a previously saved JSON [json] map.
  factory ProjectConfig.fromJson(Map<String, dynamic> json) => ProjectConfig(
        stateStyle: _normalizeState(json['stateStyle'] as String?),
        networking: _normalizeNetworking(json['networking'] as String?),
        routing: _normalizeRouting(json['routing'] as String?),
        navigationStyle:
            _normalizeNavigationStyle(json['navigationStyle'] as String?),
        dependencyInjection:
            _normalizeDi(json['dependencyInjection'] as String?),
        dataSource: _normalizeDataSource(json['dataSource'] as String?),
        serialization:
            _normalizeSerialization(json['serialization'] as String?),
        errorHandling:
            _normalizeErrorHandling(json['errorHandling'] as String?),
      );

  static String _normalizeState(String? value) {
    switch ((value ?? 'equatable').toLowerCase()) {
      case 'freezed':
        return 'freezed';
      case 'plain dart':
      case 'plain_dart':
        return 'plain_dart';
      case 'custom':
        return 'custom';
      default:
        return 'equatable';
    }
  }

  static String _normalizeNetworking(String? value) {
    switch ((value ?? 'dio').toLowerCase()) {
      case 'http':
        return 'http';
      case 'custom':
      case 'custom (i will provide networking)':
        return 'custom';
      case 'none':
        return 'none';
      default:
        return 'dio';
    }
  }

  static String _normalizeRouting(String? value) {
    switch ((value ?? 'go_router').toLowerCase()) {
      case 'gorouter':
      case 'go_router':
        return 'go_router';
      case 'flutter default navigator':
      case 'flutter_default_navigator':
      case 'navigator':
        return 'flutter_default_navigator';
      case 'custom':
      case 'custom (i will provide routing)':
        return 'custom';
      case 'none':
        return 'none';
      default:
        return 'go_router';
    }
  }

  static String _normalizeNavigationStyle(String? value) {
    switch ((value ?? 'both').toLowerCase()) {
      case 'route paths':
      case 'route_paths':
        return 'route_paths';
      case 'route names':
      case 'route_names':
        return 'route_names';
      default:
        return 'both';
    }
  }

  static String _normalizeDi(String? value) {
    switch ((value ?? 'getit').toLowerCase()) {
      case 'getit':
      case 'get_it':
        return 'getit';
      case 'getit + injectable':
      case 'get_it + injectable':
      case 'getit_+_injectable':
        return 'getit_injectable';
      case 'manual':
        return 'manual';
      case 'custom':
        return 'custom';
      default:
        return 'getit';
    }
  }

  static String _normalizeDataSource(String? value) {
    switch ((value ?? 'remote').toLowerCase()) {
      case 'local':
        return 'local';
      case 'both':
        return 'both';
      case 'custom':
        return 'custom';
      case 'none':
        return 'none';
      default:
        return 'remote';
    }
  }

  static String _normalizeSerialization(String? value) {
    switch ((value ?? 'json_serializable').toLowerCase()) {
      case 'freezed':
        return 'freezed';
      case 'manual':
        return 'manual';
      case 'custom':
        return 'custom';
      default:
        return 'json_serializable';
    }
  }

  static String _normalizeErrorHandling(String? value) {
    switch ((value ?? 'base_repository').toLowerCase()) {
      case 'either':
        return 'either';
      case 'exceptions':
      case 'exception':
        return 'exceptions';
      case 'custom':
        return 'custom';
      case 'none':
        return 'none';
      default:
        return 'base_repository';
    }
  }

  /// Whether route path constants should be generated.
  bool get hasRoutePaths =>
      navigationStyle == 'route_paths' || navigationStyle == 'both';

  /// Whether route name constants should be generated.
  bool get hasRouteNames =>
      navigationStyle == 'route_names' || navigationStyle == 'both';

  /// Whether the selected router is GoRouter.
  bool get usesGoRouter => routing == 'go_router';

  /// Whether the selected router is Flutter Navigator.
  bool get usesNavigator => routing == 'flutter_default_navigator';

  /// Whether a built-in routing integration is selected.
  bool get usesBuiltInRouting => usesGoRouter || usesNavigator;
}
