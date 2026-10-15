## [0.1.1] - 2026-10-16

- The pubspec declares all six platforms. pub.dev listed 0.1.0 as Windows only, reading its platforms from the pointer-lock plugin, which is Windows only; the input system is Dart and runs on Android, iOS, Linux, macOS, Windows and the web (JavaScript and WebAssembly). Pointer lock is still Windows only: elsewhere `PointerLock.isSupported` is false and nothing happens. The library's code is unchanged.
- An example, `example/example.dart`: a dot moved by a `move` action (WASD, the arrow keys or a stick) that bounces on `jump`, from an input asset that passes `validateAsset` (a test keeps it so).
- just_gamepads package is upgraded to 0.1.1

## [0.1.0] - 2026-10-04


A new input system, replacing the old action layer outright.

- **Assets.** `InputActionAsset`, a `.input.json` file (format `just_inputs`, version 3): maps, actions (button / axis / vector 2, pass-through), bindings as control paths (`<Keyboard>/space`), composites (2D vector, 1D axis, one and two modifiers), interactions, processors, control schemes, on-screen controls and player settings. Stable ids for everything a player can rebind. `validateAsset` and `findBindingConflicts` (join actions excepted: they listen to other devices).
- **Runtime.** `InputService` replaces `InputManager` and `InputActionResolver`: one device per pad, physical keys, events queued and replayed in order at `update(now)` on the game's clock; live state for rebinding, applied state for actions. `InputActions` per set of devices; polling and callbacks; `enable(ignoreHeld:)`. Registries for composites, interactions and processors.
- **Players.** `PlayerInputManager`: first to play is player 1, join by action (hold to join, quick press to switch while alone), lost and regained devices, per-player overrides through `InputOverrideStore`.
- **Rebinding.** `RebindingOperation`, `rebindPlayer`, `KeyboardCaptureHook`.
- **Widgets.** `OnScreenControls` (replaces `VirtualJoystick` and `OnScreenActionButtons`), `BindingLabel`, `RebindButton`, `RebindList`; `BindingDisplay` and `GamepadGlyphs` for prompts.
- **Pointer lock** (Windows): `InputService.pointerLock` hides the cursor, holds it in the window and feeds the mouse's raw movement to the mouse, through a Windows plugin in this package (it was `just_pointer_lock`). `lockPointerOnClick` takes hold on a click on the game (`GameWidget`, and the editor's play-test); Escape lets go whatever widget has the keyboard (`PointerLock.releaseKeys`), as does the window going behind.
- **Raw mouse movement.** `MouseDevice.injectDelta` adds movement from outside Flutter's pointer events (a locked pointer's raw input). `MouseDevice.relativeMode` ignores the pointer events' own movement while the pointer is locked, so nothing counts twice. `InputService.attachRawMouse(deltas, relative:)` wires a stream and a lock flag to both.
- **A frame at a time.** `FrameMotion` reads an action's movement controls (the mouse's delta and wheel, a finger's drag) once per rendered frame: everything that moved since the last `take`, however many fixed updates ran in between, through the bindings' and the action's processors. Nothing moved while the action is off, or while a rebind is listening, counts. Controls that add up say so (`InputControl.accumulates`) and read their running total with `InputControl.readTotal`.
- **Look.** `LookInput.read(dt)` turns the two look actions into a frame's yaw and pitch in radians: movement times `LookSettings.radiansPerPixel`, plus stick deflection times degrees per second times `dt`. `LookActions.addTo` adds them to an asset: `look` (`<Mouse>/delta`, optionally `<Touchscreen>/delta`) and `lookStick` (`<Gamepad>/rightStick`, optionally an on-screen stick), each binding in its device's schemes.
- **Editor.** The Input Actions editor is not in this package. It moved to its own package, `just_input_editor`, the visual side of this one, along with the module that puts it in `just_game_engine_editor`. `package:just_inputs/editor.dart` is gone, and so is `dart:io`: the runtime runs on the web.
- **Testing.** `package:just_inputs/testing.dart`: `FakeGamepadSource`, `InputTester`.

Removed: `InputManager`, `InputActionResolver`, `InputActionSet`, `InputBinding`, `Vector2Binding`, `ControllerInput`, `VirtualJoystick`, `OnScreenActionButtons`, the old `GamepadButton`/`GamepadAxis` copies (use `just_gamepads`' or the control paths).

153 tests (the editor's 59 went with it to `just_input_editor`).
