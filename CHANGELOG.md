# 1.0.0
- Added application entry-point generation and guarded integration for an existing `lib/main.dart`.
- Added screen generation inside an existing feature.
- Added optional screen-scoped BLoC generation.
- Added optional screen repository, use-case, entity, model, and datasource templates.
- Added automatic feature route updates for supported GoRouter and Navigator configurations.
- Added screen BLoC factory registration for GetIt-based projects.
- Added API documentation comments to the public CLI and generator APIs.
- Fixed `curly_braces_in_flow_control_structures` lint findings in `networking_generator.dart`.
- Expanded README documentation with installation, configuration, commands, generated structure, lifecycle guidance, and limitations.

# 0.1.0

* Initial public release of bloc_cli_scaffold.
* Added Clean Architecture project initialization.
* Added feature generation.
* Added configurable state management, networking, routing,
  dependency injection, datasource, and serialization options.
* Added project configuration persistence.
* Added protection for existing files and optional force regeneration.