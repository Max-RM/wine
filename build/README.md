# Building Wine 11.21 ARM32

This directory contains the minimal glue needed to build Wine 11.21 armhf
with the patches from this repository. The full error analysis and
alternatives are in [`../BUILD-WINE11.md`](../BUILD-WINE11.md).

## Requirements (armhf Debian 12/13)

```sh
sudo apt install build-essential clang lld llvm libunwind-dev \
                 libx11-dev libxext-dev libxrender-dev libxfixes-dev \
                 libxkbcommon-dev libxi-dev libvulkan-dev \
                 libfreetype-dev libfontconfig1-dev libgnutls28-dev \
                 libasound2-dev libpulse-dev libudev-dev libdbus-1-dev \
                 libxml2-dev libxslt1-dev
```

Plus the llvm-mingw sysroot in `/usr/armv7-w64-mingw32` (headers, libraries,
`libclang_rt.builtins-arm.a`), an `lld-link` symlink in `PATH`, and a custom
`libgcc.a` with `__gnu_h2f_ieee`/`__gnu_f2h_ieee` — see the "PE compiler on
armhf" section in [`../BUILD-WINE11.md`](../BUILD-WINE11.md).

Check:

```sh
clang --version          # 19.x
ld.lld --version
ls /usr/armv7-w64-mingw32/lib/libgcc.a
command -v lld-link
```

## Usage

```sh
# sources + patches
git clone --branch wine-11.21 --depth 1 \
    https://github.com/wine-mirror/wine.git wine-11.21
cd wine-11.21
for p in /path/to/repo/patches/threadpooltimer-winrt.patch \
         /path/to/repo/patches/d3dcompiler-include-forward-slash.patch \
         /path/to/repo/patches/winebuild-arm32-resources.patch \
         /path/to/repo/wine11-arm32-local.patch; do
    patch -p1 < "$p"
done

# full build + install
/path/to/repo/build/build-wine11.sh --src . --prefix "$HOME/opt/wine11"

# with ccache (local cache, not committed)
/path/to/repo/build/build-wine11.sh --src . --ccache

# only one module after an edit
/path/to/repo/build/build-wine11.sh --src . \
    --module dlls/winex11.drv/winex11.so
```

The script creates an out-of-tree `<src>-build` directory, so the sources
stay clean.

## Incremental rebuild

After the first build, rebuild only the changed module instead of the whole
tree:

```sh
cd wine-11.21-build
make -j"$(nproc)" dlls/winex11.drv/winex11.so
cp dlls/winex11.drv/winex11.so "$HOME/opt/wine11/lib/wine/arm-unix/"

make -j"$(nproc)" dlls/combase/arm-windows/combase.dll
cp dlls/combase/arm-windows/combase.dll "$HOME/opt/wine11/lib/wine/arm-windows/"
```

## Compilation cache

`ccache` is supported via `--ccache` / `USE_CCACHE=1`:

- speeds up a rebuild from scratch, `make clean` and branch switching on the
  same machine;
- does not speed up the first build on a new machine;
- the cache (`~/.ccache`) is not committed: it depends on the compiler,
  flags and paths;
- a prepared build tree or `.o` files are not placed in the repository —
  they are platform-dependent and heavier than the sources.
