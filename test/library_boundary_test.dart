// A game imports `just_inputs.dart` and ships it, on every platform, the web
// included. This walks every import the runtime library reaches. The editor
// is not here at all: it is just_input_editor, the visual side.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Every file under lib/ reachable from [entry] by relative paths and
/// `package:just_inputs/` ones, plus every other URI met on the way.
(Set<String>, Set<String>) reachable(String entry) {
  final seen = <String>{};
  final others = <String>{};
  void visit(File file) {
    final path = file.absolute.uri.normalizePath().toFilePath();
    if (!seen.add(path)) return;
    for (final m in _directive.allMatches(file.readAsStringSync())) {
      final uri = m.group(1)!;
      File? next;
      if (uri.startsWith('package:just_inputs/')) {
        next = File('lib/${uri.substring('package:just_inputs/'.length)}');
      } else if (uri.contains(':')) {
        others.add(uri);
      } else {
        next = File.fromUri(file.absolute.uri.resolve(uri));
      }
      if (next != null && next.existsSync()) visit(next);
    }
  }

  visit(File(entry));
  return (seen, others);
}

void main() {
  test('the runtime library never reaches the test helpers', () {
    final (files, _) = reachable('lib/just_inputs.dart');
    expect(files.where((f) => f.endsWith('testing.dart')), isEmpty);
    expect(files.length, greaterThan(20), reason: 'the walk itself works');
  });

  test('nor dart:io, so it runs on the web', () {
    final (_, others) = reachable('lib/just_inputs.dart');
    expect(
      others,
      contains('package:flutter/services.dart'),
      reason: 'the walk sees other packages',
    );
    expect(others, isNot(contains('dart:io')));
  });
}
