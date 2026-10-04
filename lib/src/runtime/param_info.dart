/// What kind of setting a [ParamInfo] is.
enum ParamKind { number, flag, choice }

/// One setting of an interaction, processor or composite — what the editor
/// draws a field for.
final class ParamInfo {
  const ParamInfo.number(
    this.name,
    this.label, {
    this.defaultValue,
    this.min,
    this.max,
    this.step = 0.05,
    this.fromSettings,
  }) : kind = ParamKind.number,
       choices = const [];

  const ParamInfo.flag(this.name, this.label, {bool this.defaultValue = false})
    : kind = ParamKind.flag,
      choices = const [],
      min = null,
      max = null,
      step = 0,
      fromSettings = null;

  const ParamInfo.choice(
    this.name,
    this.label,
    this.choices, {
    String? this.defaultValue,
  }) : kind = ParamKind.choice,
       min = null,
       max = null,
       step = 0,
       fromSettings = null;

  final String name;
  final String label;
  final ParamKind kind;

  /// What an unset value means. Null for a number whose default is one of
  /// the asset's settings ([fromSettings]).
  final Object? defaultValue;

  final double? min;
  final double? max;
  final double step;

  /// For a [ParamKind.choice].
  final List<String> choices;

  /// The asset setting an unset value falls back on, named for the editor:
  /// "Hold time (asset)".
  final String? fromSettings;
}

/// What the editor lists for a registered step.
final class StepInfo {
  const StepInfo(this.type, this.label, this.params, {this.description = ''});

  final String type;
  final String label;
  final List<ParamInfo> params;
  final String description;
}
