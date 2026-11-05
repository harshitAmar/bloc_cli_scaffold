## 0.1.5
- Run networking and dependency generation during init and feature creation.
- Generate GoRouter/Navigator router files and register feature routes.
- Add required runtime/dev dependencies and run flutter pub get when changed.
- Add `--force` to regenerate existing feature files.

## 0.1.0

- Initial configurable Clean Architecture CLI scaffold.
- Interactive setup wizard and project configuration.
- Feature generation with domain, data, and presentation layers.
- Initial route path and route-name class generation.

## 0.1.2

- Normalize routing and integration selections explicitly.
- Generate missing files inside an existing feature directory without overwriting existing files.

## 0.1.3

- Added complete Dio and HTTP core networking templates.
- Added API client, endpoints, exception, response, result, base repository and auth-header integration.
- Automatically adds the selected networking dependency to the Flutter project's pubspec.yaml.
- Runs flutter pub get after adding a networking dependency.
- Existing networking files are preserved.

## 0.1.4

- Generated BaseRepository with safeApiCall and handleApiCall for Dio and HTTP.
- Generated feature repository implementations extend BaseRepository.
- Domain repository contracts and use cases expose ApiResult.
- BLoC maps ApiResult success/failure into presentation states.
- Remote datasources return raw transport responses so BaseRepository owns response parsing.
- Added basic GetIt registration for the selected networking client.

### 0.1.4+1

- Fixed generated repository constructor and BaseRepository inheritance.
- Kept custom/none networking generation independent from BaseRepository imports.
- ApiResponse supports wrapped and unwrapped payloads.
