// libolivecore string parsers for user-typed and project-stored times: Timecode::timecode_to_time
// (drop/non-drop timecode, seconds, frames, milliseconds) and rational::fromString, plus a
// round-trip through time_to_timecode. Byte 0 picks the display mode, byte 1 the timebase.
#include <cstdint>
#include <string>

#include <olive/core/core.h>

using olive::core::rational;
using olive::core::Timecode;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 2) return -1;
  static const rational kTimebases[] = {
    rational(1001, 30000), rational(1001, 60000), rational(1, 24), rational(1001, 24000),
    rational(1, 25), rational(1, 30), rational(1, 50), rational(1, 60),
    rational(1, 48000), rational(1, 44100), rational(1, 1000), rational(1, 1)};
  Timecode::Display display = Timecode::Display(data[0] % 5);
  const rational &tb = kTimebases[data[1] % (sizeof(kTimebases) / sizeof(kTimebases[0]))];
  std::string s(reinterpret_cast<const char *>(data + 2), size - 2);

  bool ok = false;
  rational t = Timecode::timecode_to_time(s, tb, display, &ok);
  if (ok) {
    std::string back = Timecode::time_to_timecode(t, tb, display, true);
    (void)back;
  }
  bool ok2 = false;
  rational r = rational::fromString(s, &ok2);
  if (ok2) {
    std::string str = r.toString();
    (void)str;
  }
  return 0;
}
