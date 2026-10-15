#include "pointer_lock_plugin.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <vector>

namespace just_inputs {

namespace {

// HID usage page and usage of a mouse, for RegisterRawInputDevices.
constexpr USHORT kUsagePageGeneric = 0x01;
constexpr USHORT kUsageMouse = 0x02;

// The timer that sends movement held back while more raw input was queued,
// should that input turn out not to be ours. "JPL".
constexpr UINT_PTR kFlushTimerId = 0x4A504C;

constexpr ULONGLONG kClipCheckMs = 250;

}  // namespace

// static
void PointerLockPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<PointerLockPlugin>(registrar);
  PointerLockPlugin* self = plugin.get();

  self->methods_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "just_inputs/pointer_lock",
          &flutter::StandardMethodCodec::GetInstance());
  self->methods_->SetMethodCallHandler(
      [self](const auto& call, auto result) {
        self->HandleMethodCall(call, std::move(result));
      });

  self->events_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "just_inputs/pointer_lock/events",
          &flutter::StandardMethodCodec::GetInstance());
  self->events_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [self](const flutter::EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            // A new listener (a hot restart's Dart side) knows nothing of a
            // lock asked for before it, and could never let it go.
            self->Unlock();
            self->sink_ = std::move(events);
            return nullptr;
          },
          [self](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            // Nobody hears the movement any more: let go.
            self->Unlock();
            self->sink_ = nullptr;
            return nullptr;
          }));

  self->window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [self](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return self->HandleWindowMessage(hwnd, message, wparam, lparam);
      });

  registrar->AddPlugin(std::move(plugin));
}

PointerLockPlugin::PointerLockPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

PointerLockPlugin::~PointerLockPlugin() {
  // The engine is going: give the cursor back, and tell nobody.
  sink_ = nullptr;
  requested_ = false;
  Release();
  if (flush_scheduled_) {
    KillTimer(Window(), kFlushTimerId);
    flush_scheduled_ = false;
  }
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
}

void PointerLockPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "lock") {
    bool pin = true;
    if (const auto* args =
            std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      const auto found = args->find(flutter::EncodableValue("pinToCentre"));
      if (found != args->end()) {
        if (const bool* value = std::get_if<bool>(&found->second)) {
          pin = *value;
        }
      }
    }
    if (!Window()) {
      result->Error("no_window",
                    "There is no window to lock the pointer to.");
      return;
    }
    requested_ = true;
    const bool repin = engaged_ && pin != pin_to_centre_;
    pin_to_centre_ = pin;
    if (repin) ApplyClip();
    Engage(false);
    result->Success(flutter::EncodableValue(engaged_));
  } else if (method == "unlock") {
    Unlock();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

std::optional<LRESULT> PointerLockPlugin::HandleWindowMessage(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_INPUT:
      if (engaged_) OnRawInput(reinterpret_cast<HRAWINPUT>(lparam));
      // DefWindowProc still has to run, to clean up after the input.
      return std::nullopt;
    case WM_TIMER:
      if (wparam == kFlushTimerId) {
        Flush();
        return 0;
      }
      return std::nullopt;
    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        Release();
      } else if (requested_ && HIWORD(wparam) == 0) {
        // Activated and not minimised. (Restored from the taskbar, it is
        // still minimised here; WM_SIZE takes hold once it is not.)
        Engage(true);
      }
      return std::nullopt;
    case WM_ACTIVATEAPP:
      if (!wparam) Release();
      return std::nullopt;
    case WM_ENTERSIZEMOVE:
      moving_ = true;
      Release();
      return std::nullopt;
    case WM_EXITSIZEMOVE:
      moving_ = false;
      if (requested_) Engage(false);
      return std::nullopt;
    case WM_SIZE:
      if (wparam == SIZE_MINIMIZED) {
        Release();
      } else if (engaged_) {
        ApplyClip();
      } else if (requested_) {
        Engage(false);
      }
      return std::nullopt;
    case WM_MOVE:
    case WM_DISPLAYCHANGE:
    case WM_DPICHANGED:
      if (engaged_) ApplyClip();
      return std::nullopt;
    case WM_DESTROY:
      requested_ = false;
      Release();
      return std::nullopt;
  }
  return std::nullopt;
}

HWND PointerLockPlugin::Window() const {
  flutter::FlutterView* view = registrar_->GetView();
  if (!view) return nullptr;
  HWND child = view->GetNativeWindow();
  if (!child) return nullptr;
  // The runner puts the view in its window after plugins register, so this
  // is asked each time rather than kept.
  HWND root = GetAncestor(child, GA_ROOT);
  return root != child ? root : nullptr;
}

bool PointerLockPlugin::Engage(bool activating) {
  if (engaged_) return true;
  if (!requested_ || moving_) return false;
  HWND window = Window();
  if (!window || IsIconic(window)) return false;
  if (!activating && GetForegroundWindow() != window) return false;

  // No RIDEV_NOLEGACY: Flutter still gets its clicks. No RIDEV_INPUTSINK:
  // the lock is only for the window in front.
  RAWINPUTDEVICE device = {kUsagePageGeneric, kUsageMouse, 0, window};
  if (!RegisterRawInputDevices(&device, 1, sizeof(device))) return false;

  engaged_ = true;
  motion_.Reset();
  // The cursor shows while its display count is at least zero.
  ShowCursor(FALSE);
  last_clip_check_ = 0;
  ApplyClip();
  SendState(true);
  return true;
}

void PointerLockPlugin::Release() {
  if (!engaged_) return;
  Flush();
  engaged_ = false;
  ClipCursor(nullptr);
  clip_ = RECT{0, 0, 0, 0};
  ShowCursor(TRUE);
  RAWINPUTDEVICE device = {kUsagePageGeneric, kUsageMouse, RIDEV_REMOVE,
                           nullptr};
  RegisterRawInputDevices(&device, 1, sizeof(device));
  SendState(false);
}

void PointerLockPlugin::Unlock() {
  requested_ = false;
  Release();
}

void PointerLockPlugin::ApplyClip() {
  HWND window = Window();
  if (!window) return;
  RECT client;
  if (!GetClientRect(window, &client)) return;
  // Client to screen coordinates, both corners at once.
  MapWindowPoints(window, nullptr, reinterpret_cast<POINT*>(&client), 2);
  const RECT clip = pin_to_centre_ ? CentreClip(client) : client;
  if (IsEmptyClip(clip)) return;
  if (pin_to_centre_) {
    SetCursorPos(clip.left + 1, clip.top + 1);
  }
  clip_ = clip;
  ClipCursor(&clip_);
}

void PointerLockPlugin::KeepClip() {
  const ULONGLONG now = GetTickCount64();
  if (now - last_clip_check_ < kClipCheckMs) return;
  last_clip_check_ = now;
  if (IsEmptyClip(clip_)) return;
  RECT current;
  if (GetClipCursor(&current) && !EqualRect(&current, &clip_)) {
    ClipCursor(&clip_);
  }
}

void PointerLockPlugin::OnRawInput(HRAWINPUT handle) {
  RAWINPUT input;
  UINT size = sizeof(input);
  if (GetRawInputData(handle, RID_INPUT, &input, &size,
                      sizeof(RAWINPUTHEADER)) == static_cast<UINT>(-1)) {
    return;
  }
  if (input.header.dwType != RIM_TYPEMOUSE) return;

  const RAWMOUSE& mouse = input.data.mouse;
  if (mouse.usFlags & MOUSE_MOVE_ABSOLUTE) {
    const bool desktop = (mouse.usFlags & MOUSE_VIRTUAL_DESKTOP) != 0;
    const int width =
        GetSystemMetrics(desktop ? SM_CXVIRTUALSCREEN : SM_CXSCREEN);
    const int height =
        GetSystemMetrics(desktop ? SM_CYVIRTUALSCREEN : SM_CYSCREEN);
    motion_.AddAbsolute(AbsoluteToPixels(mouse.lLastX, width),
                        AbsoluteToPixels(mouse.lLastY, height));
  } else {
    motion_.AddRelative(mouse.lLastX, mouse.lLastY);
  }
  KeepClip();

  // More raw input already queued (a busy frame, a fast mouse): let it join
  // this movement and go as one message. The timer sends it anyway should
  // that input be someone else's.
  if (HIWORD(GetQueueStatus(QS_RAWINPUT)) & QS_RAWINPUT) {
    ScheduleFlush();
  } else {
    Flush();
  }
}

void PointerLockPlugin::ScheduleFlush() {
  if (flush_scheduled_) return;
  HWND window = Window();
  if (!window) return;
  flush_scheduled_ = SetTimer(window, kFlushTimerId, USER_TIMER_MINIMUM,
                              nullptr) != 0;
}

void PointerLockPlugin::Flush() {
  if (flush_scheduled_) {
    KillTimer(Window(), kFlushTimerId);
    flush_scheduled_ = false;
  }
  double dx = 0;
  double dy = 0;
  if (!motion_.Take(&dx, &dy)) return;
  if (sink_) sink_->Success(flutter::EncodableValue(std::vector<double>{dx, dy}));
}

void PointerLockPlugin::SendState(bool locked) {
  if (sink_) sink_->Success(flutter::EncodableValue(locked));
}

}  // namespace just_inputs
