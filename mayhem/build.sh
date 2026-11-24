#!/usr/bin/env bash
#
# mayhem/build.sh — olive: the sanitized fuzz harnesses (build-fuzz/) and upstream's unit tests
# (build-tests/, normal flags). Both CMake trees live under the gitignored /build* pattern.
# Dependencies all come from the image: Qt5/OCIO/OIIO/OpenEXR/PortAudio from apt, FFmpeg 6.1
# (olive still uses the pre-7.0 channel-layout API; Debian trixie ships 7.1) prebuilt static under
# /opt/toolchains/deps/ffmpeg-6.1.2, and the ext/core + ext/KDDockWidgets submodules in the tree.
set -euo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${SRC:=/mayhem}"
: "${FFMPEG_ROOT:=/opt/toolchains/deps/ffmpeg-6.1.2}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
for d in ext/core/CMakeLists.txt ext/KDDockWidgets/CMakeLists.txt; do
  [ -f "$d" ] || { echo "missing $d: check out the git submodules (submodules: recursive)" >&2; exit 1; }
done

# FFmpeg is static: give CMake each component explicitly, and append the archives in dependency
# order (plus their system libs) to every link line. --exclude-libs keeps the static FFmpeg symbols
# out of the dynamic symbol table so apt's OpenImageIO keeps binding to its own libav*.so.
FF_ARGS=(-DFFMPEG_ROOT="$FFMPEG_ROOT")
for c in avutil avcodec avformat avfilter swscale swresample; do
  FF_ARGS+=(-DFFMPEG_${c}_INCLUDE_DIR="$FFMPEG_ROOT/include" -DFFMPEG_${c}_LIBRARY="$FFMPEG_ROOT/lib/lib${c}.a")
done
FF_LINK="-Wl,--exclude-libs,libavfilter.a:libavformat.a:libavcodec.a:libswscale.a:libswresample.a:libavutil.a"
for c in avfilter avformat avcodec swscale swresample avutil; do FF_LINK+=" $FFMPEG_ROOT/lib/lib${c}.a"; done
FF_LINK+=" -lz -lm -lpthread"
# ext/core's own test targets include libavutil headers without its include dir.
FF_INC="-isystem $FFMPEG_ROOT/include"

# 1) Upstream unit tests (tests/ via BUILD_TESTS, ext/core via OLIVECORE_BUILD_TESTS), normal flags.
cmake -S . -B build-tests -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=ON -DOLIVECORE_BUILD_TESTS=ON \
  -DCMAKE_C_FLAGS="$FF_INC $COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$FF_INC $COVERAGE_FLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS" \
  -DCMAKE_CXX_STANDARD_LIBRARIES="$FF_LINK" "${FF_ARGS[@]}"
cmake --build build-tests -j"$MAYHEM_JOBS" --target \
  common-tests timeline-tests compositing-tests rational-test stringutils-test timecode-test timerange-test

# 2) Fuzz harnesses: the whole project instrumented (sanitizers + SanCov + DWARF 3).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$SRC/build-standalone-main.o"
# LeakSanitizer off for every fuzz + standalone binary (Qt and static singletons leak by design).
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$SRC/build-lsan-off.o"
FUZZ_FLAGS="$FF_INC $SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS"
cmake -S . -B build-fuzz -G Ninja -DCMAKE_BUILD_TYPE=Debug -DOLIVECORE_BUILD_TESTS=OFF \
  -DCMAKE_PROJECT_INCLUDE="$SRC/mayhem/fuzz_inject.cmake" \
  -DOLIVE_FUZZ_STANDALONE_OBJ="$SRC/build-standalone-main.o" -DOLIVE_FUZZ_LSAN_OBJ="$SRC/build-lsan-off.o" \
  -DCMAKE_C_FLAGS_DEBUG="-O1" -DCMAKE_CXX_FLAGS_DEBUG="-O1" \
  -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS" \
  -DCMAKE_CXX_STANDARD_LIBRARIES="$FF_LINK" "${FF_ARGS[@]}"
TARGETS=(fuzz_project_load fuzz_paste fuzz_html fuzz_timecode)
build_list=()
for t in "${TARGETS[@]}"; do build_list+=("$t" "$t-standalone"); done
cmake --build build-fuzz -j"$MAYHEM_JOBS" --target "${build_list[@]}"
for t in "${TARGETS[@]}"; do
  cp -f "build-fuzz/fuzz/$t" "build-fuzz/fuzz/$t-standalone" "$SRC/"
done
