// A dot moved by the `player/move` action and bounced by `player/jump`:
// arrow keys, WASD or a gamepad's left stick move it; Space or the pad's
// south button jumps. The same actions read the same way whatever the device.
//
// To run it, make a Flutter app that depends on just_inputs and put this
// file in its lib/main.dart.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_inputs/just_inputs.dart';

void main() => runApp(const MaterialApp(home: InputDemo()));

/// The input asset: usually a `.input.json` file in the app's assets, made
/// with the Input Actions editor.
const inputAsset = '''
{
  "format": "just_inputs",
  "version": 3,
  "nextId": 14,
  "maps": [
    {
      "id": "m1",
      "name": "player",
      "actions": [
        {
          "id": "a1",
          "name": "move",
          "type": "vector2",
          "bindings": [
            {"id": "b1", "composite": "2DVector", "parts": [
              {"id": "b2", "part": "up", "path": "<Keyboard>/w"},
              {"id": "b3", "part": "down", "path": "<Keyboard>/s"},
              {"id": "b4", "part": "left", "path": "<Keyboard>/a"},
              {"id": "b5", "part": "right", "path": "<Keyboard>/d"}
            ]},
            {"id": "b6", "composite": "2DVector", "parts": [
              {"id": "b7", "part": "up", "path": "<Keyboard>/upArrow"},
              {"id": "b8", "part": "down", "path": "<Keyboard>/downArrow"},
              {"id": "b9", "part": "left", "path": "<Keyboard>/leftArrow"},
              {"id": "b10", "part": "right", "path": "<Keyboard>/rightArrow"}
            ]},
            {"id": "b11", "path": "<Gamepad>/leftStick"}
          ]
        },
        {
          "id": "a2",
          "name": "jump",
          "type": "button",
          "bindings": [
            {"id": "b12", "path": "<Keyboard>/space"},
            {"id": "b13", "path": "<Gamepad>/buttonSouth"}
          ]
        }
      ]
    }
  ]
}
''';

/// Shows the dot and drives the input once a frame.
class InputDemo extends StatefulWidget {
  const InputDemo({super.key});

  @override
  State<InputDemo> createState() => _InputDemoState();
}

class _InputDemoState extends State<InputDemo>
    with SingleTickerProviderStateMixin {
  final input = InputService()..loadAsset(InputActionAsset.parse(inputAsset));
  late final Ticker _ticker = createTicker(_tick);

  Offset _position = Offset.zero;
  double _bounce = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    input.attachGamepads(); // no pads is fine
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Every event since the last update is replayed now, in order, on this
    // clock — never the wall clock.
    input.update(elapsed.inMicroseconds / 1e6);

    final move = input.actions.action('player/move').readVector2(); // y down
    if (input.actions.action('player/jump').wasPressedThisFrame()) {
      _bounce = 1;
    }
    setState(() {
      _position += move * 240 * dt;
      _bounce = (_bounce - dt * 3).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      // Keys go to the input service; it keeps them, so nothing else reacts.
      onKeyEvent: (_, event) {
        input.handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: ColoredBox(
        color: const Color(0xFF14161C),
        child: Center(
          child: Transform.translate(
            offset: _position,
            child: Transform.scale(
              scale: 1 + _bounce * 0.5,
              child: const SizedBox.square(
                dimension: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF4FC3F7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
