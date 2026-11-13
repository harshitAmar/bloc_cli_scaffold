# bloc_cli_scaffold

The published Dart package is `bloc_cli_scaffold`; its installed executable command is `bloc_cli`.

A configurable Flutter CLI that scaffolds Clean Architecture features, screens, BLoC, routing, networking, and dependency injection.

`bloc_cli` reduces repetitive setup by generating a consistent feature-first structure and wiring supported integrations into an existing Flutter project. Generated code is a starting point: add real endpoints, models, validation, error handling, and application-specific behavior before shipping.

## Features

- Interactive Clean Architecture configuration.
- Feature generation with data, domain, and presentation layers.
- Additional screen generation inside an existing feature.
- Optional screen-scoped BLoC generation.
- Optional screen repository, use-case, model, and datasource templates.
- Dio and HTTP networking templates.
- API client, API result, and constructor-injected BaseRepository templates.
- GoRouter and Flutter Navigator route generation.
- Route path and route name constants.
- GetIt dependency registration templates.
- Dependency additions to the target Flutter project's `pubspec.yaml`.
- Existing-file preservation by default and explicit `--force` regeneration.
- Project configuration persistence in `.bloc_cli.json`.

## Requirements

- Dart SDK `>=3.3.0 <4.0.0`.
- Flutter SDK installed for target-project generation.
- Run commands from the root of an existing Flutter application.
- Add the Dart Pub cache `bin` directory to PATH to run the global executable.

## Installation

```bash
dart pub global activate bloc_cli_scaffold
```

Verify the installation:

```bash
bloc_cli --version
bloc_cli --help
```

On Windows, if the command is not recognized, add this directory to PATH and restart the terminal:

```text
%LOCALAPPDATA%\Pub\Cache\bin
```

### Activate from a local checkout

```bash
git clone https://github.com/harshitAmar/bloc_cli_scaffold.git
cd bloc_cli_scaffold
dart pub get
dart pub global activate --source path .
```


## Quick start

Navigate to your Flutter project:

```bash
cd path/to/flutter_app
```

Initialize the architecture and select integrations interactively:

```bash
bloc_cli init
```

Generate a feature:

```bash
bloc_cli create feature auth
```

Add a screen to an existing feature:

```bash
bloc_cli create screen profile --feature auth
```

Add a screen with a screen-scoped BLoC:

```bash
bloc_cli create screen profile --feature auth --with-bloc
```

Add a screen with a BLoC and repository/data/domain templates:

```bash
bloc_cli create screen profile --feature auth --with-bloc --with-repository
```

Regenerate target files intentionally:

```bash
bloc_cli create screen profile --feature auth --with-bloc --with-repository --force
```

> **Warning:** `--force` overwrites the matching generated files. Commit or back up custom changes first.

## Commands

| Command | Description |
|---|---|
| `bloc_cli help` | Show command help |
| `bloc_cli --version` | Show CLI version |
| `bloc_cli init` | Configure and initialize a Flutter project |
| `bloc_cli create feature <name>` | Generate a Clean Architecture feature |
| `bloc_cli create feature <name> --force` | Regenerate generated feature files |
| `bloc_cli create screen <name> --feature <feature>` | Add a screen to an existing feature |
| `bloc_cli create screen <name> --feature <feature> --with-bloc` | Add a screen and BLoC |
| `bloc_cli create screen <name> --feature <feature> --with-bloc --with-repository` | Add a screen with BLoC and repository templates |

## Configuration

`bloc_cli init` writes the selected options to `.bloc_cli.json` in the Flutter project root. The file is reused by later generation commands.

Example:

```json
{
  "version": 1,
  "architecture": "clean",
  "stateStyle": "equatable",
  "networking": "dio",
  "routing": "go_router",
  "navigationStyle": "both",
  "dependencyInjection": "getit",
  "dataSource": "remote",
  "serialization": "json_serializable",
  "errorHandling": "base_repository"
}
```

Available choices:

| Area | Options |
|---|---|
| BLoC state/event style | Equatable, Freezed, Plain Dart, Custom |
| Networking | Dio, HTTP, Custom, None |
| Routing | GoRouter, Flutter Navigator, Custom, None |
| Navigation constants | Paths, Names, Both |
| Dependency injection | GetIt, GetIt + Injectable, Manual, Custom |
| Datasource | Remote, Local, Both, Custom, None |
| Serialization | json_serializable, Freezed, Manual, Custom |

Some custom/manual integrations require application-specific wiring. Review the generated code and the console instructions for the selected options. In this release, automatic DI integration is primarily implemented for GetIt; do not assume that selecting Manual, Custom, or Injectable produces the same generated behavior as plain GetIt. The `BaseRepository` strategy is implemented for Dio-backed generated datasources; HTTP, Custom, and None networking choices keep their own integration path.

### BaseRepository result propagation

When Dio and `BaseRepository (centralized errors)` are selected, generated remote datasources return `Future<ApiResult<Model>>`. Repository implementations map that into `ApiResult<Entity>`, and repository contracts and UseCases preserve the typed result. Generated BLoCs explicitly handle success and failure with `result.when(...)`, preventing a failed API response from being emitted as a loaded state.

`ApiResult` is generated in `lib/core/network/api_result.dart`. Expected API failures are represented by `ApiResult.failure`; successful responses use `ApiResult.success`.

## Generated structure

A feature is generated in a feature-first layout similar to:

```text
lib/
├── core/
│   ├── di/
│   │   └── injection.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── api_response.dart
│   │   └── base_repository.dart
│   └── routes/
│       ├── app_routes.dart
│       └── app_router.dart
└── features/
    └── auth/
        ├── data/
        │   ├── datasources/
        │   ├── models/
        │   └── repositories/
        ├── domain/
        │   ├── entities/
        │   ├── repositories/
        │   └── usecases/
        └── presentation/
            ├── bloc/
            ├── pages/
            └── widgets/
```

The exact files depend on the selected configuration and the command flags.

## Screen lifecycle and dependency registration

When a screen is generated with `--with-bloc`, the route template creates the BLoC through `BlocProvider(create: ...)`. For GetIt, the generated screen BLoC is registered as a factory so each route instance receives a new BLoC. `BlocProvider` owns and closes the instance it creates when the provider is disposed.

Repository and use-case registrations are intended to be reusable feature dependencies. Review the generated feature DI file when adding multiple screens that share data/domain dependencies, and verify that the registrations are unique in your project.

For Dio, the generated DI initializer registers the `Dio` reference from the configured `ApiClient`; do not create a second independent Dio instance for individual features. Datasources should receive the registered instance through constructor injection. With `BaseRepository` error handling selected, generated Dio datasources extend `BaseRepository` and use its shared `handleApiCall` pipeline. `BaseRepository` receives Dio through its constructor; it does not perform a hidden GetIt lookup. `handleApiCall` maps transport and server errors to `ApiException`, while `safeApiCall` is available when a caller wants an `ApiResult<T>` instead of thrown exceptions.

## Dependencies and code generation

The CLI adds supported runtime and development dependencies to the target project's `pubspec.yaml` and attempts to run `flutter pub get` when it changes the manifest.

For projects using FVM, run dependency resolution with the project's FVM Flutter SDK if needed:

```bash
fvm flutter pub get
```

For Freezed or json_serializable, run build_runner after generation when generated serialization files are required:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Safe generation behavior

- Existing files are preserved by default.
- `--force` overwrites files targeted by the selected generator.
- Route and DI marker comments are used for generated registration blocks.
- Review diffs before committing generated changes.
- Keep `.bloc_cli.json` under version control if your team wants consistent generation settings.

## Development

```bash
dart pub get
dart format .
dart analyze
dart test
```

Run the CLI locally:

```bash
dart run bin/bloc_cli.dart --help
```

## Known limitations

- Generated datasource endpoints and response fields are starter examples; replace them with your API contract.
- The shared BaseRepository template currently targets Dio. HTTP and custom networking require their own error adapter.
- Existing `main.dart` integration is conservative and may print manual integration guidance when it cannot safely identify the app root.
- Manual and custom DI/routing strategies may require hand-written integration.
- Review local-only and combined datasource templates before using them in production.
- Generated code must be analyzed and tested inside the target Flutter application; the CLI package cannot infer all application-specific constructors or route conventions.

## Contributing

Issues and pull requests are welcome. Please include reproduction steps, the selected `.bloc_cli.json` configuration, and the generated file tree when reporting a generator bug.

1. Fork the repository.
2. Create a focused branch.
3. Add or update tests for the generator behavior.
4. Run formatting, analysis, and tests.
5. Open a pull request with a concise explanation.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
