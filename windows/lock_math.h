#ifndef FLUTTER_PLUGIN_JUST_INPUTS_LOCK_MATH_H_
#define FLUTTER_PLUGIN_JUST_INPUTS_LOCK_MATH_H_

// The plugin's arithmetic, apart from any window so it can be unit tested:
// adding up raw mouse movement, and where a pinned cursor is held.

#include <windows.h>

namespace just_inputs {

// An absolute raw-input coordinate (0 to 65535 across the screen) in pixels
// of a screen |extent| pixels across.
inline double AbsoluteToPixels(LONG value, int extent) {
  return static_cast<double>(value) * extent / 65535.0;
}

// The box a pinned cursor is held in: 2x2 pixels at the centre of |client|
// (screen coordinates), as SDL's relative mouse mode does. An empty |client|
// (a minimised window) gives an empty box.
inline RECT CentreClip(const RECT& client) {
  if (client.right <= client.left || client.bottom <= client.top) {
    return RECT{0, 0, 0, 0};
  }
  const LONG x = client.left + (client.right - client.left) / 2;
  const LONG y = client.top + (client.bottom - client.top) / 2;
  return RECT{x - 1, y - 1, x + 1, y + 1};
}

inline bool IsEmptyClip(const RECT& rect) {
  return rect.right <= rect.left || rect.bottom <= rect.top;
}

// Raw mouse movement added up between two sends.
//
// Most mice report relative movement in device counts. Some sources report
// absolute positions instead (remote desktop, virtual machines, pen
// tablets): their movement is the difference from the last position, so the
// first one after a Reset only sets where they start.
class MotionAccumulator {
 public:
  void AddRelative(LONG dx, LONG dy) {
    dx_ += dx;
    dy_ += dy;
  }

  void AddAbsolute(double x, double y) {
    if (has_last_) {
      dx_ += x - last_x_;
      dy_ += y - last_y_;
    }
    last_x_ = x;
    last_y_ = y;
    has_last_ = true;
  }

  bool IsEmpty() const { return dx_ == 0 && dy_ == 0; }

  // Hands over what was added up and starts again from zero. False when
  // there was nothing.
  bool Take(double* dx, double* dy) {
    if (IsEmpty()) return false;
    *dx = dx_;
    *dy = dy_;
    dx_ = 0;
    dy_ = 0;
    return true;
  }

  // Drops what was added up, and where an absolute source last was.
  void Reset() {
    dx_ = 0;
    dy_ = 0;
    has_last_ = false;
  }

 private:
  double dx_ = 0;
  double dy_ = 0;
  bool has_last_ = false;
  double last_x_ = 0;
  double last_y_ = 0;
};

}  // namespace just_inputs

#endif  // FLUTTER_PLUGIN_JUST_INPUTS_LOCK_MATH_H_
