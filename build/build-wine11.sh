#!/bin/bash
# build-wine11.sh — сборка Wine 11.22 armhf (ARM32 PE) с локальными патчами.
#
# Рассчитан на armhf Debian 12/13 с clang/lld 19 и sysroot llvm-mingw в
# /usr/armv7-w64-mingw32 (см. BUILD-WINE11.md). Запускать от обычного
# пользователя, не от root.
#
# Примеры:
#   ./build-wine11.sh --src ~/wine-11.22 --prefix ~/opt/wine11
#   ./build-wine11.sh --src ~/wine-11.22 --ccache
#   ./build-wine11.sh --src ~/wine-11.22 --module dlls/winex11.drv/winex11.so
#
# ccache: USE_CCACHE=1 или --ccache. Кэш остаётся локальным (~/.ccache)
# и в репозиторий не попадает.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC=""
BUILD=""
PREFIX="${HOME}/opt/wine11"
JOBS="$(nproc 2>/dev/null || echo 4)"
USE_CCACHE="${USE_CCACHE:-0}"
DO_INSTALL=1
TARGETS=()

die() { echo "error: $*" >&2; exit 1; }

usage() {
    cat <<EOF
usage: $0 [options]

  --src DIR        исходники Wine (по умолчанию текущий каталог)
  --build DIR      build-каталог (по умолчанию <src>-build)
  --prefix DIR     куда ставить (по умолчанию \$HOME/opt/wine11)
  -j, --jobs N     параллельных задач (по умолчанию nproc)
  --ccache         использовать ccache (если установлен)
  --no-install     не выполнять make install
  --module TARGET  собрать только цель (можно несколько раз)
  -h, --help       эта справка
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --src)        SRC="$2"; shift 2 ;;
        --build)      BUILD="$2"; shift 2 ;;
        --prefix)     PREFIX="$2"; shift 2 ;;
        -j|--jobs)    JOBS="$2"; shift 2 ;;
        --ccache)     USE_CCACHE=1; shift ;;
        --no-install) DO_INSTALL=0; shift ;;
        --module)     TARGETS+=("$2"); shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "unknown option: $1 (try --help)" ;;
    esac
done

[ -n "$SRC" ] || SRC="$(pwd)"
[ -f "$SRC/configure" ] || die "$SRC does not look like a Wine source tree"
SRC="$(cd "$SRC" && pwd)"
[ -n "$BUILD" ] || BUILD="${SRC}-build"

for tool in gcc g++ clang llvm-ar; do
    command -v "$tool" >/dev/null 2>&1 || \
        die "missing $tool (apt install build-essential clang lld llvm)"
done

export PATH="$SCRIPT_DIR/toolchain:$PATH"
command -v armv7-w64-mingw32-clang >/dev/null 2>&1 || \
    die "armv7-w64-mingw32-clang not found in $SCRIPT_DIR/toolchain"

if [ "$USE_CCACHE" = 1 ]; then
    command -v ccache >/dev/null 2>&1 || \
        die "ccache not installed (apt install ccache) or unset --ccache"
    export WINE_CCACHE=1
    CC="ccache gcc"
    CXX="ccache g++"
    echo "ccache: enabled ($(ccache --version | head -1))"
else
    CC="gcc"
    CXX="g++"
fi

mkdir -p "$BUILD"
cd "$BUILD"

if [ ! -f Makefile ]; then
    echo "configure: $SRC -> $BUILD (prefix $PREFIX)"
    "$SRC/configure" \
        --prefix="$PREFIX" \
        --enable-archs=arm \
        --with-mingw=llvm-mingw \
        --disable-tests \
        CC="$CC" CXX="$CXX" \
        CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0"
else
    echo "reusing existing build tree: $BUILD"
fi

if [ ${#TARGETS[@]} -gt 0 ]; then
    echo "make -j$JOBS ${TARGETS[*]}"
    make -j"$JOBS" "${TARGETS[@]}"
else
    echo "make -j$JOBS"
    make -j"$JOBS"
    if [ "$DO_INSTALL" = 1 ]; then
        make install
    fi
fi
