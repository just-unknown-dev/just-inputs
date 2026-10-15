// The example's input asset is valid, and its actions answer the keys it
// says they do.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';
import 'package:just_inputs/testing.dart';

import '../example/example.dart' as example;

void main() {
  test('the example asset is valid', () {
    final asset = InputActionAsset.parse(example.inputAsset);
    final errors = validateAsset(
      asset,
    ).where((issue) => issue.severity == IssueSeverity.error);
    expect(errors, isEmpty);
  });

  test('D moves it right and Space jumps', () {
    final service = InputService()
      ..loadAsset(InputActionAsset.parse(example.inputAsset));
    addTearDown(service.dispose);
    final tester = InputTester(service);
    tester
      ..keyDown(PhysicalKeyboardKey.keyD)
      ..keyDown(PhysicalKeyboardKey.space)
      ..step();
    expect(
      service.actions.action('player/move').readVector2(),
      const Offset(1, 0),
    );
    expect(service.actions.action('player/jump').wasPressedThisFrame(), isTrue);
  });
}
