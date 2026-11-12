import 'package:bloc_cli/src/config/project_config.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectConfig', () {
    test('round-trips normalized configuration values', () {
      const config = ProjectConfig(
        stateStyle: 'equatable',
        networking: 'dio',
        routing: 'go_router',
        navigationStyle: 'both',
        dependencyInjection: 'getit',
        dataSource: 'remote',
        serialization: 'json_serializable',
        errorHandling: 'base_repository',
      );

      final restored = ProjectConfig.fromJson(config.toJson());

      expect(restored.stateStyle, 'equatable');
      expect(restored.networking, 'dio');
      expect(restored.routing, 'go_router');
      expect(restored.hasRoutePaths, isTrue);
      expect(restored.hasRouteNames, isTrue);
      expect(restored.errorHandling, 'base_repository');
    });

    test('normalizes legacy routing and datasource values', () {
      final config = ProjectConfig.fromJson({
        'stateStyle': 'Plain Dart',
        'networking': 'HTTP',
        'routing': 'Flutter Default Navigator',
        'navigationStyle': 'Route paths',
        'dependencyInjection': 'Manual',
        'dataSource': 'Both',
        'serialization': 'Manual',
      });

      expect(config.stateStyle, 'plain_dart');
      expect(config.networking, 'http');
      expect(config.routing, 'flutter_default_navigator');
      expect(config.navigationStyle, 'route_paths');
      expect(config.dataSource, 'both');
      expect(config.errorHandling, 'base_repository');
    });

    test('persists the selected API error handling strategy', () {
      final config = ProjectConfig.fromJson({
        'stateStyle': 'equatable',
        'networking': 'dio',
        'routing': 'go_router',
        'navigationStyle': 'both',
        'dependencyInjection': 'getit',
        'dataSource': 'remote',
        'serialization': 'json_serializable',
        'errorHandling': 'exceptions',
      });

      expect(config.errorHandling, 'exceptions');
      expect(config.toJson()['errorHandling'], 'exceptions');
    });
  });
}
