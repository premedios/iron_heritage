# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

`iron_heritage` is currently an **unmodified `flutter create` scaffold**. `lib/` contains only `main.dart` (the default counter demo) and `test/` only `widget_test.dart`. There is no app architecture, state management, routing, or dependency layer yet — treat structural decisions as open, and don't assume conventions exist that aren't in the code.

## Commands

```bash
flutter pub get                     # install deps
flutter run                         # run on connected device/emulator
flutter analyze                     # lint + static analysis
flutter test                        # all tests
flutter test test/widget_test.dart  # a single test file
flutter test --name "substring"     # a single test by name

dart run build_runner build         # regenerate freezed/json code
dart run build_runner watch         # regenerate continuously while editing
```

Run the generator after any change to a `@freezed`-annotated class, or the
`.freezed.dart` / `.g.dart` parts go stale and analysis fails.

## Constraints to respect

- **Platforms: Android and iOS only.** Only `android/` and `ios/` exist. `flutter run -d chrome` (or windows/macos/linux) fails until the platform is added via `flutter create --platforms=<p> .`.
- **Dart dot-shorthand syntax is in use.** `main.dart` writes `colorScheme: .fromSeed(...)` and `mainAxisAlignment: .center` rather than the fully-qualified `ColorScheme.fromSeed` / `MainAxisAlignment.center`. This needs the `sdk: ^3.12.2` pin in `pubspec.yaml`; do not lower it, and prefer this style when editing existing code that already uses it.
- Lints come from `package:flutter_lints/flutter.yaml` with no project overrides in `analysis_options.yaml`.
- **Not a git repository.** No VCS workflow is set up; `git` commands will fail until `git init`.

## Code generation (freezed)

Data classes use [freezed](https://pub.dev/packages/freezed) with
`json_serializable`.

> **Version note:** `freezed` is pinned to **exactly `3.2.5`** (stable) — no
> prereleases, deliberately. `dart pub add dev:freezed` will resolve to the
> `4.0.0-dev.x` line, because freezed 3.0-3.2.0 caps `source_gen` at ^2/^3 while
> `json_serializable ^6.14.0` needs ^4.1.2. Do not accept that resolution:
> 3.2.5 satisfies both (`source_gen 4.2.3`) at the cost of holding `analyzer` at
> 10.2.0 instead of 13.x. Revisit only when freezed 4.0 ships stable.

Two syntax gotchas — most snippets online are 2.x and will not compile here:

- Freezed 3.x/4.x requires **`abstract class`** (or `sealed class` for unions).
  Plain `class Foo with _$Foo` is a 2.x pattern and fails to generate.
- This project's `build_runner` has **removed `--delete-conflicting-outputs`**;
  passing it prints `These options have been removed and were ignored`. Just run
  `dart run build_runner build`.

Verified working shape:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_model.freezed.dart';
part 'my_model.g.dart';   // only if the class needs fromJson/toJson

@freezed
abstract class MyModel with _$MyModel {
  const factory MyModel({
    required String name,
    @Default(0) int count,
  }) = _MyModel;

  factory MyModel.fromJson(Map<String, dynamic> json) => _$MyModelFromJson(json);
}
```

Generated `.freezed.dart` / `.g.dart` files are **not** in `.gitignore`, so they
are currently tracked. That is a deliberate-or-not choice worth settling before
the first commit — either keep committing them or add `*.freezed.dart` /
`*.g.dart` and generate in CI.
