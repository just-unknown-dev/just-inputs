## [0.1.0] - 2026-10-04


A new input system, replacing the old action layer outright.

- **Assets.** `InputActionAsset`, a `.input.json` file (format `just_inputs`,
  version 3): maps, actions (button / axis / vector 2, pass-through), bindings
  as control paths (`<Keyboard>/space`), composites (2D vector, 1D axis, one
  and two modifiers), interactions, processors, control schemes, on-screen
  controls and player settings. Stable ids for everything a player can
  rebind. `validateAsset` and `findBindingConflicts` (join actions excepted:
  they listen to other devices).
- **Runtime.** `InputService` replaces `InputManager` and
  `InputActionResolver`: one device per pad, physical keys, events queued and
  replayed in order at `update(now)` on the game's clock; live state for
  rebinding, applied state for actions. `InputActions` per set of devices;
  polling and callbacks; `enable(ignoreHeld:)`. Registries for composites,
  interactions and processors.
- **Players.** `PlayerInputManager`: first to play is player 1, join by
  action (hold to join, quick press to switch while alone), lost and
  regained devices, per-player overrides through `InputOverrideStore`.
- **Rebinding.** `RebindingOperation`, `rebindPlayer`, `KeyboardCaptureHook`.
- **Widgets.** `OnScreenControls` (replaces `VirtualJoystick` and
  `OnScreenActionButtons`), `BindingLabel`, `RebindButton`, `RebindList`;
  `BindingDisplay` and `GamepadGlyphs` for prompts.
- **Editor.** The Input Actions editor is not in this package. It moved to
  its own package, `just_input_editor`, the visual side of this one, along
  with the module that puts it in `just_game_engine_editor`.
  `package:just_inputs/editor.dart` is gone, and so is `dart:io`: the
  runtime runs on the web.
- **Testing.** `package:just_inputs/testing.dart`: `FakeGamepadSource`,
  `InputTester`.

Removed: `InputManager`, `InputActionResolver`, `InputActionSet`,
`InputBinding`, `Vector2Binding`, `ControllerInput`, `VirtualJoystick`,
`OnScreenActionButtons`, the old `GamepadButton`/`GamepadAxis` copies (use
`just_gamepads`' or the control paths).

131 tests (the editor's 59 went with it to `just_input_editor`).
