import 'package:flutter/services.dart';

/// Shared (de)serialization for `List<LogicalKeyboardKey>` fields, used by
/// both [InputBinding] and `Vector2Binding` — pulled out to a standalone,
/// non-underscore file since Dart privacy is per-file: a leading-underscore
/// helper declared alongside one of those classes wouldn't be reachable from
/// the other's file.
List<LogicalKeyboardKey> parseKeyList(List<dynamic>? raw) {
  if (raw == null) return const [];
  return raw.map((id) {
    final keyId = (id as num).toInt();
    return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
  }).toList();
}

List<int> keyListToJson(List<LogicalKeyboardKey> keys) =>
    keys.map((key) => key.keyId).toList();
