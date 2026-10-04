import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/testing.dart';
import 'package:just_inputs/just_inputs.dart';

import 'sample_asset.dart';

void main() {
  group('binding text', () {
    const display = BindingDisplay();

    test('keys, composites, chords', () {
      final asset = sampleAsset();
      final move = asset.findAction('move')!.action;
      expect(display.binding(move.bindings.first), 'W/A/S/D');
      expect(display.control('<Keyboard>/space'), 'Space');
      expect(display.control('<Mouse>/leftButton'), 'LMB');
      expect(display.control('<Mouse>/scroll/up'), 'Wheel ↑');
      expect(display.control(''), '');
      expect(
        display.binding(
          const CompositeBindingDef(
            id: 'x',
            composite: CompositeKinds.oneModifier,
            parts: [
              CompositePartDef(
                id: 'y',
                part: 'modifier',
                path: '<Keyboard>/shift',
              ),
              CompositePartDef(id: 'z', part: 'binding', path: '<Keyboard>/e'),
            ],
          ),
        ),
        'Shift + E',
      );
    });

    test('overrides show through', () {
      final move = sampleAsset().findAction('move')!.action;
      expect(
        display.binding(move.bindings.first, {'b4': '<Keyboard>/upArrow'}),
        '↑/A/S/D',
      );
    });

    test('a key reads as it does on the player\'s own board, once pressed', () {
      final service = InputService();
      addTearDown(service.dispose);
      service.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyZ, // AZERTY
          timeStamp: Duration.zero,
        ),
      );
      expect(
        BindingDisplay(keyboard: service.keyboard).control('<Keyboard>/w'),
        'Z',
      );
      expect(
        BindingDisplay(keyboard: service.keyboard).control('<Keyboard>/a'),
        'A',
      );
    });

    test('pad glyphs follow the brand; a Switch Pro is mirrored', () {
      expect(GamepadGlyphs.label(gp.GamepadType.xbox, 'buttonSouth'), 'Ⓐ');
      expect(
        GamepadGlyphs.label(gp.GamepadType.playStation, 'buttonSouth'),
        '✕',
      );
      expect(
        GamepadGlyphs.label(gp.GamepadType.nintendoSwitchPro, 'buttonSouth'),
        'Ⓑ',
      );
      expect(
        GamepadGlyphs.label(gp.GamepadType.playStation, 'leftTrigger'),
        'L2',
      );
      expect(
        GamepadGlyphs.label(gp.GamepadType.xbox, 'leftStick/up'),
        'Left Stick ↑',
      );
      expect(GamepadGlyphs.label(gp.GamepadType.xbox, 'dpad'), 'D-Pad');
    });

    test('on-screen controls by their label', () {
      expect(
        BindingDisplay(asset: sampleAsset()).control('<OnScreen>/jump'),
        'JUMP',
      );
      expect(
        BindingDisplay(asset: sampleAsset()).control('<OnScreen>/moveStick'),
        'moveStick',
      );
    });

    test('an action, in the scheme in use', () {
      final service = InputService()..loadAsset(sampleAsset());
      addTearDown(service.dispose);
      final pad = service.createActions(group: 'Gamepad');
      expect(const BindingDisplay().action(pad, 'jump'), 'Ⓐ');
      expect(const BindingDisplay().action(service.actions, 'jump'), 'Space');
    });
  });

  group('on-screen controls', () {
    Future<InputService> pump(WidgetTester tester) async {
      final service = InputService()..loadAsset(sampleAsset());
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 400,
            child: OnScreenControls(
              input: service,
              visibility: OnScreenVisibility.always,
            ),
          ),
        ),
      );
      return service;
    }

    testWidgets('a button is held while a finger is on it', (tester) async {
      final service = await pump(tester);
      expect(find.text('JUMP'), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('JUMP')),
      );
      service.update(1);
      expect(service.actions.action('jump').isPressed(), isTrue);
      await gesture.up();
      service.update(2);
      expect(service.actions.action('jump').isPressed(), isFalse);
    });

    testWidgets('a floating stick appears under the thumb and steers', (
      tester,
    ) async {
      final service = await pump(tester);
      // The stick's region is the lower left: 0..0.5 across, 0.3..1 down.
      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(200, 0));
      service.update(1);
      expect(service.actions.action('move').readVector2(), const Offset(1, 0));
      await gesture.moveBy(const Offset(0, -100));
      service.update(2);
      expect(
        service.actions.action('move').readVector2().dy,
        0,
        reason: 'a horizontal stick',
      );
      await gesture.up();
      service.update(3);
      expect(service.actions.action('move').readVector2(), Offset.zero);
    });

    testWidgets('two thumbs: move and jump at once', (tester) async {
      final service = await pump(tester);
      final thumb = await tester.startGesture(
        const Offset(100, 300),
        pointer: 1,
      );
      await thumb.moveBy(const Offset(-200, 0));
      final other = await tester.startGesture(
        tester.getCenter(find.text('JUMP')),
        pointer: 2,
      );
      service.update(1);
      expect(service.actions.action('move').readVector2().dx, -1);
      expect(service.actions.action('jump').isPressed(), isTrue);
      await thumb.up();
      await other.up();
    });

    testWidgets('hidden off touch platforms unless asked', (tester) async {
      // Tests run as Android; this one is on a desktop.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final service = InputService()..loadAsset(sampleAsset());
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(home: OnScreenControls(input: service)),
      );
      expect(find.text('JUMP'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('rebinding on screen', () {
    testWidgets('press the button, press a key: bound, shown, saved', (
      tester,
    ) async {
      final service = InputService()..loadAsset(sampleAsset());
      addTearDown(service.dispose);
      service.players.start();
      InputTester(service).tap(PhysicalKeyboardKey.keyW);
      final p1 = service.players[0]!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RebindList(player: p1, maps: const ['player']),
          ),
        ),
      );
      final rows = rebindRows(p1, maps: const ['player']);
      expect(rows.map((r) => r.label), [
        'Move Up',
        'Move Down',
        'Move Left',
        'Move Right',
        'Jump',
      ]);
      expect(find.text('Space'), findsOneWidget);

      await tester.tap(find.text('Space'));
      await tester.pump();
      expect(find.text('Press a key… (Esc cancels)'), findsOneWidget);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyJ,
        physicalKey: PhysicalKeyboardKey.keyJ,
      );
      await tester.pumpAndSettle();
      expect(find.text('J'), findsOneWidget);
      expect(p1.overrides['b11'], '<Keyboard>/j');
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyJ,
        physicalKey: PhysicalKeyboardKey.keyJ,
      );

      // Back to the default.
      await tester.tap(find.byTooltip('Default').last);
      await tester.pumpAndSettle();
      expect(find.text('Space'), findsOneWidget);
      expect(p1.overrides.isEmpty, isTrue);
    });

    testWidgets('Escape while listening leaves the binding as it was', (
      tester,
    ) async {
      final service = InputService()..loadAsset(sampleAsset());
      addTearDown(service.dispose);
      service.players.start();
      InputTester(service).tap(PhysicalKeyboardKey.keyW);
      final p1 = service.players[0]!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RebindButton(player: p1, bindingId: 'b11'),
          ),
        ),
      );
      await tester.tap(find.text('Space'));
      await tester.pump();
      await tester.sendKeyEvent(
        LogicalKeyboardKey.escape,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pumpAndSettle();
      expect(find.text('Space'), findsOneWidget);
      expect(p1.overrides.isEmpty, isTrue);
    });

    testWidgets('a mouse button, caught over everything', (tester) async {
      final service = InputService()..loadAsset(sampleAsset());
      addTearDown(service.dispose);
      service.players.start();
      InputTester(service).tap(PhysicalKeyboardKey.keyW);
      final p1 = service.players[0]!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RebindButton(player: p1, bindingId: 'b11'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Space'));
      await tester.pump();
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.down(const Offset(10, 10));
      await tester.pumpAndSettle();
      await mouse.up();
      expect(p1.overrides['b11'], '<Mouse>/rightButton');
      expect(find.text('RMB'), findsOneWidget);
    });
  });
}
