# Wine 11 ARM32 — local fixes

This repository focuses on **Wine 11 ARM32 (armhf)** — a native 32-bit ARM
build running on an ARMv7 userland. It is **not** about x86 emulation
(box86/box64) and **not** about the ARM64 port. It contains the patches and
documentation needed to bring a stock Wine 11.21 armhf build to the point
where real Windows ARM32 PE binaries run on an Android phone: UWP→Win32 shims
(Win32Craft) and ARM32 games.

This repository is based on Wine **11.21** and contains the ARM32 fixes
**already applied**. The standalone patches are in `patches/` and also apply
to a pristine Wine 11.21 tree with `patch -p1`. Apart from race and crash
fixes, they are opt-in and do not change default behaviour unless the
corresponding environment variable is set.

A ready-to-run binary is published in Releases (once available). The source
tree can be rebuilt with the scripts in `build/`.

## Tested software

Tested on a POCO X3 Pro (ARMv7 + AArch64, Adreno 640) running Debian 13.7
armhf in a chroot (Linux Deploy), Wine 11.21, with Xvfb/llvmpipe (`:1`) and
labwc + Mesa KGSL + wayvnc (`:2`).

| # | Program / game | Status |
|---|---|---|
| 1 | **HDS** — HEX Differences Searcher 1.0.2 (LLVM-mingw/UCRT ARM32, console + GUI) | Works under Wine 10, including drag-and-drop; not separately re-tested under Wine 11. Cosmetic issue: the two blue splitter animations are missing |
| 2 | **Geometry Dash 1.0.0.0** (Win32Craft ARM32) | Works under Wine 10 with app-local MSVC runtimes (`msvcr110`, `msvcp110`). The crash was caused by a Wine 10 RTTI bug, fixed upstream in Wine 11 |
| 3 | **REDCON** (Win32Craft ARM32) | Reaches `OnLaunched` with app-local `msvcr120_app`/`msvcp120_app`; then stops at WinRT `ApplicationLanguages`/`SetRestrictedErrorInfo`. Not re-tested under Wine 11 yet |
| 4 | **Minecraft PE 0.10.4.40** (Win32Craft ARM32) | **Works** under Wine 11.21: main menu, world, rendering, timers |
| 5 | **Minecraft Bedrock 1.2.8** (Win32Craft ARM32) | **Works** under Wine 11.21: menu, world list, world creation, in-world gameplay; closes via the window "X" button and `Alt+F4` |

Limitation: this is an ARM32 Wine build, so it runs only **ARM32 PE**
(Windows RT / ARM32 shims). Regular x86 applications do not run.

## What exactly was fixed

### 1. `Windows.System.Threading.ThreadPoolTimer` (the key fix for MCPE)

Files:

- `include/windows.system.threading.idl`
- `dlls/threadpoolwinrt/classes.idl`
- `dlls/threadpoolwinrt/main.c` (+424 lines)

What was added:

- the `ThreadPoolTimer` runtime class to both IDL files;
- the `TimerElapsedHandler` and `TimerDestroyedHandler` delegates;
- the `IThreadPoolTimer` (`Period`, `Delay`, `Cancel`) and
  `IThreadPoolTimerStatics` (`CreatePeriodicTimer`, `CreateTimer`,
  `CreatePeriodicTimerWithCompletion`, `CreateTimerWithCompletion`)
  interfaces;
- the implementation in `threadpoolwinrt`: activation factory, statics and
  the timer object itself;
- one dedicated thread per timer: `CreateEvent` + `CreateThread` +
  `WaitForSingleObject`. Not the most efficient design, but simple and
  functionally correct;
- registration in `DllGetActivationFactory`:
  `RuntimeClass_Windows_System_Threading_ThreadPoolTimer` → `timer_factory`.

Why: Win32Craft creates a `DispatcherTimer` through
`Windows.System.Threading.ThreadPoolTimer`. Wine 11.21 implemented
`ThreadPool` but not `ThreadPoolTimer`, so activation failed and the game
received no timer ticks. After the patch, timers started firing at ~50 Hz.

### 2. Shader include files (`d3dcompiler`)

File: `dlls/d3dcompiler_43/compiler.c`

The `D3D_COMPILE_STANDARD_FILE_INCLUDE` handler now looks for the last
separator using both `\` and `/`. If the file cannot be opened by its full
path, it retries with the bare include name. `d3dcompiler_47` is built from
the same `compiler.c` via `PARENTSRC`, so the patch fixes both DLLs.

Why: MCPE compiles `data/shaders/dx11/color_uv.vertex.hlsl`; the old code
only looked for `\`, substituted the current directory instead of
`data/shaders/dx11/`, and failed to find `ShaderConstants.fxh` with
`E4002: Failed to open`.

### 3. `winebuild` and resources on a 32-bit host

File: `tools/winebuild/res32.c`

Instead of `.incbin "big.res",offset,size` for every resource, a separate
small temporary file is created and `.incbin "<tmpfile>"` is used. Added
`#include <limits.h>` and `#include <unistd.h>`.

Why: the LLVM assembler `mmap`s the whole file for every `.incbin`.
`shell32.res` contains 3082 resources in an 8.7 MB file, so a 32-bit process
ran into the ~3 GB address-space limit and failed with a bogus
`Could not find incbin file`. This was required to build resource-heavy DLLs
at all.

### 4. Local Wine 11 ARM32 patch (`wine11-arm32-local.patch`)

Added during the second stage — bringing up MCPE/MCBE, the hardware display
`:2` and VNC control. 10 files, 23 hunks:

- `dlls/winex11.drv/mouse.c` — `WINE_X11_MOUSE_AS_TOUCH`: mouse → synthetic
  touch (`=1` legacy extra-info, `=pointer` real `WM_POINTER`); disable
  `XGrabPointer` and skip mapping the clip window in `NoPointerGrab` mode;
- `dlls/winex11.drv/x11drv_main.c` — read `WINE_X11_NO_POINTER_GRAB` and the
  `NoPointerGrab` registry value;
- `dlls/winex11.drv/window.c` — `X11DRV_SetCapture` without grabbing; verify
  that the clip window is still alive and reparent it to the root window
  (otherwise a fatal `BadWindow` when the desktop window is recreated);
- `dlls/winex11.drv/x11drv.h` — `extern BOOL no_pointer_grab`;
- `dlls/wined3d/cs.c` — re-wake the command-stream thread when
  `wined3d_cs_mt_finish` waits too long for the queue to drain (fixes the
  render freeze on the hardware display);
- `libs/vkd3d/libs/vkd3d-shader/{hlsl.h,hlsl.c,hlsl.y,hlsl_codegen.c,glsl.c}`
  — `CalculateLevelOfDetail(Unclamped)` in the vkd3d HLSL frontend (needed by
  MCBE 1.2.8).

In short:

- **MCPE/MCBE** get timers and shader compilation (items 1–3 above);
- **MCBE 1.2.8** additionally needs app-local native MSVC runtimes and
  `CalculateLevelOfDetail(Unclamped)` — without it `D3DCompile #2` fails with
  `E5005` and the game dereferences null;
- **VNC**: the window can be closed with the "X" button or `Alt+F4` (clicks
  reach the window manager), and the cursor is not locked inside the game
  window;
- **robustness**: MCBE starts even when MCPE is already running in the same
  `wineserver` (a stale clip-window id no longer kills the process);
- **hardware display `:2`**: rendering no longer freezes after 15–110 s
  (lost wakeup in the wined3d command stream).

### 5. What made GD, REDCON and MCPE work

To avoid the impression that "Wine had to be rewritten": the first stage
changed only **5 files / 3 patches**, and none in `ntdll` or `d3d11`. Later,
while bringing up MCBE 1.2.8 and the hardware display,
`wine11-arm32-local.patch` was added (10 files / 23 hunks), including
`wined3d` and `vkd3d`.

**What is NOT a source change:**

- RTTI on ARM32 — a Wine 10 bug, fixed upstream in Wine 11; no patch.
- Building ARM32 PE — toolchain glue, not source:
  - a custom `libgcc.a` with `__gnu_h2f_ieee`/`__gnu_f2h_ieee`
    ([`libgcc-arm-half.c`](libgcc-arm-half.c));
  - a clang wrapper:
    `--target=armv7-windows-gnu -march=armv7-a -mfpu=neon -fuse-ld=lld
    -rtlib=compiler-rt -stdlib=libc++ ... -lgcc`;
  - `lld`/`lld-link` symlinks, llvm-mingw headers, an empty `libgcc_s.a`;
  - `configure --enable-archs=arm --with-mingw=llvm-mingw --disable-tests`.
- Runtime settings, not code:
  - `WINEDLLOVERRIDES` with native app-local MSVC runtimes for
    MCPE/REDCON/MCBE;
  - `--feature-level=10_0` (a Win32Craft shim flag, not Wine);
  - `~/.asoundrc` with null ALSA;
  - Xvfb + llvmpipe instead of Xvnc.

## Patches in this repository

The fixes below are **already applied** to the source tree. The patches are
kept here for reference and for rebuilding a pristine Wine 11.21.

| Patch | Files | What it fixes |
|---|---|---|
| [`patches/threadpooltimer-winrt.patch`](patches/threadpooltimer-winrt.patch) | 3 | `Windows.System.Threading.ThreadPoolTimer` (MCPE) |
| [`patches/d3dcompiler-include-forward-slash.patch`](patches/d3dcompiler-include-forward-slash.patch) | 1 | `#include` with `/` and bare names in `d3dcompiler` (MCPE shaders) |
| [`patches/winebuild-arm32-resources.patch`](patches/winebuild-arm32-resources.patch) | 1 | `winebuild` no longer `mmap`s the whole `.res` for every `.incbin` (build on a 32-bit host) |
| [`wine11-arm32-local.patch`](wine11-arm32-local.patch) | 10 | mouse-as-touch/`WM_POINTER`, `NoPointerGrab` + clip window, `wined3d` freeze, `CalculateLevelOfDetail` in vkd3d |
| [`patches/winex11-mouse-as-touch.patch`](patches/winex11-mouse-as-touch.patch) | 1 | Standalone mouse-as-touch diff for upstream. **Already included** in `wine11-arm32-local.patch` |
| [`patches/vkd3d-calculate-lod.patch`](patches/vkd3d-calculate-lod.patch) | 5 | Standalone `CalculateLevelOfDetail` diff for upstream vkd3d. **Already included** in `wine11-arm32-local.patch` |

Order of application to a pristine `wine-11.21`:

```sh
for p in patches/threadpooltimer-winrt.patch \
         patches/d3dcompiler-include-forward-slash.patch \
         patches/winebuild-arm32-resources.patch \
         wine11-arm32-local.patch; do
    patch -p1 < "$p"
done
```

`winex11-mouse-as-touch.patch` and `vkd3d-calculate-lod.patch` do not need to
be applied separately — they are already part of
`wine11-arm32-local.patch`.

All patches have been verified: they apply with `patch -p1` to a pristine
Wine 11.21 tree and produce files that are byte-for-byte identical to the
build tree (for `wine11-arm32-local.patch` — round-trip against
`wine-11.21.tar.xz`, md5 `048b06178c0f518c71f91ee4699b68a7`).

## Building

Details and troubleshooting are in [`BUILD-WINE11.md`](BUILD-WINE11.md).
In short (armhf Debian 13, clang 19 + lld 19 + llvm-mingw sysroot):

```sh
# 1. This fork (the fixes are already applied)
git clone https://github.com/Max-RM/wine.git wine-arm32
cd wine-arm32

# 2. Build (script from this repository)
./build/build-wine11.sh --src . --prefix "$HOME/opt/wine11"
```

To reproduce the same tree from a pristine Wine 11.21 source instead, apply
the patches first:

```sh
git clone --branch wine-11.21 --depth 1 \
    https://github.com/wine-mirror/wine.git wine-11.21
cd wine-11.21
for p in /path/to/repo/patches/threadpooltimer-winrt.patch \
         /path/to/repo/patches/d3dcompiler-include-forward-slash.patch \
         /path/to/repo/patches/winebuild-arm32-resources.patch \
         /path/to/repo/wine11-arm32-local.patch; do
    patch -p1 < "$p"
done
/path/to/repo/build/build-wine11.sh --src . --prefix "$HOME/opt/wine11"
```

`build/build-wine11.sh` creates an out-of-tree build directory, picks up the
`armv7-w64-mingw32-clang` wrapper and supports `ccache` (see below).

### Incremental rebuild

After the first build you do **not** need to rebuild everything. Rebuild only
the module you changed:

```sh
cd wine-11.21-build

# example: edit dlls/winex11.drv/mouse.c
make -j"$(nproc)" dlls/winex11.drv/winex11.so
cp dlls/winex11.drv/winex11.so \
   "$HOME/opt/wine11/lib/wine/arm-unix/"

# example: PE DLL
make -j"$(nproc)" dlls/combase/arm-windows/combase.dll
cp dlls/combase/arm-windows/combase.dll \
   "$HOME/opt/wine11/lib/wine/arm-windows/"
```

### Compilation cache (ccache)

`ccache` is supported as an **optional local build feature**, not as a file in
the repository.

- `build/build-wine11.sh --ccache` (or `USE_CCACHE=1`) wraps the host
  `gcc`/`g++` and the PE `clang` in `ccache`, if it is installed.
- The cache helps on a rebuild from scratch, after `make clean`, when
  switching branches, and on repeated builds on the same machine. It does not
  speed up the first build on a new machine.
- The cache is **not committed**: it is tied to the compiler version, flags
  and paths, takes gigabytes, and is useless on another machine.
- `sccache` only makes sense when a shared/remote cache (S3/Redis) is needed;
  for a single machine it is unnecessary complexity.
- Do not put a prepared build tree (`.o` files) in the repository: it is
  platform-dependent, breaks when the toolchain changes and is larger than
  the sources.
- For users who only want to run Wine, publish a binary in Releases rather
  than a cache.

Summary: **scripts — yes, ccache — yes (optional), the cache itself and build
artifacts — no.**

## Documentation

- [`DEBIAN13.md`](DEBIAN13.md) — how the Debian 13 armhf container, Wine
  10/11, VNC `:1`/`:2` and game launching are set up, plus FPS measurements.
- [`BUILD-WINE11.md`](BUILD-WINE11.md) — building Wine 11.21 armhf, the
  toolchain, error analysis and incremental rebuilds.

## License

Wine is distributed under LGPL-2.1-or-later. The patches are a derivative
work of Wine and are distributed under the same terms.
