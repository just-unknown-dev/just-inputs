# just_inputs

Input for Flutter games: named **actions** bound to keyboard, mouse, gamepads and touch, read the same way whatever the device — plus local multiplayer, player rebinding and on-screen controls. Modelled on Unity's Input System.

```dart
final input = InputService()
  ..loadAsset(InputActionAsset.parse(await rootBundle.loadString('assets/input/game.input.json')));
await input.attachGamepads();

// Once per fixed step, with your game's clock:
input.update(now);

if (input.actions.action('player/jump').wasPressedThisFrame()) jump();
final move = input.actions.action('player/move').readVector2(); // y down
```

## The pieces

| | |
|---|---|
| **Asset** (`InputActionAsset`, a `.input.json` file) | Everything below, saved together. Immutable; the editor and the runtime both read it. |
| **Map** | Actions switched on and off together — `player` while playing, `ui` in menus. Each says whether it is on at start. |
| **Action** | Something the player does: a `button`, an `axis` or a `vector2`. The strongest binding drives it (or, with *pass-through*, the latest). |
| **Binding** | A control path, `<Keyboard>/space`, `<Gamepad>/leftStick`, `<OnScreen>/jump` — or a **composite**: `2DVector` (WASD), `1DAxis` (Q/E), `OneModifier`/`TwoModifiers` (Shift + E). |
| **Interaction** | How a press becomes the action: `press`, `hold`, `tap`, `slowTap`, `multiTap`. Phases: *started*, *performed*, *canceled*. |
| **Processor** | A change on the way: dead zones, `normalize`, `invert`, `scale`, `clamp`. |
| **Scheme** | A way of playing — Keyboard & Mouse, Gamepad, Touch — and its bindings, by group. |

Keys are bound by **position** (`PhysicalKeyboardKey`), so WASD stays under the left hand on AZERTY. Labels are learned from the player's own presses: `BindingDisplay(keyboard: input.keyboard)`.

Every event is queued as it arrives and replayed in order at `update(now)`, so a press and a release between two updates is still a press. Input time is the clock you pass — never the wall clock.

## Reading actions

```dart
final jump = actions.action('player/jump');
jump.isPressed();             jump.wasPressedThisFrame();  jump.wasReleasedThisFrame();
jump.phase;                   jump.wasPerformedThisFrame();
jump.onPerformed((a) => ...); // synchronous, inside update()
actions.map('player')!.disable();
actions.map('player')!.enable(ignoreHeld: true); // the press that closed the menu does not jump
```

## Players

```dart
input.players.start();
input.players.joined.listen((p) => spawnCharacter(p.index));
input.actionsFor(1)?.action('player/jump');
```

With `players.start()`:

- player 1 is whoever plays first, with whatever they touch;
- a device nobody uses joins as the next player when a **join action** is performed on it — give it a `hold` and a quick press means something else;
- alone, a quick press on a device nobody uses moves player 1 onto it;
- a player whose pad is pulled out is *lost* until it (or another pad) comes back: `deviceLost`, `deviceRegained`, `dropLost`.

The asset's `players` block sets the most players and the join actions.

## Rebinding

```dart
final result = await rebindPlayer(player, bindingId);   // listens, keeps, saves; swaps a clash
player.resetOverrides();
```

Rebinding hears the next control the moment it changes — it works while the game is paused — takes keys before any focused widget (so Escape and the arrows can be bound; Escape alone cancels), and ignores whatever was already held. Overrides are stored per player through an `InputOverrideStore`, apart from the asset. `RebindButton` and `RebindList` are ready-made widgets.

## On-screen controls

The asset's `onScreen` list places buttons and sticks (fixed, or floating under the thumb) relative to the screen. `OnScreenControls(input: input)` draws them and feeds `<OnScreen>/…` — they are controls like any other, bound in the same actions.

## Look

A camera that turns reads look **once per rendered frame**, not once per fixed step: `<Mouse>/delta` read per step judders when the frame rate and the step rate differ. Look comes as two actions, because a mouse held still turns nothing while a stick held still keeps turning:

```dart
final asset = LookActions.addTo(myAsset); // `look` (mouse) and `lookStick` (right stick)
final look = LookInput(input.actionsFor(0)!,
    settings: const LookSettings(radiansPerPixel: 0.0025, yawDegreesPerSecond: 180));

// Every rendered frame:
final turn = look.read(dt); // radians: dx yaw (right +), dy pitch (down +)
```

`FrameMotion` is the per-frame read underneath, for any movement action (a wheel zoom, say).

## Pointer lock

For mouse look, `input.pointerLock` hides the cursor, holds it in the window and streams the mouse's raw movement — never accelerated, never stopped by the edge of the screen — into the mouse, so the look actions read it like any other movement (the pointer events' own is ignored while it holds). A game that looks with the mouse asks for it on a click:

```dart
input.lockPointerOnClick = true; // GameWidget, and the editor's play-test
```

Escape lets go, whatever widget has the keyboard (`PointerLock.releaseKeys`), and so does the window going behind another; it takes hold again on the next click. Or call `input.pointerLock.lock()` and `unlock()` yourself. Windows today: elsewhere `isSupported` is false and nothing happens. Raw movement from anywhere else goes in through `input.attachRawMouse(deltas, relative:)`.

## The editor

The Input Actions editor is its own package, `just_input_editor`, the visual side of this one. It edits the asset this package runs: maps, actions and bindings; Pick, or Listen for the next key or button; interactions, processors, schemes and players; a keyboard, a gamepad and a phone to see and click bindings on; and a live test. Its module puts it in `just_game_engine_editor`.

A game imports `just_inputs.dart` (through `just_game_engine`), never `testing.dart` (`FakeGamepadSource`, `InputTester`) and never `just_input_editor`.
