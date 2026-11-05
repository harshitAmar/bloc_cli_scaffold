# bloc_cli_scaffold

A configurable Flutter CLI for generating feature-first Clean Architecture projects with BLoC, networking, routing, dependency injection, and serialization options.

`bloc_cli` helps you establish a consistent project structure and generate new features without repeatedly creating boilerplate files.

## Features

- Initialize Clean Architecture structure in an existing Flutter project.
- Generate feature modules with `bloc_cli create feature`.
- Choose your preferred BLoC state and event implementation.
- Select a networking solution.
- Configure routing and navigation constants.
- Choose a dependency injection strategy.
- Generate remote and/or local datasource structures.
- Select a serialization strategy.
- Automatically update project dependencies when supported by the selected configuration.
- Save project configuration in `.bloc_cli.json`.
- Preserve existing files by default.
- Use `--force` when you intentionally want to regenerate existing generated files.

## Installation

Install the CLI globally:

```bash
dart pub global activate bloc_cli_scaffold
```

Verify the installation:

```bash
bloc_cli --version
bloc_cli --help
```

### Windows PATH configuration

If the `bloc_cli` command is not recognized, add the Dart Pub cache executable directory to your PATH:

```text
%LOCALAPPDATA%\Pub\Cache\bin
```

Restart your terminal after updating PATH.

### Activate from source

To use a local checkout while developing:

```bash
git clone https://github.com/YOUR_USERNAME/bloc_cli_scaffold.git
cd bloc_cli_scaffold

dart pub get
dart pub global activate --source path .
```

## Requirements

- Dart SDK compatible with the package's declared SDK constraint.
- Flutter SDK installed and available in PATH.
- An existing Flutter project for the `init` and feature-generation workflows.
- Internet access when the CLI needs to resolve newly added dependencies.

If you use FVM, run the CLI from the terminal where your Flutter SDK is configured and available.

## Quick start

### 1. Initialize your Flutter project

Navigate to your existing Flutter project:

```bash
cd my_flutter_app
```

Run:

```bash
bloc_cli init
```

The CLI guides you through the architecture configuration and generates the selected core structure.

### 2. Create a feature

```bash
bloc_cli create feature auth
```

This generates the feature structure according to your saved configuration.

### 3. Generate again with force

By default, existing files are preserved. If you intentionally want to overwrite generated files:

```bash
bloc_cli create feature auth --force
```

**Warning:** `--force` can overwrite your existing implementation. Commit or back up your work before using it.

## Configuration

During initialization, `bloc_cli` asks you to choose the architecture and implementation options.

Your choices are saved in:

```text
.bloc_cli.json
```

The saved configuration is reused when generating additional features.

### State management

Choose how BLoC events and states should be implemented:

| Option | Description |
|---|---|
| Equatable | Value equality using Equatable |
| Freezed | Immutable classes and generated union/data classes |
| Plain Dart | Standard Dart classes |
| Custom | Use your own implementation approach |

### Networking

| Option | Description |
|---|---|
| Dio | Dio-based HTTP client |
| HTTP | Dart HTTP package |
| Custom | Use your own networking implementation |
| None | Do not generate networking integration |

### Routing

| Option | Description |
|---|---|
| GoRouter | GoRouter-based navigation |
| Flutter Navigator | Built-in Flutter Navigator |
| Custom | Use your own routing implementation |
| None | Do not generate routing integration |

### Navigation constants

| Option | Description |
|---|---|
| Paths | Generate route paths |
| Names | Generate route names |
| Both | Generate route paths and names |

### Dependency injection

| Option | Description |
|---|---|
| GetIt | GetIt service locator |
| GetIt + Injectable | GetIt with Injectable-based registration |
| Manual | Manual dependency initialization |
| Custom | Use your own dependency injection approach |

### Datasource

| Option | Description |
|---|---|
| Remote | Remote datasource structure |
| Local | Local datasource structure |
| Both | Remote and local datasource structures |
| Custom | Use your own datasource implementation |
| None | Do not generate datasource integration |

### Serialization

| Option | Description |
|---|---|
| json_serializable | JSON serialization using json_serializable |
| Freezed | Freezed-based model generation |
| Manual | Manually written serialization |
| Custom | Use your own serialization approach |

## Configuration example

A representative `.bloc_cli.json` configuration:

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
  "serialization": "json_serializable"
}
```

The exact values in this file are managed by the CLI. Keep the file in your project root so future feature generation uses the same choices.

## Generated architecture

The generated structure depends on your configuration. A representative feature-first Clean Architecture layout looks like this:

```text
lib/
├── core/
│   ├── di/
│   │   └── injection.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   └── base_repository.dart
│   └── routes/
│       ├── app_routes.dart
│       └── app_router.dart
│
└── features/
    └── auth/
        ├── data/
        │   ├── datasources/
        │   ├── models/
        │   └── repositories/
        │
        ├── domain/
        │   ├── entities/
        │   ├── repositories/
        │   └── usecases/
        │
        └── presentation/
            ├── bloc/
            ├── pages/
            └── widgets/
```

This is a representative layout. Generated folders and files vary depending on your selected options and the generator version.

## Networking and dependency injection

When Dio is selected, the generated networking layer should centralize its configuration in the API client.

The dependency injection setup should reuse the API client's Dio instance rather than creating multiple Dio instances. This allows configured headers, interceptors, timeouts, and other client settings to be shared.

Review generated registrations and constructor dependencies when integrating the generated code into an existing application.

## Generated code and customization

`bloc_cli` is intended to reduce repetitive setup, not to replace application-specific development.

After generating a feature:

1. Review the generated files.
2. Add your API endpoints and request/response models.
3. Implement business rules and validation.
4. Connect datasource and repository methods.
5. Add application-specific dependency registrations.
6. Review route declarations and page imports.
7. Run code generation where required by your selected serialization option.
8. Run analysis and tests before committing.

Existing files are preserved by default. Use `--force` only when you intend to regenerate files.

## Commands

| Command | Description |
|---|---|
| `bloc_cli --help` | Display available commands and usage |
| `bloc_cli --version` | Display the installed CLI version |
| `bloc_cli init` | Initialize the project architecture |
| `bloc_cli create feature <name>` | Generate a feature |
| `bloc_cli create feature <name> --force` | Regenerate existing feature files |

## Troubleshooting

### `bloc_cli` is not recognized

Make sure the Dart Pub cache executable directory is on PATH:

```text
%LOCALAPPDATA%\Pub\Cache\bin
```

Then restart your terminal.

### Dependencies are not added

Check the selected networking, routing, state management, and serialization options in `.bloc_cli.json`.

Run the following from your Flutter project:

```bash
flutter pub get
```

If you use FVM:

```bash
fvm flutter pub get
```

### Existing files were not regenerated

The CLI preserves existing files by default. Use `--force` only when you want to overwrite generated files:

```bash
bloc_cli create feature auth --force
```

### Generated code has errors

Check that:

- The selected dependencies are present in `pubspec.yaml`.
- `flutter pub get` completed successfully.
- Required code generation commands have been run.
- Generated imports and route declarations match your actual project structure.
- Your existing classes and constructor signatures match the generated registrations.

## Contributing

Contributions, bug reports, and feature requests are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Run formatting, analysis, and tests.
5. Open a pull request with a clear description.

```bash
dart format .
dart analyze
dart test
```

## Issues and feature requests

Report bugs and request features:

[GitHub Issues](https://github.com/YOUR_USERNAME/bloc_cli_scaffold/issues)

## License

This project is distributed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Note:** `bloc_cli` generates starter code. Always review, test, and adapt generated code to your application's requirements before using it in production.

## License

This project is licensed under the MIT License.
See the [LICENSE](LICENSE) file for details.