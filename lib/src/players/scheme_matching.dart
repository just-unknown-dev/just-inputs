import '../devices/input_device.dart';
import '../model/input_action_asset.dart';
import '../model/scheme_def.dart';

/// What a device brings when someone plays with it: the scheme it belongs
/// to and the other devices that go with it — the mouse with the keyboard,
/// the touch screen with the on-screen controls.
final class SchemeMatch {
  const SchemeMatch(this.scheme, this.devices);

  /// Null when the asset has no scheme the device fits: every binding
  /// counts.
  final ControlSchemeDef? scheme;

  final List<InputDevice> devices;
}

/// The first scheme in [asset] that uses [device]'s layout, with [device]
/// and whichever of [available] the scheme also wants (one per layout).
SchemeMatch matchScheme(
  InputActionAsset asset,
  InputDevice device,
  Iterable<InputDevice> available,
) {
  for (final scheme in asset.schemes) {
    if (!scheme.layouts.contains(device.layout)) continue;
    final devices = [device];
    for (final layout in scheme.layouts) {
      if (layout == device.layout) continue;
      for (final other in available) {
        if (other.layout == layout && !devices.contains(other)) {
          devices.add(other);
          break;
        }
      }
    }
    return SchemeMatch(scheme, devices);
  }
  return SchemeMatch(null, [device]);
}
