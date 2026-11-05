# bloc_cli

A configurable Flutter BLoC Clean Architecture scaffolding CLI.

## Install locally

```bash
dart pub global activate --source path .
```

Ensure the Dart pub cache `bin` directory is on your PATH.

## Usage

Run commands from the root of an existing Flutter project:

```bash
bloc_cli init
bloc_cli create feature auth
bloc_cli help
```

`init` stores project choices in `.bloc_cli.json`. Commit or ignore this file according to your team's workflow; it is added to `.gitignore` by default.

## Configuration choices

- BLoC classes: Equatable, Freezed, Plain Dart, Custom
- Networking: Dio, HTTP, Custom, None
- Routing: GoRouter, Flutter Default Navigator, Custom, None
- Navigation constants: Route paths, Route names, Both
- DI: GetIt, GetIt + Injectable, Manual, Custom
- Data sources: Remote, Local, Both, Custom, None
- Serialization: json_serializable, Freezed, Manual, Custom

## Current implementation scope (0.1.0)

The initial scaffold includes:
- Interactive project configuration
- Configuration persistence
- Clean Architecture feature generation
- Starter route path/name class generation
- Dio, HTTP, and custom datasource templates

The following are intentionally not automated yet:
- Updating `pubspec.yaml` dependencies
- GoRouter / Navigator route registration and page injection
- DI registration generation
- Individual `create bloc`, `create entity`, etc. commands
- Full Freezed generation compatibility and build_runner setup

Review generated TODOs and add the packages selected during initialization before running `flutter pub get`.
