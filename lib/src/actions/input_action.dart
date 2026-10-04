import 'input_binding.dart';
import 'vector2_binding.dart';

/// Whether an action resolves to a discrete on/off signal ([button]) or a
/// continuous 2D direction ([vector2], e.g. movement) — mirrors Unity's
/// Input System "Action Type" (Button vs. Value/Vector2) distinction.
enum ActionType { button, vector2 }

/// One action's full definition — which action map it belongs to (by id —
/// games define their own map ids, this package stays agnostic of what they
/// mean), its [type], and the binding shape matching that type.
///
/// [button]/[vector2] both always exist regardless of [type] (only the one
/// matching [type] is meaningful) — a plain tagged-union-via-unused-sibling-
/// field, chosen over a sealed-class visitor for simpler JSON
/// (de)serialization.
class InputAction {
  const InputAction({
    required this.mapId,
    this.type = ActionType.button,
    this.button = const InputBinding(),
    this.vector2 = const Vector2Binding(),
  });

  final String mapId;
  final ActionType type;

  /// Meaningful iff [type] is [ActionType.button].
  final InputBinding button;

  /// Meaningful iff [type] is [ActionType.vector2].
  final Vector2Binding vector2;

  Map<String, dynamic> toJson() => {
    'mapId': mapId,
    'type': type.name,
    'button': button.toJson(),
    'vector2': vector2.toJson(),
  };

  factory InputAction.fromJson(Map<String, dynamic> json) {
    final rawButton = json['button'] as Map<String, dynamic>?;
    final rawVector2 = json['vector2'] as Map<String, dynamic>?;
    return InputAction(
      mapId: json['mapId'] as String? ?? '',
      type: ActionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => ActionType.button,
      ),
      button: rawButton == null
          ? const InputBinding()
          : InputBinding.fromJson(rawButton),
      vector2: rawVector2 == null
          ? const Vector2Binding()
          : Vector2Binding.fromJson(rawVector2),
    );
  }
}
