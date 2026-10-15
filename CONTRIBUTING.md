# Contributing to Just Inputs

Thank you for your interest in contributing to **Just Inputs**. Bug fixes, features, tests and documentation are all welcome.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs and Suggesting Features](#reporting-bugs-and-suggesting-features)
- [Development Setup](#development-setup)
- [Working Against Unpublished Dependencies](#working-against-unpublished-dependencies)
- [How the Package Fits Together](#how-the-package-fits-together)
- [Running the Tests](#running-the-tests)
- [Coding Guidelines](#coding-guidelines)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Commit Message Convention](#commit-message-convention)
- [License](#license)

---

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By taking part you agree to its terms. Please report unacceptable behaviour to the maintainers.

---

## Reporting Bugs and Suggesting Features

Before opening an issue, search the [existing issues](https://github.com/just-unknown-dev/just-inputs/issues) and check that the problem happens on the latest version.

A bug report should have:

- a clear title;
- steps to reproduce, and what you expected instead of what happened;
- the output of `flutter --version`, and the platform (Android, iOS, Linux, macOS, Windows, web; for the web, the browser and whether it was a JavaScript or a WebAssembly build);
- the `.input.json` asset, or the smallest part of it that shows the problem: the map, the action and its bindings, with their interactions and processors;
- for a timing bug (`hold`, `tap`, `slowTap`, `multiTap`), the interaction's settings and how often your game calls `InputService.update`;
- for a keyboard bug, the keyboard layout (QWERTY, AZERTY, …);
- for a gamepad bug, the controller, how it is connected, and whether the `just_gamepads` example app reads it correctly. If the example app is wrong too, the bug belongs in [just_gamepads](https://github.com/just-unknown-dev/just-gamepads/issues).

A bug in the Input Actions editor belongs in `just_input_editor`, not here.

For a feature, open an issue labelled **`enhancement`** that describes the problem it solves and how it should behave. The package's scope is turning device input into game actions: the asset, the runtime, local players, rebinding, binding prompts and on-screen controls. Reading controllers is `just_gamepads`'s job, editing assets is `just_input_editor`'s, and running input in the game loop is `just_game_engine`'s. A change to the `.input.json` format affects the editor and every game's saved assets, so open the issue first and agree the approach before you write it.

---

## Development Setup

| Tool | Minimum version |
|------|-----------------|
| Dart | 3.12.2 |
| Flutter | A stable release that ships Dart 3.12.2 or later |

There is no app to run here: you work on the package and its tests. To try a change in a real game, add the package to a Flutter app as a path dependency (`path: ../just-inputs`).

```bash
git clone https://github.com/just-unknown-dev/just-inputs.git
cd just-inputs
flutter pub get
flutter test
```

If you're working from the Just engine monorepo, run every command from `packages/just_inputs`.

---

## Working Against Unpublished Dependencies

The package's only dependency besides Flutter is `just_gamepads`. When a change needs an unreleased version of it, check `just_gamepads` out next to this repository and point this package at it with a `pubspec_overrides.yaml` in the repository root:

```yaml
# pubspec_overrides.yaml: local only, never commit it.
dependency_overrides:
  just_gamepads:
    path: ../just_gamepads
```

Then run `flutter pub get`. Delete the file (or the entry) and run `flutter pub get` again to go back to the published version.

Do not change `pubspec.yaml` to a path dependency. If your pull request needs a version of `just_gamepads` that is not published yet, say so in the pull request: this package can only be released after it.

Two packages depend on this one: `just_input_editor`, which edits its assets, and `just_game_engine`, which runs them. If you change the public API or the asset format, say in the pull request what they will need.

---

## How the Package Fits Together

| Folder | Contents |
|--------|----------|
| `lib/src/model/` | The asset: `InputActionAsset` and its maps, actions, bindings, schemes, on-screen controls and settings; `validateAsset` and `findBindingConflicts` |
| `lib/src/paths/` | Control paths (`<Keyboard>/space`) and the catalogue of controls each device family has |
| `lib/src/devices/` | The devices: keyboard, mouse, touchscreen, one per gamepad, and the on-screen controls |
| `lib/src/runtime/` | `InputService`, `InputActions` and `InputAction`; the composite, interaction and processor registries |
| `lib/src/players/` | `PlayerInputManager`: joining, lost and regained devices, scheme matching |
| `lib/src/rebinding/` | `RebindingOperation`, `BindingOverrides` and `InputOverrideStore` |
| `lib/src/display/` | `BindingDisplay` and `GamepadGlyphs`: the text and glyphs for prompts |
| `lib/src/widgets/` | `OnScreenControls`, `BindingLabel`, `RebindButton`, `RebindList` |
| `lib/testing.dart` | `FakeGamepadSource` and `InputTester`, for tests only |
| `test/` | The tests; `test/sample_asset.dart` is a platformer-shaped asset many of them share |

A few rules hold the package together. Keep them:

- **The asset is immutable.** Every edit makes a new `InputActionAsset`. The editor's undo keeps whole assets, and the runtime swaps one in between two frames.
- **The same asset always writes the same bytes.** `encode()` writes keys in a fixed order, so a save that changed nothing changes nothing in version control. Add a new field at a fixed place in `toJson`.
- **Saved assets must keep loading.** The file carries `format: just_inputs` and `version: 3`, and `fromJson` reads only that version. A new field is optional, with a default that keeps the old behaviour, and then needs no new version. Never rename or reuse a key. Add a test in `test/asset_codec_test.dart` that reads JSON written before your change.
- **Ids are stable.** Bindings and composite parts get their ids from `InputActionAsset.takeId`, and players' rebinds are stored by those ids. Never renumber, reuse or derive an id from a position.
- **Input time is the game's clock.** Events are queued as they arrive and replayed in order at `update(now)`, so a press and a release between two updates still count as a press. Nothing under `lib/` reads the wall clock: no `DateTime.now`, `Stopwatch` or `Timer`. Interactions time themselves from `now`.
- **Keys are bound by position.** Bindings use `PhysicalKeyboardKey`, so WASD stays under the left hand on AZERTY. The key's label is only for display.
- **Gamepads arrive in `just_gamepads`' standard layout:** sticks with Y positive down, face buttons named by position. Don't special-case a controller brand here; fix the mapping in `just_gamepads`.
- **Composites, interactions and processors are registry entries** in `InputComposites`, `InputInteractions` and `InputProcessors`. An entry's `StepInfo` lists each setting as a `ParamInfo`, and the editor draws its fields from that list, so a new setting needs one. Assets save the entry's type name, so never rename one.

---

## Running the Tests

Run every command from the repository root. `test/library_boundary_test.dart` reads `lib/` from disk and expects that working directory.

```bash
# The whole suite.
flutter test

# One file.
flutter test test/runtime_test.dart
```

**The library boundary.** `test/library_boundary_test.dart` walks every import that `just_inputs.dart` reaches. It fails if the runtime reaches `testing.dart`, or reaches `dart:io`, which would break web builds.

**Writing tests.** Use `lib/testing.dart`: `InputTester` presses keys and steps the clock, and `FakeGamepadSource` plugs in pads and sends their state. Both are synchronous, so a test can press and check straight away. Move time with `InputTester.step` and never wait on a real timer.

---

## Coding Guidelines

- **Formatting.** Code is formatted with `dart format`. This must report no changes:

  ```bash
  dart format --output=none --set-exit-if-changed lib test
  ```

- **Analysis.** `flutter analyze` must report no issues at all: no errors, warnings or infos. The rules are in `analysis_options.yaml`: `flutter_lints`.
- **Web and WebAssembly.** The package runs on every Flutter platform, including web builds compiled to JavaScript and to WebAssembly. Nothing in `lib/` may import `dart:io` or `dart:html`; the library boundary test checks it.
- **No process-wide state** except the three registries. Per-game state belongs to an `InputService`, and per-player state to a `PlayerInput`.
- **Documentation.** Give every public API you add a `///` doc comment. Describe user-visible changes in [CHANGELOG.md](CHANGELOG.md), and update [README.md](README.md) if the public API changes.
- **Tests.** Add or update tests for any behaviour you change. A bug fix comes with a test that fails without it.
- **Dependencies.** Do not add a dependency without discussing it in an issue first.
- **Structure.** Match the existing folders under `lib/src/`. Export new public API through `lib/just_inputs.dart`, and test helpers through `lib/testing.dart`. Other code imports those libraries, not files under `lib/src/`.

---

## Submitting a Pull Request

1. Create a topic branch from `main`:
   ```bash
   git checkout -b fix/hold-cancel-on-release
   ```
2. Make your change, following the [Coding Guidelines](#coding-guidelines).
3. Check that everything passes:
   ```bash
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test
   ```
4. Commit with a [conventional commit message](#commit-message-convention).
5. Push to your fork and open a pull request against `main`. Say what changed and why. List any unpublished `just_gamepads` version it needs, and any change it means for `just_input_editor` or `just_game_engine`.
6. Answer review feedback.

Small pull requests are easier to review.

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependencies |

Use the area as the scope: `model`, `paths`, `devices`, `runtime`, `players`, `rebinding`, `display`, `widgets` or `testing`. Mark a change that breaks the public API or the asset format with `!` and a `BREAKING CHANGE:` footer.

**Examples:**
```
fix(runtime): cancel a hold released on the same update it started
feat(runtime): add a response curve processor
docs(contributing): explain the asset format rules
```

---

## License

By contributing to Just Inputs you agree that your contributions will be licensed under the [BSD-3-Clause License](LICENSE).
