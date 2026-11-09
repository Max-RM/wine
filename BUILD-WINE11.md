# Wine ARM32: почему не «патчим 4.0», и как собрать современный Wine

Дата: 07.11.2026. Статус: **вариант A выполнен** — Debian 13 armhf + Wine 10
установлены, HDS проходит, Geometry Dash запускается с родными MSVC-рантаймами
(см. [DEBIAN13.md](DEBIAN13.md)). **Вариант B в работе**: Wine 11.22 armhf
успешно прошёл `configure`, идёт `make -j6`; toolchain и найденные грабли
описаны в DEBIAN13.md, раздел «Wine 11.22 armhf: сборка».

## Коротко

1. **Перенести все изменения Wine 11 в Wine 4.0 нельзя.** Это не набор патчей, а
   другая кодовая база: между 4.0 (2019) и 11.0 (2026) переписаны PE/Unix-разделение,
   WoW64, ntdll, UCRT, HID, драйверы и т.д. Практически это означает «взять Wine 11
   и собрать его под ARM32», а не «допатчить 4.0».
2. **Полная сборка Wine возможна только на Linux.** `C:\llvm-mingw` собирает только
   Windows PE (DLL/EXE). `wineserver`, `ntdll.so`, `win32u.so` и драйверы — это ELF,
   их должен собирать Linux-компилятор под armhf.
3. **Самый быстрый путь — не собирать, а взять готовый armhf Wine 10 из Debian 13
   (trixie).** В нём уже есть полный набор ARM32 PE DLL, включая `ucrtbase.dll`
   с `wcrtomb_s`. Требуется glibc >= 2.38, то есть Debian 13 (или новее).
4. Если нужен именно Wine 11 — собирать нативно в armhf-chroot на телефоне
   (Debian 12/13), с PE-компилятором `clang` + sysroot от LLVM-mingw.
5. Место: минимум ~5 ГБ, комфортно 10–12 ГБ. Сейчас на `/data` свободно ~6.7 ГБ —
   впритык; лучше внешний USB-накопитель или сборка на другой машине.

## Откуда исходники (для своей ветки)

Дерево соответствует официальному релизу Wine 11.22 (git-тег `wine-11.22`,
upstream-коммит `9f8c4ae`), а не дистрибутивному пакету. Основной способ
получить базу — git; тарбол с dl.winehq.org — для проверки одного файла:

- `https://dl.winehq.org/wine/source/11.x/wine-11.22.tar.xz`
  (ссылка подтверждена файлом `ANNOUNCE.md` внутри дерева);
- md5 тарбола здесь не приводится: дерево сверялось по git-тегу `wine-11.22`
  (upstream-коммит `9f8c4ae`), он и есть точка отсчёта для патчей;
- локально дерево — `/home/MaxRM/Projects/wine-11.22`,
  сборка — `/home/MaxRM/Projects/wine-11.22-build` (out-of-tree).

Тот же код в git — официальный репозиторий WineHQ, тег `wine-11.22`:

```bash
# официальный (GitLab WineHQ)
git clone --branch wine-11.22 --depth 1 \
    https://gitlab.winehq.org/wine/wine.git wine-11.22

# или зеркало на GitHub
git clone --branch wine-11.22 --depth 1 \
    https://github.com/wine-mirror/wine.git wine-11.22

cd wine-11.22
git checkout -b arm32/mcpe-0.10.4
```

Для своей ветки с исправлениями: наложить патчи из [`patches/`](patches/)
на тег и закоммитить их по одному.

```bash
for p in /path/to/wine/patches/*.patch; do
    patch -p1 < "$p"
done
```

Патчи (все против чистого `wine-11.22`):

| Патч | Что чинит |
|---|---|
| [`winebuild-arm32-resources.patch`](patches/winebuild-arm32-resources.patch) | `winebuild` не маппит целиком `.res` на каждый `.incbin` — иначе линковка `shell32.dll` падает на 32-битном хосте |
| [`d3dcompiler-include-forward-slash.patch`](patches/d3dcompiler-include-forward-slash.patch) | `#include` с `/` и голым именем в `d3dcompiler` (шейдеры MCPE) |
| [`threadpooltimer-winrt.patch`](patches/threadpooltimer-winrt.patch) | `Windows.System.Threading.ThreadPoolTimer` для WinRT-приложений |
| [`winex11-mouse-as-touch.patch`](patches/winex11-mouse-as-touch.patch) | `WINE_X11_MOUSE_AS_TOUCH`: мышь → синтетическое касание (`=1` legacy extra-info, `=pointer` настоящий `WM_POINTER`) |
| [`wine11-arm32-local.patch`](wine11-arm32-local.patch) | Дополнительные локальные правки поверх перечисленных (10 файлов, 23 хунка): `WINE_X11_NO_POINTER_GRAB` (окно можно закрыть по VNC; в этом режиме clip-окно не мапится, иначе оно перехватывает клики по заголовку), устойчивость `winex11.drv` к протухшему clip-окну (фатальный `BadWindow` при пересоздании desktop-окна), фикс потерянного пробуждения в `dlls/wined3d/cs.c` (без него рендер на аппаратном дисплее замирает через 15–110 с) и поддержка `CalculateLevelOfDetail(Unclamped)` в HLSL-фронтенде vkd3d (нужна MCBE 1.2.8) |
| [`patches/vkd3d-calculate-lod.patch`](patches/vkd3d-calculate-lod.patch) | Отдельный diff той же поддержки `CalculateLevelOfDetail(Unclamped)` для апстрима vkd3d. **Уже включён** в `wine11-arm32-local.patch` — не применять оба |

## Почему не бэкпорт

Wine 4.0 ARM32 — экспериментальная ветка mainline. В Wine 11 ARM32 — это тот же
mainline, собранный с `--enable-archs=arm`. Отдельной «ветки ARM32», из которой
можно вытащить исправления, нет. `unxed/fix-it-in-wine` — методика точечных хаков
под конкретные приложения, а не способ перенести 7 лет разработки.

Практический вывод: базой должен быть Wine 11 (или 10), а не 4.0. Остающиеся
проблемы (HID, UCRT, D3D, конкретные приложения) чинятся уже поверх него.

## Что уже проверено по пакетам Debian

| Пакет | Версия | glibc | Установлено | Что внутри |
|---|---|---|---|---|
| `libwine` armhf, trixie | 10.0~repack-6 | >= 2.38 | 437 МБ | 746 ARM32 PE DLL (`arm-windows/`), 37 Unix `.so` (`arm-unix/`), `ucrtbase.dll` с `wcrtomb_s` |
| `libwine` armhf, bookworm | 8.0~repack-4 | >= 2.35 | 190 МБ | ARM32 PE + Unix `.so` |
| `libwine` armhf, bullseye | 5.0.3-3 | >= 2.31 | ~? | первая версия с рабочим `wcrtomb_s` |

То есть `wcrtomb_s` не нужно шить: в Wine >= 5.0 она реализована в `ucrtbase`.
Шим из `wine/shim` — временная мера для 4.0, для современного Wine не нужен.

## Вариант A (рекомендуется первым): готовый Wine 10, без сборки

Нужен armhf-rootfs Debian 13 (trixie). Варианты:

- отдельный Linux Deploy-контейнер/профиль с Debian 13 armhf;
- вложенный chroot в текущем Debian 10 (если разрешены mount/bind);
- rootfs-тарбол Debian 13 armhf + `chroot`.

В chroot:

```bash
apt update
apt install -y wine32 wine fonts-wine
# или, если не хотим ставить в систему:
# apt download wine32 libwine wine wine-common
# for f in *.deb; do dpkg-deb -x "$f" /home/MaxRM/Projects/Wine/wine10; done
```

Проверка версии и HDS:

```bash
export WINEPREFIX=/home/MaxRM/Projects/Wine/prefix10
export WINEARCH=win32
export DISPLAY=:0
export XAUTHORITY=/home/MaxRM/.Xauthority
wine --version
cd /home/MaxRM/Projects/Wine/WinTest
wine HDS --console a.bin b.bin -y -q
ls -l HDS-Logs_*.txt
```

Ожидание: `wcrtomb_s` больше не «unimplemented», лог непустой. Если HDS
запустился — современный Wine решает исходную проблему, и можно тестировать
`Win32Craft_ARM`.

Минусы: Debian 13 требует glibc 2.38; на текущем Debian 10 это не запустится.
Для Tab 2 нужен Debian 13 (или 12 + Wine 8.0).

## ARM64-rootfs + multiarch или armhf-rootfs?

Для задачи «запускать ARM32 PE» правильный выбор — **armhf-rootfs**, а не
arm64 + multiarch.

Почему:

- Wine ARM32 — это 32-битный Unix-слой + 32-битные PE DLL. Ему нужен именно
  armhf-userland; arm64-слой сам по себе ARM32 PE не запускает (32-битный ARM-код
  не исполняется внутри 64-битного процесса).
- На arm64 пришлось бы делать `dpkg --add-architecture armhf` и ставить
  `wine32:armhf` **плюс** armhf-версии X11, freetype, fontconfig, ALSA, Pulse,
  gnutls и т.д. Это не «один пакет», а параллельный набор 32-битных библиотек.
- armhf-rootfs меньше по размеру и не создаёт multiarch-конфликтов.
- Tab 2 — чистый ARM32, там armhf обязателен. Если тестировать на телефоне в
  armhf, перенос на Tab 2 будет один в один.
- Сборка Wine 11 на armhf — нативная; на arm64 пришлось бы городить armhf-chroot
  или кросс-сборку.

Единственное условие: ядро и CPU должны поддерживать AArch32 (32-битный
userland). Сейчас это уже доказано — текущий Debian 10 armhf работает. Если
когда-нибудь перейдёшь на устройство, где 32-битные бинарники не запускаются,
проверять нужно именно это, а не «пакет для ARM32».

Если бы целью был ARM64-Wine или ARM64 PE — тогда да, arm64-rootfs. Но цель —
ARM32, поэтому armhf.

## Debian 13 без Linux Deploy (вручную)

Linux Deploy — это в основном обёртка над `chroot` + mount. Если в нём нет
Debian 13, rootfs можно поставить руками, не трогая текущий Debian 10.

Готовый armhf-rootfs: `images.linuxcontainers.org`, каталог
`images/debian/trixie/armhf/default/<дата>/rootfs.tar.xz`. На 07.11.2026
это ~84 МБ, рядом лежит `SHA256SUMS`.

Пример (пути — внутри текущего Debian 10, это тот же `/data`):

```bash
ROOT=/home/MaxRM/Projects/Wine/debian13
mkdir -p "$ROOT"
curl -LO https://images.linuxcontainers.org/images/debian/trixie/armhf/default/20261107_05:24/rootfs.tar.xz
tar -xf rootfs.tar.xz -C "$ROOT"

# DNS
cp /etc/resolv.conf "$ROOT/etc/resolv.conf"

# mount-точки
mkdir -p "$ROOT"/{proc,sys,dev,dev/shm,tmp/.X11-unix}
mount --bind /proc "$ROOT/proc"
mount --bind /sys  "$ROOT/sys"
mount --bind /dev  "$ROOT/dev"
mount --bind /dev/shm "$ROOT/dev/shm"
mount --bind /tmp/.X11-unix "$ROOT/tmp/.X11-unix"
mount --bind /home/MaxRM/Projects "$ROOT/home/MaxRM/Projects"
```

Пользователь с тем же UID, чтобы файлы в `Projects` были доступны:

```bash
chroot "$ROOT" /bin/bash
groupadd -g 60000 MaxRM
useradd -u 60000 -g 60000 -m -s /bin/bash MaxRM
exit
```

Установка Wine 10 (внутри chroot, это отдельная система, не телефон):

```bash
chroot "$ROOT" /bin/bash -c '
  apt update &&
  DEBIAN_FRONTEND=noninteractive apt install -y wine32 wine fonts-wine
'
```

Проверка:

```bash
chroot --userspec=60000:60000 "$ROOT" /bin/bash -c '
  export HOME=/home/MaxRM
  export WINEPREFIX=/home/MaxRM/Projects/Wine/prefix13
  export WINEARCH=win32
  export DISPLAY=:0
  export XAUTHORITY=/home/MaxRM/.Xauthority
  wine --version
  cd /home/MaxRM/Projects/Wine/WinTest
  wine HDS --console a.bin b.bin -y -q
'
```

Важно:

- `/data/local/tmp/...` — это путь **Android**, изнутри Debian-chroot его обычно
  не видно. Проще ставить в `/home/MaxRM/Projects/Wine/debian13`: это тот же
  раздел `/data`, и он доступен по SSH.
- Если `mount --bind` внутри chroot запрещён (SELinux/права), варианты:
  1. выполнить монтирование из root-shell на Android (adb/терминал);
  2. переключить Linux Deploy на новый rootfs (старый сохранить);
  3. `proot` — только как крайний вариант, Wine под ним может работать плохо.
- Wine ставится в `/usr` **внутри Debian 13 chroot**, а не в систему телефона.
  Это изолированно и не мешает Debian 10.
- Если нужен Wine строго в `Projects`, можно `apt download` + `dpkg-deb -x`,
  но зависимости всё равно придётся ставить в chroot.

## Обновлять текущий Debian 10 или ставить Debian 13 рядом?

Технически обновить chroot можно, но **для этой задачи лучше не делать in-place
обновление**, а поставить рядом отдельный rootfs Debian 13:

- обновление идёт только по цепочке **10 → 11 → 12 → 13**, напрямую 10 → 13
  Debian не поддерживает;
- Debian 10 и 11 уже EOL, для них нужны `archive.debian.org`/`old-releases`,
  а это лишние шансы сломать apt;
- в chroot на Android есть свои особенности (Linux Deploy, mount, SSH, UID),
  которые апгрейд может задеть;
- при апгрейде легко потерять рабочее окружение SSH/OpenCode, а откатиться
  сложно.

Безопаснее так:

1. Оставить текущий Debian 10 как есть — он отвечает за SSH/OpenCode и остаётся
   резервным вариантом.
2. Скачать rootfs Debian 13 armhf (например, с `images.linuxcontainers.org`
   или из `debuerreotype/docker-debian-artifacts`) и распаковать в отдельный
   каталог, например `/home/MaxRM/Projects/Wine/debian13`.
3. Заходить в него через `chroot` из текущего Debian 10, с bind-mount
   `/proc`, `/sys`, `/dev`, `/dev/shm`, `/tmp/.X11-unix` (для GUI) и
   `/home/MaxRM/Projects` (чтобы видеть те же файлы).
4. Создать внутри пользователя с тем же UID (`60000`), чтобы не переключать
   владельцев файлов.
5. Поставить туда `wine32` 10.0 и тестировать HDS. Если всё хорошо — позже
   можно либо оставить так, либо переехать на Debian 13 полностью.

Если всё же делать in-place апгрейд: сначала полный бэкап `/home/MaxRM` и
`/etc`, запускать через `tmux`/`screen`, идти по шагам 10→11→12→13, на каждом
шаге проверять SSH и apt. Но это дольше и рискованнее, чем отдельный rootfs.

## Вариант B: собрать Wine 11 нативно на armhf

Делать в Debian 12 (glibc 2.36) или Debian 13 (glibc 2.38). Для максимальной
совместимости с Tab 2 лучше Debian 12: тогда бинарник пойдёт на Debian 12/13 и
Arch ARM32 (там glibc новее).

### Место

| Компонент | На диске |
|---|---|
| Исходники Wine 11 (32 МБ .tar.xz) | 300–500 МБ |
| Build tree (`-g0`, `--disable-tests`) | 2.5–4 ГБ |
| Install | 0.6–1.0 ГБ |
| PE-sysroot LLVM-mingw + clang resource | ~60 МБ |
| Debian 13 chroot (если нужен) | 0.5–1 ГБ |
| **Пик** | **4–5.5 ГБ** |
| После `rm -rf build` | 1–2 ГБ |

### PE-компилятор на armhf

Проблема: обычный `gcc`/`clang` из Debian не знает Windows ARM32. Нужен
`clang` >= 16 с поддержкой ARM SEH + sysroot от LLVM-mingw.

На Windows уже есть `C:\llvm-mingw`; оттуда нужно скопировать на телефон:

- `armv7-w64-mingw32/` — заголовки и библиотеки (≈50 МБ);
- `lib/clang/19/lib/windows/libclang_rt.builtins-arm.a` (136 КБ);
- при необходимости — заголовки clang resource dir.

На телефоне (Debian 12/13):

```bash
apt install -y clang lld llvm make gcc g++ bison flex pkg-config \
  libx11-dev libxext-dev libxrandr-dev libxrender-dev libxfixes-dev \
  libxi-dev libxcomposite-dev libxcursor-dev libxinerama-dev \
  libfreetype6-dev libfontconfig1-dev libgnutls28-dev libasound2-dev \
  libpulse-dev libdbus-1-dev libxml2-dev libpng-dev libjpeg-dev \
  libvulkan-dev libgl1-mesa-dev libegl1-mesa-dev libosmesa6-dev \
  libudev-dev libcups2-dev libsane-dev libkrb5-dev libgphoto2-dev \
  liblcms2-dev libldap2-dev libncurses-dev zlib1g-dev gettext
```

Wrapper (пример; путь и версию clang поправить по факту):

```bash
mkdir -p /home/MaxRM/Projects/Wine/toolchain/bin
cat > /home/MaxRM/Projects/Wine/toolchain/bin/armv7-w64-mingw32-clang <<'EOF'
#!/bin/sh
ROOT=/home/MaxRM/Projects/Wine/toolchain
exec /usr/bin/clang \
  --target=armv7-w64-windows-gnu \
  --sysroot="$ROOT/armv7-w64-mingw32" \
  -resource-dir="$ROOT/clang-resource" \
  "$@"
EOF
chmod +x /home/MaxRM/Projects/Wine/toolchain/bin/armv7-w64-mingw32-clang
```

`clang-resource` — локальная копия resource dir, в которой лежит
`lib/windows/libclang_rt.builtins-arm.a` и заголовки clang. Не обязательно
трогать системный `/usr/lib/llvm-*`.

### Конфигурация и сборка

```bash
cd /home/MaxRM/Projects/Wine
mkdir -p src build install toolchain
tar -xf wine-11.0.tar.xz -C src

export PATH=/home/MaxRM/Projects/Wine/toolchain/bin:$PATH
cd build

../src/wine-11.0/configure \
  --prefix=/home/MaxRM/Projects/Wine/install \
  --enable-archs=arm \
  --with-mingw=llvm-mingw \
  --disable-tests \
  CFLAGS="-O2 -g0 -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard" \
  CXXFLAGS="-O2 -g0 -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard"

make -j"$(nproc)"
make install
```

Важно:

- `--enable-archs=arm` — ARM32 PE; на armhf-хосте это же значение получается
  автоматически, но лучше задать явно.
- `--with-mingw=llvm-mingw` заставит искать `armv7-w64-mingw32-clang` в `PATH`.
- `-march=armv7-a -mfpu=vfpv3-d16` — generic, без `-march=native`, чтобы
  работало и на Tab 2 (Cortex-A9), и на телефоне.
- `-g0` и `--disable-tests` экономят несколько гигабайт.
- Если `make install` ругается на `armv7-w64-mingw32-strip`, добавить wrapper
  на `llvm-strip` или `STRIP=true`.

После установки:

```bash
rm -rf /home/MaxRM/Projects/Wine/build
du -sh /home/MaxRM/Projects/Wine/install
```

### Инкрементальная пересборка одной DLL

После первой полной сборки **не удаляйте build-дерево**: в нём остаются все
`.o`, и правка одного файла пересобирает только его и линкует один модуль.

```bash
cd /home/MaxRM/Projects/wine-11.22-build

# пример: правим dlls/combase/roapi.c
make -j6 dlls/combase/arm-windows/combase.dll

# установить только эту DLL (быстрее, чем полный make install-lib)
cp dlls/combase/arm-windows/combase.dll \
   /home/MaxRM/opt/wine11/lib/wine/arm-windows/
```

Правила:

- правка `.c`/`.h` внутри `dlls/<name>/` — пересборка этого модуля;
- правка общего заголовка в `include/` — пересоберутся все объекты, которые
  его включают (makedep ведёт зависимости);
- правка `.spec` (экспорты) — пересоберутся импорт-библиотеки и
  перелинкуются зависимые модули, но это всё равно минуты, не часы;
- `make -j6` без цели — тоже инкрементальный, соберёт только изменившееся;
- установочный каталог DLL: `$(prefix)/lib/wine/arm-windows/`.

### Патчи Wine 11 для MCPE 0.10.4.40

Кроме [`winebuild-arm32-resources.patch`](patches/winebuild-arm32-resources.patch),
для MCPE нужен патч include-обработчика `d3dcompiler`:

[`patches/d3dcompiler-include-forward-slash.patch`](patches/d3dcompiler-include-forward-slash.patch)
— принимает `/` и `\` в имени шейдера и дополнительно пробует голое имя
include. Без него `data/shaders/dx11/color_uv.vertex.hlsl` не находит
`ShaderConstants.fxh` и компиляция шейдера падает с `E4002`.

Полный список патчей (включая `threadpooltimer-winrt` и
`winex11-mouse-as-touch`) и команды наложения на чистый тег — в разделе
[«Откуда исходники»](#откуда-исходники-для-своей-ветки) выше.

Применение и пересборка (патч лежит в дереве исходников, `d3dcompiler_47`
собирается из `d3dcompiler_43` через `PARENTSRC`, поэтому пересоберутся обе):

```sh
cd /home/MaxRM/Projects/wine-11.22
patch -p1 < /path/to/d3dcompiler-include-forward-slash.patch
cd /home/MaxRM/Projects/wine-11.22-build
make -j6 dlls/d3dcompiler_43/arm-windows/d3dcompiler_43.dll \
         dlls/d3dcompiler_47/arm-windows/d3dcompiler_47.dll
```

Установка обеих DLL:

```sh
for v in 43 47; do
  cp dlls/d3dcompiler_$v/arm-windows/d3dcompiler_$v.dll \
     /home/MaxRM/opt/wine11/lib/wine/arm-windows/
  cp dlls/d3dcompiler_$v/arm-windows/d3dcompiler_$v.dll \
     /home/MaxRM/.wine11/drive_c/windows/system32/
done
```

Проверка, что патч — настоящий unified diff и применяется на чистом дереве:

```sh
cd /tmp && rm -rf w11verify && mkdir -p w11verify/dlls/d3dcompiler_43
tar -xJf /tmp/wine-11.22.tar.xz -C w11verify --strip-components=1 \
    wine-11.22/dlls/d3dcompiler_43/compiler.c
cd w11verify && patch -p1 --dry-run < /path/to/d3dcompiler-include-forward-slash.patch
```

### Грабли PE-тулчейна (проверено на Wine 11.22)

1. `libs/ffmpeg/libavutil/arm/float_dsp_neon.S` требует NEON — в обёртке
   clang обязателен `-mfpu=neon`.
2. Ссылки `-lgcc`/`-lgcc_eh`/`-lgcc_s` в sysroot llvm-mingw отсутствуют:
   нужен `-rtlib=compiler-rt`, а пустой `libgcc_s.a` создаётся через
   `llvm-ar rc /usr/armv7-w64-mingw32/lib/libgcc_s.a`.
   Дополнительно ARM-хелперы `__gnu_h2f_ieee`/`__gnu_f2h_ieee` не входят в
   Wine-овский `libcompiler-rt.a` (линковка `colorcnv.dll`/ffmpeg падает с
   `undefined symbol: __gnu_h2f_ieee`). Лечится своей маленькой
   `libgcc.a` в sysroot + `-lgcc` в обёртке. Готовая реализация:
   [`libgcc-arm-half.c`](libgcc-arm-half.c).

   ```sh
   armv7-w64-mingw32-clang -c -O2 -o /tmp/h2f.o libgcc-arm-half.c
   llvm-ar rc /usr/armv7-w64-mingw32/lib/libgcc.a /tmp/h2f.o
   # в обёртку добавить -lgcc после "$@"
   ```
3. Заголовки llvm-mingw лежат не в `armv7-w64-mingw32/include`, а в
   общем `include/`; его нужно скопировать в
   `/usr/armv7-w64-mingw32/include` (там же `c++/v1`).
4. C++ линкуется только с `-stdlib=libc++ -lc++ -lc++abi -lunwind`.
5. `winegcc` при линковке DLL **не передаёт** `-fuse-ld=lld`, поэтому
   обёртка должна содержать `-fuse-ld=lld` сама. Иначе:
   `ld: unrecognised emulation mode: thumb2pe`.
6. `error: winebuild : No such file or directory` — на самом деле не гонка:
   winebuild ищет `lld-link` в `PATH`, а Debian ставит его только в
   `/usr/lib/llvm-19/bin`. Лечится симлинком:

   ```sh
   ln -sfn /usr/lib/llvm-19/bin/lld-link /usr/local/bin/lld-link
   ln -sfn /usr/lib/llvm-19/bin/lld     /usr/local/bin/lld
   ```

   Сообщение вводит в заблуждение: `spawn()` печатает `winebuild: <errno>`,
   а не имя ненайденного инструмента. Если после этого всё ещё падает,
   повторите `make` — параллельная пересборка `winebuild` тоже возможна.
7. `error: Could not find incbin file '.../shell32.res'` (и другие большие
   DLL с ресурсами) — **не** отсутствие файла, а исчерпание адресного
   пространства. LLVM-ассемблер делает `mmap` всего файла на каждый
   `.incbin`; в `shell32.res` 8.7 МБ и 3082 ресурса, то есть 3082 отображения
   по 8.7 МБ, и 32-битный процесс упирается в ~3 ГБ после ~450 штук.
   Точка отказа недетерминирована, поэтому похоже на гонку.
   Патч: [`patches/winebuild-arm32-resources.patch`](patches/winebuild-arm32-resources.patch) —
   winebuild пишет каждый ресурс в отдельный маленький временный файл.
   Применяется к `tools/winebuild/res32.c`, затем

   ```sh
   make -j6 tools/winebuild/winebuild
   ```

### Запуск из своей папки, без установки в систему

```bash
export PATH=/home/MaxRM/Projects/Wine/install/bin:$PATH
export WINEPREFIX=/home/MaxRM/Projects/Wine/prefix11
export WINEARCH=win32
export DISPLAY=:0
export XAUTHORITY=/home/MaxRM/.Xauthority
wine --version
```

Если бинарник перенесён в другое место, нужен wrapper с `WINELOADER`,
`WINESERVER`, `WINEDLLPATH`, `WINEDATADIR` (см. ниже).

### Скрипт сборки и ccache

В репозитории есть [`build/build-wine11.sh`](build/build-wine11.sh): он
создаёт out-of-tree build-каталог, подхватывает обёртку
`armv7-w64-mingw32-clang` и опционально включает `ccache`.

```sh
./build/build-wine11.sh --src ~/wine-11.22 --prefix ~/opt/wine11
./build/build-wine11.sh --src ~/wine-11.22 --ccache
./build/build-wine11.sh --src ~/wine-11.22 \
    --module dlls/winex11.drv/winex11.so
```

`ccache` ускоряет повторную сборку с нуля, `make clean` и смену ветки на
той же машине, но не первую сборку на новой машине. Кэш (`~/.ccache`) и
build-артефакты в репозиторий не кладутся: они привязаны к компилятору,
флагам и путям. Для «просто запустить» лучше публиковать бинарник в
Releases.

## Вариант C (эксперимент): glibc 2.28, сборка на Debian 10

Если критична совместимость именно с Debian 10 / старым Tab 2, можно попробовать
собрать на Debian 10 с GCC 8.3, а PE-часть — самодостаточным компилятором,
который не требует glibc 2.3x. Кандидат — **Zig** (статический бинарник для
armv7a Linux, внутри clang + mingw-w64 + compiler-rt, умеет
`-target arm-windows-gnu`). Это нужно проверять: сначала собрать крошечную
ARM32 PE DLL, потом настроить Wine. Если Zig не подойдёт — вернуться к Debian 12/13.

## Универсальный `tar.gz`

Сделать можно, но «универсальность» ограничена:

1. **glibc.** Бинарник требует glibc не старше той, на которой собран.
   - Debian 10 → glibc 2.28 → пойдёт на Debian 10+, Arch ARM32.
   - Debian 12 → glibc 2.36 → пойдёт на Debian 12+, Arch ARM32.
   - Debian 13 → glibc 2.38 → пойдёт на Debian 13+, Arch ARM32.
   Обратная совместимость (собрать на 13, запустить на 10) невозможна.
2. **CPU.** Только generic `armv7-a` + `vfpv3-d16`, без `-march=native`.
3. **Зависимости.** Wine линкуется с libX11, freetype, fontconfig, ALSA/Pulse,
   gnutls, Vulkan/GL и т.д. На Arch soname в основном те же, но пакеты должны
   быть установлены. Можно приложить `ldd`-список и/или bundled libs +
   `LD_LIBRARY_PATH`.
4. **Relocatable.** Wine не полностью relocatable: пути частично вкомпилированы.
   Нужен wrapper, который вычисляет свой каталог и выставляет
   `WINELOADER`, `WINESERVER`, `WINEDLLPATH`, `WINEDATADIR`, `PATH`.
   `WINEPREFIX` у каждой машины свой.

Шаблон wrapper:

```bash
#!/bin/sh
ROOT="$(cd "$(dirname "$0")" && pwd)"
export WINELOADER="$ROOT/install/bin/wine"
export WINESERVER="$ROOT/install/bin/wineserver"   # проверить фактический путь
export WINEDLLPATH="$ROOT/install/lib/wine/arm-unix:$ROOT/install/lib/wine/arm-windows"
export WINEDATADIR="$ROOT/install/share/wine"
export PATH="$ROOT/install/bin:$PATH"
exec "$WINELOADER" "$@"
```

Упаковка:

```bash
tar -C /home/MaxRM/Projects/Wine -czf wine-11.0-armhf.tar.gz install wine-env.sh
```

Ориентир по размеру: `libwine` armhf 10.0 — 66 МБ в `.deb` при 437 МБ
установленных. Полный Wine 11 armhf, вероятно, 150–250 МБ в `.tar.gz`.

## Tab 2 (GTP5110)

- CPU: TI OMAP4430, Cortex-A9, ARMv7, VFPv3-D16, NEON. Сборка с generic
  `-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard` подходит.
- RAM 1 ГБ: Wine 11 + тяжёлое приложение может не влезть. HDS/простые ARM32
  программы — реально; MCBE/3D — скорее всего нет.
- Проверить `uname -r`: для Debian 12/13 нужен kernel >= 3.2 (лучше 4.x+).
  Если на Tab 2 старый kernel 3.0, современный glibc может не заработать.
- Ставить готовый `tar.gz` в `/home/...`, не в системные папки; запускать через
  wrapper и `PATH`.

## Arch ARM32

- Платформа `armv7` (hard-float), glibc новее Debian 12/13.
- Поставить runtime-зависимости: `libx11 libxext libxrender libxi libxfixes
  libxrandr libxcursor libxinerama libxcomposite freetype2 fontconfig alsa-lib
  libpulse dbus libxml2 libpng libjpeg-turbo vulkan-icd-loader mesa gnutls
  krb5 libgphoto2 libusb`.
- Если используется готовый Debian-пакет, может понадобиться `libz-mingw-w64`
  (Debian-специфичная зависимость); при сборке из исходников PE-zlib входит в Wine.

## Порядок действий

1. Когда телефон подключится — проверить свободное место и наличие Debian 13
   chroot/профиля.
2. Вариант A: поднять Debian 13 armhf, поставить `wine32` (10.0), прогнать HDS.
   Это быстрый ответ на вопрос «современный Wine решает проблему?».
3. Если да — прогнать `Win32Craft_ARM`/MCBE, зафиксировать оставшиеся ошибки.
4. Если нужен Wine 11 или glibc 2.36 — вариант B: собрать в Debian 12/13,
   сделать `tar.gz`, проверить на телефоне, затем на Tab 2.
5. Вариант C (Debian 10 + Zig) — только если действительно нужна поддержка
   Debian 10; иначе не тратить время, Debian 10 EOL.

## Ссылки

- Wine 11 `configure.ac`: `--enable-archs`, `--with-mingw`, ARM PE.
- LLVM-mingw: `armv7-w64-mingw32/`, `libclang_rt.builtins-arm.a`.
- Debian packages: `libwine`, `wine32`, `wine` (armhf, trixie/bookworm).
