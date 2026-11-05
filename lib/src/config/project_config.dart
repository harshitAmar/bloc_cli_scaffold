
class ProjectConfig {
  const ProjectConfig({
    required this.stateStyle,
    required this.networking,
    required this.routing,
    required this.navigationStyle,
    required this.dependencyInjection,
    required this.dataSource,
    required this.serialization,
  });

  final String stateStyle;
  final String networking;
  final String routing;
  final String navigationStyle;
  final String dependencyInjection;
  final String dataSource;
  final String serialization;

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
  };

  factory ProjectConfig.fromJson(Map<String, dynamic> json) => ProjectConfig(
    stateStyle: _normalizeState(json['stateStyle'] as String?),
    networking: _normalizeNetworking(json['networking'] as String?),
    routing: _normalizeRouting(json['routing'] as String?),
    navigationStyle: _normalizeNavigationStyle(json['navigationStyle'] as String?),
    dependencyInjection: _normalizeDi(json['dependencyInjection'] as String?),
    dataSource: _normalizeDataSource(json['dataSource'] as String?),
    serialization: _normalizeSerialization(json['serialization'] as String?),
  );

  static String _normalizeState(String? value) {
    switch ((value ?? 'equatable').toLowerCase()) {
      case 'freezed': return 'freezed';
      case 'plain dart':
      case 'plain_dart': return 'plain_dart';
      case 'custom': return 'custom';
      default: return 'equatable';
    }
  }

  static String _normalizeNetworking(String? value) {
    switch ((value ?? 'dio').toLowerCase()) {
      case 'http': return 'http';
      case 'custom':
      case 'custom (i will provide networking)': return 'custom';
      case 'none': return 'none';
      default: return 'dio';
    }
  }

  static String _normalizeRouting(String? value) {
    switch ((value ?? 'go_router').toLowerCase()) {
      case 'gorouter':
      case 'go_router': return 'go_router';
      case 'flutter default navigator':
      case 'flutter_default_navigator':
      case 'navigator': return 'flutter_default_navigator';
      case 'custom':
      case 'custom (i will provide routing)': return 'custom';
      case 'none': return 'none';
      default: return 'go_router';
    }
  }

  static String _normalizeNavigationStyle(String? value) {
    switch ((value ?? 'both').toLowerCase()) {
      case 'route paths':
      case 'route_paths': return 'route_paths';
      case 'route names':
      case 'route_names': return 'route_names';
      default: return 'both';
    }
  }

  static String _normalizeDi(String? value) {
    switch ((value ?? 'getit').toLowerCase()) {
      case 'getit':
      case 'get_it': return 'getit';
      case 'getit + injectable':
      case 'get_it + injectable':
      case 'getit_+_injectable': return 'getit_injectable';
      case 'manual': return 'manual';
      case 'custom': return 'custom';
      default: return 'getit';
    }
  }

  static String _normalizeDataSource(String? value) {
    switch ((value ?? 'remote').toLowerCase()) {
      case 'local': return 'local';
      case 'both': return 'both';
      case 'custom': return 'custom';
      case 'none': return 'none';
      default: return 'remote';
    }
  }

  static String _normalizeSerialization(String? value) {
    switch ((value ?? 'json_serializable').toLowerCase()) {
      case 'freezed': return 'freezed';
      case 'manual': return 'manual';
      case 'custom': return 'custom';
      default: return 'json_serializable';
    }
  }

  bool get hasRoutePaths => navigationStyle == 'route_paths' || navigationStyle == 'both';
  bool get hasRouteNames => navigationStyle == 'route_names' || navigationStyle == 'both';
  bool get usesGoRouter => routing == 'go_router';
  bool get usesNavigator => routing == 'flutter_default_navigator';
  bool get usesBuiltInRouting => usesGoRouter || usesNavigator;
}
