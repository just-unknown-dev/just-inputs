// Native (dart:io) implementation of the thin file-IO helper used by
// InputActionResolver.loadFromProjectFile. Selected by the conditional
// import in input_action_resolver.dart on every platform except web.
import 'dart:io';

/// Read the contents of the file at [path], relative to the current
/// working directory.
String readFile(String path) =>
    File('${Directory.current.path}/$path').readAsStringSync();
