#ifndef FLUTTER_PLUGIN_JUST_INPUTS_PLUGIN_H_
#define FLUTTER_PLUGIN_JUST_INPUTS_PLUGIN_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

#include "lock_math.h"

namespace just_inputs {

// Pointer lock for the window hosting Flutter.
//
// While the lock holds ("engaged"), the plugin:
// - registers for raw mouse input (WM_INPUT) on the top-level window, and
//   sends the movement to Dart on `just_inputs/pointer_lock/events` as
//   `[dx, dy]` (a Float64List), coalescing whatever raw input has piled up;
// - hides the cursor (ShowCursor) and holds it with ClipCursor, either in a
//   2x2 box at the centre of the window or anywhere in its client area.
//
// The lock is *requested* by Dart (`lock`/`unlock` on `just_inputs/pointer_lock`)
// and *engaged* only while the window is in front: it lets go when the
// window is deactivated, minimised or being moved or sized, and engages
// again when the window comes back, for as long as it is requested. Each
// change is sent to Dart as a bool.
//
// Everything runs on the platform thread: the method channel, the event
// sink and the window procedure delegate all do.
class PointerLockPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit PointerLockPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~PointerLockPlugin();

  PointerLockPlugin(const PointerLockPlugin&) = delete;
  PointerLockPlugin& operator=(const PointerLockPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Sees every message to the top-level window before the runner does.
  // Never claims one except its own flush timer.
  std::optional<LRESULT> HandleWindowMessage(HWND hwnd, UINT message,
                                             WPARAM wparam, LPARAM lparam);

  // The top-level window hosting the Flutter view, or null before the view
  // has been placed in one (or when there is no view).
  HWND Window() const;

  // Takes hold if requested and possible. |activating| skips the
  // foreground check, for WM_ACTIVATE, which arrives while the window is
  // only becoming the foreground one.
  bool Engage(bool activating);

  // Lets go, keeping the request. Sends what moved before it did.
  void Release();

  // Stops requesting, and lets go.
  void Unlock();

  // Holds the cursor where the lock wants it, from the window's current
  // place and size.
  void ApplyClip();

  // Puts the clip back if something else changed it (a UAC prompt,
  // Ctrl+Alt+Del, another app). Checked at most every 250 ms.
  void KeepClip();

  void OnRawInput(HRAWINPUT handle);
  void ScheduleFlush();
  void Flush();
  void SendState(bool locked);

  flutter::PluginRegistrarWindows* registrar_;
  int window_proc_id_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;

  bool requested_ = false;
  bool pin_to_centre_ = true;
  bool engaged_ = false;
  // Inside a move or size loop: the user is dragging the window's frame.
  bool moving_ = false;
  bool flush_scheduled_ = false;

  RECT clip_ = {0, 0, 0, 0};
  ULONGLONG last_clip_check_ = 0;
  MotionAccumulator motion_;
};

}  // namespace just_inputs

#endif  // FLUTTER_PLUGIN_JUST_INPUTS_PLUGIN_H_
