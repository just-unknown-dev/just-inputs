import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/just_inputs.dart';

class _FakeBackend implements gp.GamepadBackend {
  final _connections = StreamController<gp.GamepadConnectionEvent>.broadcast();
  final _stateChanges = StreamController<gp.GamepadStateEvent>.broadcast();
  final Map<String, gp.GamepadInfo> _connected = {};

  @override
  Future<void> start() async {}

  @override
  List<gp.GamepadInfo> get connected => List.unmodifiable(_connected.values);

  @override
  Stream<gp.GamepadConnectionEvent> get connections => _connections.stream;

  @override
  Stream<gp.GamepadStateEvent> get stateChanges => _stateChanges.stream;

  void connect(String id, {gp.GamepadType type = gp.GamepadType.xbox}) {
    final info = gp.GamepadInfo(id: id, name: id, type: type);
    _connected[id] = info;
    _connections.add(gp.GamepadConnectionEvent(info: info, connected: true));
  }

  void disconnect(String id) {
    final info = _connected.remove(id)!;
    _connections.add(gp.GamepadConnectionEvent(info: info, connected: false));
  }

  void pushState(String id, gp.GamepadState state) {
    _stateChanges.add(gp.GamepadStateEvent(gamepadId: id, state: state));
  }

  @override
  void dispose() {
    _connections.close();
    _stateChanges.close();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeBackend backend;
  late gp.GamepadManager manager;
  late InputManager input;

  setUp(() {
    backend = _FakeBackend();
    manager = gp.GamepadManager(backend: backend);
    input = InputManager()..initialize();
    input.attachGamepads(manager: manager);
  });

  tearDown(() {
    input.dispose();
    manager.dispose();
  });

  test('forwards axes and buttons from the active controller', () async {
    backend.connect('a');
    backend.pushState(
      'a',
      gp.GamepadState(
        axes: {gp.GamepadAxis.leftStickX: 0.9},
        buttonsDown: {gp.GamepadButton.a},
      ),
    );
    await flush();

    expect(input.controller.getAxis(GamepadAxis.leftStickX), 0.9);
    expect(input.controller.isButtonDown(GamepadButton.a), isTrue);
  });

  test('sets activeGamepadType/Name once a controller produces real input', () async {
    expect(input.controller.isConnected, isFalse);

    backend.connect('a', type: gp.GamepadType.playStation);
    backend.pushState('a', gp.GamepadState(buttonsDown: {gp.GamepadButton.a}));
    await flush();

    expect(input.controller.activeGamepadType, gp.GamepadType.playStation);
    expect(input.controller.activeGamepadName, 'a');
    expect(input.controller.isConnected, isTrue);
  });

  test('clears stale state when the active controller disconnects', () async {
    backend.connect('a');
    backend.pushState('a', gp.GamepadState(buttonsDown: {gp.GamepadButton.a}));
    await flush();
    expect(input.controller.isButtonDown(GamepadButton.a), isTrue);

    backend.disconnect('a');
    await flush();

    expect(input.controller.isButtonDown(GamepadButton.a), isFalse);
    expect(input.controller.isConnected, isFalse);
  });

  test('clears stale state when active focus switches to a different pad', () async {
    backend.connect('a');
    backend.pushState('a', gp.GamepadState(buttonsDown: {gp.GamepadButton.a}));
    await flush();

    backend.connect('b');
    backend.pushState('b', gp.GamepadState(buttonsDown: {gp.GamepadButton.b}));
    await flush();

    expect(input.controller.isButtonDown(GamepadButton.a), isFalse);
    expect(input.controller.isButtonDown(GamepadButton.b), isTrue);
  });
}
