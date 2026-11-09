# Debian 13 armhf + Wine 10/11 на телефоне

Дата: 09.11.2026. Статус: **работает** — HDS и Geometry Dash под Wine 10,
Minecraft PE 0.10.4.40 под Wine 11.22. Добавлен аппаратный дисплей `:2`
(labwc + Mesa KGSL + wayvnc), опциональный отключатель захвата указателя и
исправлено зависание рендера (потерянное пробуждение в command stream
wined3d).

## Что установлено

| | |
|---|---|
| Rootfs | `/data/local/tmp/Debian_13_ARM32` (Debian 13.7, armhf) |
| Точка монтирования | `/data/local/tmp/mnt` (Linux Deploy 2.5.1, после перезагрузки контейнера) |
| Профиль Linux Deploy | `Debian13` (`/data/local/tmp/Debian13.conf`) |
| Рабочий стол | LXDE (lightdm не используется, старт через `startlxde`) |
| VNC | TightVNC `:1` → порт **5901** (x11vnc, программный), `:2` → **5902** (wayvnc, аппаратный) |
| SSH | порт **2223**, пользователь **MaxRM**, пароль задан локально (в публичной копии скрыт) |
| Wine | 10.0~repack-6 (пакеты `libwine`, `wine32`, `wine`, `wine32-preloader`) |
| Wine 11 | 11.22, установлен в `/home/MaxRM/opt/wine11` и зарегистрирован в `/usr/local` как системный `wine` |
| Wine prefix | Wine 10: `/home/MaxRM/.wine`, Wine 11: `/home/MaxRM/.wine11` |

Старые контейнеры `Linux_ARM32` (Debian 10) и `Arch` не тронуты.

## Запуск и остановка (Termux)

```sh
su -c 'sh /data/local/tmp/start-debian13.sh'
```

Скрипт сам монтирует контейнер, запускает dbus, sshd и VNC. Повторный запуск
безопасен: уже работающие сервисы не дублируются.

Остановка:

```sh
su -c 'sh /data/local/tmp/stop-debian13.sh'
```

После запуска скрипт печатает IP телефона:

```
SSH  : ssh MaxRM@<phone-ip> -p 2223     (пароль задан локально)
VNC 1: <phone-ip>:5901                  (x11vnc, без пароля, LXDE/софт)
VNC 2: <phone-ip>:5902                  (wayvnc, без пароля, аппаратный, игры)
```

## Вход в систему

SSH (из Termux или с ПК):

```sh
ssh MaxRM@<phone-ip> -p 2223
```

Root-shell внутри контейнера:

```sh
su -c 'sh /data/data/ru.meefik.linuxdeploy/files/cli.sh -p Debian13 shell'
```

VNC-клиент: адрес `<phone-ip>:5901` — LXDE на программном дисплее `:1`.
Второй порт `5902` — аппаратный дисплей `:2` для игр (см. раздел про `:2`).
Оба сервера сейчас запущены **без пароля** (`-nopw` / без auth); SSH
по-прежнему защищён паролем (задан локально).

## Автозапуск VNC и доступ по USB

### Внутри контейнера

VNC поднимается сам при старте контейнера и сторожится демоном:

| Что | Файл |
|---|---|
| хук LinuxDeploy (`INIT=run-parts`, `INIT_PATH=/etc/rc.local`) | `/etc/rc.local` |
| sysv-обёртка (на случай переключения на `INIT=sysv`) | `/etc/init.d/vnc-display` |
| запуск + сторож | `/usr/local/bin/vnc-autostart` |

`vnc-autostart` вызывает `display-up`, поднимает LXDE на `:1` и раз в 30 с
проверяет, что живы `Xvfb :1`, `labwc`, `Xwayland :2` и порты 5901/5902.
Если что-то упало — снова вызывает `display-up` (он идемпотентный).
Лог: `/tmp/vnc-autostart.log`.

```sh
/etc/init.d/vnc-display status
/etc/init.d/vnc-display restart
touch /etc/vnc-autostart.no-watchdog   # выключить сторож
```

LinuxDeploy при остановке контейнера вызывает `/etc/rc.local stop` — это
корректно останавливает все VNC-процессы (проверено).

### Автозапуск контейнера после перезагрузки телефона

Magisk-скрипт `/data/adb/service.d/99-linuxdeploy-vnc.sh` ждёт
`sys.boot_completed`, затем выполняет
`cli.sh -p /data/local/tmp/Debian13.conf start -m`. Лог:
`/data/local/tmp/linuxdeploy-boot.log`. Отключить:

```sh
mv /data/adb/service.d/99-linuxdeploy-vnc.sh /data/adb/service.d/99-linuxdeploy-vnc.sh.off
```

### Доступ с ПК по шнуру (localhost)

`adb forward` живёт в adb-сервере на ПК и **теряется** при переподключении
кабеля, перезагрузке телефона или ПК — изнутри Linux это не исправить.
Поэтому сторож стоит на ПК:

- [`vnc-usb.ps1`](../vnc-usb.ps1) — раз в 3 с проверяет `adb get-state` и
  при необходимости заново создаёт `tcp:5901` / `tcp:5902`;
- `vnc-usb.cmd` — запуск без окна консоли;
- `vnc-usb-once.cmd` — разово, вручную;
- ярлык `VNC USB adb-forward` уже лежит в автозагрузке Windows
  (`shell:startup`).

После этого `localhost:5901` и `localhost:5902` в TightVNC доступны всегда,
пока воткнут кабель.

### Ctrl+V в терминале

В `lxterminal` вставка переназначена с `Ctrl+Shift+V` на **`Ctrl+V`**
(`~/.config/lxterminal/lxterminal.conf`, `paste_accel=<Primary>v`).
Копирование оставлено на `Ctrl+Shift+C`: `Ctrl+C` в терминале — это SIGINT
(прерывание программы), забирать его под копирование нельзя.

## Wine 10

Окружение уже подготовлено:

```sh
source ~/Projects/Wine/wine-env.sh
wine --version
# wine-10.0 (Debian 10.0~repack-6)
```

`wine-env.sh` выставляет:

```sh
DISPLAY=:1
XAUTHORITY=$HOME/.Xauthority
WINEPREFIX=$HOME/.wine
WINEDLLOVERRIDES="mscoree,mshtml="
WINEDEBUG=-all
```

Обёртка для запуска из любой папки:

```sh
~/Projects/Wine/wine-run.sh winecfg
```

Важно: запускать **от пользователя MaxRM**, не через `sudo wine` — иначе
меняются `HOME`/`DISPLAY` и владельцы файлов в префиксе.

## Wine 11 как системный Wine (по умолчанию)

Wine 11 установлен в `/home/MaxRM/opt/wine11`, а в `/usr/local` зарегистрирован
как системный Wine: бинарники и каталоги `lib/share/include` — символические
ссылки на эту единственную установку (без копирования сотен мегабайт).

```sh
which wine          # /usr/local/bin/wine
wine --version      # wine-11.22
```

Префикс по умолчанию — `~/.wine11` (не `~/.wine`, чтобы не обновлять префикс
Wine 10). Он задаётся в `/etc/profile.d/wine11.sh` и в `~/.bashrc` для
интерактивных оболочек; явно заданный `WINEPREFIX` всегда имеет приоритет.

Wine 10 остаётся в `/usr/bin/wine` как запасной вариант:

```sh
source ~/Projects/Wine/wine-env.sh   # PATH=/usr/bin:$PATH, WINEPREFIX=~/.wine
wine --version                        # wine-10.0
```

Внимание: в нелогин-оболочках (`su MaxRM -c '...'` без `-`) `WINEPREFIX` не
выставляется автоматически — задавайте его явно.

## Запуск `.exe` по двойному клику

Установлены `xdg-utils` и `desktop-file-utils`, созданы:

- `/usr/local/bin/wine11-open` — обёртка: выставляет `WINEPREFIX=~/.wine11`,
  `WINEARCH=win32`, `WINEDEBUG=-all` и вызывает `/usr/local/bin/wine`;
- `/usr/share/applications/wine11.desktop` — обработчик для PE-файлов.

MIME-ассоциации пользователя MaxRM:

```
application/vnd.microsoft.portable-executable  -> wine11.desktop
application/x-ms-dos-executable                -> wine11.desktop
application/x-msdownload                       -> wine11.desktop
```

Проверка:

```sh
xdg-mime query default application/vnd.microsoft.portable-executable
# wine11.desktop
```

После этого двойной клик по `.exe` в PCManFM запускает Wine 11. Проверено
end-to-end на тестовом PE: `gio open` и `xdg-open` запускают его через Wine.
`application/x-executable` (ELF) намеренно **не** перехватывается.

Для MCPE по-прежнему нужен `~/start-mcpe11.sh`: у шима обязателен
`--feature-level=10_0` и нативные app-local MSVC-рантаймы, которых в
универсальной ассоциации нет.

## Результат HDS

```sh
cd ~/WinTest
source ~/Projects/Wine/wine-env.sh
wine HDS.exe --console a.bin b.bin -y -q
```

Лог `HDS-Logs_07-11-2026_11-01-24.txt`:

```
HEX Differences Searcher 1.0.2
Time: Sat Nov  7 11:01:24 2026
File 1: a.bin
Size of File 1: 8
File 2: b.bin
Size of File 2: 8

SEARCH FOR DIFFERENCES...
0x4 >> 41 >> 42
1 DIFFERENCES FOUND.
```

То есть `wcrtomb_s` больше не «unimplemented»: лог пишется полностью,
отличия считаются. Исходная проблема Wine 4.0 решена переходом на Wine 10.

GUI тоже работает: `winecfg` и окно `HEX Differences Searcher 1.0.2`
(712x406) открываются на `:1` и видны в VNC.

## Известные мелочи

- `wine notepad` и `wine explorer` из этого пакета падают с page fault;
  `winecfg` и HDS GUI при этом работают. Для задачи это не критично.
- HDS в консольном режиме возвращает код 255, но лог и результат корректны.
- `Win32Craft_ARM` — это UWP→Win32-прослойка для старых ARM32-сборок MCBE,
  а не отдельная игра. Пока не помещено ни само приложение, ни данные.
  Подготовлена папка `/home/MaxRM/WinTest/Win32Craft` и скрипт
  `run-win32craft.sh`; туда нужно положить `Win32Craft_ARM.exe`, файлы MCBE
  и FMOD, затем запустить `./run-win32craft.sh`.
  Проверка Wine 10: `combase.dll` экспортирует `RoInitialize`,
  `RoGetActivationFactory`, `WindowsCreateString` и т.д.; API-set
  `api-ms-win-core-winrt-*` отсутствуют, но Win32Craft подставляет их своими
  `.def`-заглушками. Основной риск — D3D11 и скорость: под Xvnc рендер
  программный.
- VNC-разрешение 2179x1080 (из профиля Linux Deploy). При желании можно
  уменьшить до 1280x720 для скорости: поправить строку запуска `vncserver`
  в `/data/local/tmp/start-debian13.sh`.

## X-стек: Xvfb + llvmpipe + x11vnc

TightVNC `Xvnc` не подходит: в нём нет GLX/RENDER/XFIXES, из-за этого падал
D3D11. Рабочая схема — обычный `Xvfb` с расширениями и `x11vnc` поверх:

```sh
Xvfb :1 -screen 0 2179x1080x24 \
  +extension GLX +extension RENDER +extension XFIXES +extension Composite \
  -ac -nolisten tcp -noreset
su - MaxRM -c 'DISPLAY=:1 XAUTHORITY=$HOME/.Xauthority startlxde'
su - MaxRM -c 'DISPLAY=:1 XAUTHORITY=$HOME/.Xauthority \
  x11vnc -display :1 -rfbauth $HOME/.vnc/passwd -rfbport 5901 \
  -forever -shared -noxdamage -noshm -bg -o /tmp/x11vnc.log'
```

Готовый скрипт: `/tmp/restart-x-inner.sh` внутри chroot (копия —
`/data/local/mnt/tmp/restart-x-inner.sh`). Он убивает старые X-серверы,
чистит `/tmp/.X1-lock` и `/tmp/.X11-unix/X1`, поднимает Xvfb, LXDE и x11vnc.

- VNC: `<phone-ip>:5901`, пароль задан локально (в публичной копии скрыт).
- Резерв через ADB: `adb forward tcp:5901 tcp:5901` → `localhost:5901`.
- `glxinfo -B` показывает llvmpipe, OpenGL 4.5, GLX/RENDER/XFIXES/DAMAGE/Present.

Буфер обмена: `x11vnc` синхронизирует X CLIPBOARD с RFB cut-text по
умолчанию. В `lxterminal` вставка переназначена на **Ctrl+V**
(`paste_accel=<Primary>v`), копирование — `Ctrl+Shift+C`; см. раздел
«Ctrl+V в терминале» выше. В GUI/Wine-приложениях работает обычный Ctrl+V
при условии, что VNC-клиент отдаёт свой буфер в сессию.

## Аппаратный дисплей `:2` (labwc + Mesa KGSL + wayvnc)

`:1` (Xvfb) полностью программный: llvmpipe рисует, x11vnc снимает кадры через
`XGetImage`. На этом телефоне в ядре нет SysV SHM (`shmget` → `ENOSYS`),
поэтому `XGetImage` кадра 1280×720 стоит 250–350 мс — потолок x11vnc ~4–5
обновлений/с. Поэтому игры вынесены на отдельный аппаратный дисплей.

Схема:

```
:1  Xvfb + llvmpipe + LXDE          -> x11vnc 5901   (рабочий стол, софт)
:2  labwc (headless) + Mesa KGSL
    + Xwayland + Mesa 27 (kgsl)     -> wayvnc 5902   (игры, железо)
```

`wayvnc` забирает кадры через `wlr-screencopy` (dmabuf), без `XGetImage`,
поэтому не упирается в отсутствие SHM.

Запуск/проверка (идемпотентно, можно вызывать сколько угодно раз):

```sh
/usr/local/bin/display-up          # он же ~/start-displays.sh
HW_WIDTH=1280 HW_HEIGHT=720 display-up   # сменить режим
```

Скрипт поднимает Xvfb/x11vnc/labwc/Xwayland/wayvnc, при смене режима делает
`wlr-randr --custom-mode`, перезапускает wayvnc и Xwayland, проверяет, что
glamor не свалился на llvmpipe. По умолчанию **960×540**.

Важные грабли (все уже учтены в `display-up`):

- **wineserver кэширует размер X-экрана.** После смены режима надо
  `wineserver -k`, иначе игра продолжает считать экран старым (например,
  рисует 1272×660 при Xwayland 640×480).
- **Xwayland обязан получить KGSL-окружение** (`LD_LIBRARY_PATH`,
  `LIBGL_DRIVERS_PATH`, `MESA_LOADER_DRIVER_OVERRIDE=kgsl`,
  `MESA_DRI3_DISABLE_PRESENT_WAIT_FENCE=1`) и `-geometry`, совпадающий с
  режимом. Иначе он молча уходит в llvmpipe (`Refusing to try glamor on
  llvmpipe`).
- **wayvnc завершается при изменении размера вывода** («Display has been
  resized but client does not support resizing»), поэтому режим меняется до
  старта wayvnc, либо wayvnc перезапускается после.
- `MESA_DRI3_DISABLE_PRESENT_WAIT_FENCE=1` убирает зависание
  `loader_dri3_wait_gl` → `xcb_wait_for_special_event` на KGSL.

Замеры (MCPE 0.10.4.40, `--feature-level=10_0`, захват указателя выключен,
после фикса command stream — см. ниже):

| Режим `:2` | Рендер игры | VNC raw | VNC ZRLE |
|---|---|---|---|
| 640×480 | ~150 fps | — | — |
| **960×540** | **287 fps** (замер на 150 с) | **19.5 upd/s** | **16.9 upd/s** |
| 1280×720 | 137 fps | ~10 upd/s | ~10 upd/s |

По умолчанию **960×540**: при 1280×720 картинка крупнее, но и рендер, и VNC
заметно медленнее, а 640×480 на телефоне неудобен.

### Зависание рендера: потерянное пробуждение в command stream wined3d

Раньше игра через 15–110 с замирала: кадры в `win32craft.log`
(`frames(+0xF0)=`) переставали расти, картинка на `:2` становилась
байт-в-байт неизменной, но процесс и цикл сообщений жили, ввод обрабатывался.
Зависание воспроизводилось на 640×480 и 960×540, с VNC-клиентом и без него,
и **никогда** на `:1` (llvmpipe).

Диагностика (gdb + `llvm-addr2line` по DWARF в `wined3d.dll`):

- поток рендера крутится в userspace на 100 % CPU (не в syscall) —
  `wined3d_cs_mt_finish` → `wined3d_pause` (`cs.c`);
- поток `wined3d_cs` спит в `wined3d_cs_wait_event` (`cs.c`), хотя очередь
  команд непустая;
- вызовы — `NtYieldExecution`/`sched_yield` в цикле ожидания.

То есть классическое **потерянное пробуждение**: очередь непустая, а поток
command stream уже спит и его больше никто не будит. На ARM (слабая модель
памяти + KGSL) гонка проявляется гораздо чаще, чем на x86.

Фикс в `dlls/wined3d/cs.c`: если `wined3d_cs_mt_finish` прокрутился больше
`WINED3D_PAUSE_SPIN_COUNT` раз, он раз в ~1 мс повторно будит поток
command stream (`NtAlertThreadByThreadId`, иначе `SetEvent`). Лишнее
пробуждение безвредно: поток просто перепроверит очередь. Фикс не меняет
поведение Wine по умолчанию и не зависит от игры/разрешения — это
исправление гонки, а не обход.

Результат: 5-минутный прогон с живым VNC-клиентом, кадры растут
непрерывно, зависаний нет (подробности в таблице выше).

## Захват указателя и закрытие окон по VNC

Wine при активации окна делает `XGrabPointer`, из-за чего курсор нельзя
вывести за пределы окна, а кнопка закрытия в VNC недоступна. Добавлен
**опциональный** патч: при `WINE_X11_NO_POINTER_GRAB=1` Wine не вызывает
`XGrabPointer` и **не мапит clip-окно**. Второе важно: clip-окно — это
InputOnly-окно на весь прямоугольник захвата; если оставить его
замапленным, оно перехватывает клики у всех окон под ним, включая
декорации оконного менеджера (кнопки «свернуть/развернуть/закрыть»).
По умолчанию патч выключен — поведение стокового Wine не меняется.

```sh
export WINE_X11_NO_POINTER_GRAB=1    # включить
export WINE_X11_NO_POINTER_GRAB=0    # явно выключить
```

То же через реестр: `HKCU\Software\Wine\X11 Driver` → `NoPointerGrab` (строка
`"1"`). Переменная окружения имеет приоритет. `~/start-mcpe-hw.sh`,
`~/start-mcbe128.sh` и `/usr/local/bin/wine11-open` включают его сами
(значение можно переопределить).

Проверено: один клик по «X» в заголовке MCBE закрывает игру штатно
(`message loop ended (WM_QUIT)`, `Win32Bootstrap returning 0`); `Alt+F4`
работает так же.

Отдельно исправлена устойчивость `winex11.drv` к «протухшему» clip-окну:
идентификатор окна хранится в свойстве desktop-окна, и если desktop-окно
пересоздаётся (например, при запуске второго приложения в том же
`wineserver`), в свойстве остаётся мёртвый id. Первый же `X_UnmapWindow`
на нём даёт фатальную `BadWindow`, и процесс Wine завершается. Теперь
`init_clip_window()` проверяет окно через `XGetWindowAttributes` +
`X11DRV_expect_error`, стирает протухшее свойство, а само clip-окно
пересаживается в root-окно, а не в desktop-окно. Благодаря этому MCBE
запускается, даже когда в том же префиксе уже работает MCPE.

Аварийное закрытие зависшего окна/игры:

```sh
wine-kill          # закрывает активное окно, затем убивает его PID
```

В LXDE повешен хоткей **Ctrl+Alt+End** → `wine-kill`. Важно: `xdotool
windowclose` сам по себе оставляет процессы Wine живыми, поэтому
`wine-kill` после закрытия окна добивает PID (`SIGTERM`, затем `SIGKILL`).

## Локальный патч Wine 11.22

Все локальные изменения лежат в
[`wine11-arm32-local.patch`](wine11-arm32-local.patch) — 10 файлов, 23 хунка:

- `dlls/winex11.drv/mouse.c` — mouse-as-touch (`WM_POINTER`), отключение
  `XGrabPointer` и отказ от маппинга clip-окна в режиме `NoPointerGrab`;
- `dlls/winex11.drv/x11drv_main.c` — чтение `WINE_X11_NO_POINTER_GRAB` и
  `NoPointerGrab` из реестра;
- `dlls/winex11.drv/window.c` — `X11DRV_SetCapture` без захвата; проверка
  живости clip-окна и его перенос в root-окно (иначе фатальный `BadWindow`
  при пересоздании desktop-окна);
- `dlls/winex11.drv/x11drv.h` — `extern BOOL no_pointer_grab`;
- `dlls/wined3d/cs.c` — повторное пробуждение потока command stream, если
  `wined3d_cs_mt_finish` долго ждёт опустошения очереди (лечение зависания
  рендера, см. раздел про `:2`);
- `libs/vkd3d/libs/vkd3d-shader/{hlsl.h,hlsl.c,hlsl.y,hlsl_codegen.c,glsl.c}`
  — `CalculateLevelOfDetail(Unclamped)` в HLSL-фронтенде vkd3d.

Патч применяется к чистому `wine-11.22` через `patch -p1`. Фичи в
`winex11.drv` включаются только явно (`WINE_X11_NO_POINTER_GRAB`,
`WINE_X11_MOUSE_AS_TOUCH`), поведение по умолчанию не меняется; фикс в
`wined3d/cs.c` — это исправление гонки, он активен всегда и не привязан к
игре или разрешению. Это и есть содержимое будущей ветки в форке
`Max-RM/wine`.

## GPU: Adreno есть, но X/Wine его пока не используют

> Актуально: аппаратный путь уже работает на дисплее `:2` через Mesa 27
> (`kgsl`) + labwc + wayvnc — см. раздел выше. Ниже — история ранних попыток
> и почему `:1` (Xvfb) остаётся программным.

Проверено на телефоне:

- ядро отдаёт `/dev/dri/card0` и `renderD128` (`DRIVER=msm_drm`,
  `qcom,mdss_mdp`) и `/dev/kgsl-3d0` (Adreno, права 666);
- armhf-Mesa 25.0.7 **уже содержит** `msm_dri.so` и `kgsl_dri.so`,
  `libdrm-freedreno1` установлен;
- но `EGL_PLATFORM=surfaceless GALLIUM_DRIVER=kgsl eglinfo` и то же с `msm`
  падают с `failed to create dri2 screen`; без `GALLIUM_DRIVER` Mesa
  выбирает `kms_swrast`/llvmpipe;
- в собранном Wine 11 `winex11.drv` использует GLX, EGL-пути нет;
- `Xvfb` — программный GLX, поэтому `glxinfo` всегда показывает llvmpipe.

Вывод: пересборка ARM64-драйверов под ARM32 сама по себе ускорения не даст —
драйверы уже есть, проблема в display/EGL-пути и в том, что Wine ходит через
GLX. Реальные направления:

1. **Дешёвое:** уменьшить разрешение Xvfb и включить у `x11vnc` DAMAGE/SHM
   вместо `-noxdamage -noshm` — это снимет нагрузку с CPU и VNC.
2. **Аппаратное:** `libhybris` + 32-битные Adreno-блобы
   (`/vendor/lib/egl/libEGL_adreno.so`, `libGLESv2_adreno.so`) + EGL/GLES-путь
   в Wine. Это отдельный большой проект.
3. **Xorg на DRM** (`card0`) — упирается в DRM-master, который держит
   Android SurfaceFlinger.

## Geometry Dash (Win32Craft ARM32) — работает

Главная причина краха — встроенный `msvcr110` Wine 10 на ARM32. С родными
MSVC-рантаймами из папки игры всё запускается:

```sh
export WINEDLLOVERRIDES="mscoree,mshtml=;msvcr110=n;msvcp110=n"
cd ~/WinTest/GeometryDash_1.0.0.0_ARM32_Win32Craft
wine gd_host.exe
```

В логе `gd_host.log`: `D3D11 device created, feature level 0xb100`, затем
непрерывные `Draw #N hr=0x0`; кадр `gd_frame.bmp` (480x800) содержит
загрузочный экран Geometry Dash.

Причина: в Wine 10 `dlls/msvcrt/cxx.h` включает `RTTI_USE_RVA` для всех
не-i386, включая ARM32, а MSVC ARM RTTI использует абсолютные адреса.
В Wine 11 это исправлено (`#ifndef _WIN64 #undef RTTI_USE_RVA`), поэтому
после сборки Wine 11 можно вернуться к встроенным CRT.

## REDCON и MCPE 0.10.4

- **REDCON** с родными `msvcr120_app=n;msvcp120_app=n` проходит
  `__GetPlatformExceptionInfo` и доходит до `OnLaunched`. Дальше упирается в
  `Windows.Globalization.ApplicationLanguages` (фейковый WinRT Win32Craft
  возвращает `REGDB_E_CLASSNOTREG`, реальный — `0x80040150`) и
  `combase.SetRestrictedErrorInfo`. Под Wine 11 ещё не перепроверялся.
- **MCPE 0.10.4.40 под Wine 11.22 работает** — см. следующий раздел.

## MCPE 0.10.4.40 под Wine 11 — работает

Запуск (уже установленный скрипт):

```sh
su - MaxRM -c 'nohup /home/MaxRM/start-mcpe11.sh >/tmp/mcpe11-run.log 2>&1 &'
```

`/home/MaxRM/start-mcpe11.sh`:

```sh
#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/MaxRM/.Xauthority
export WINEPREFIX=/home/MaxRM/.wine11
export WINEARCH=win32
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml=;msvcr120_app=n;msvcp120_app=n;vccorlib120_app=n"
export PATH=/home/MaxRM/opt/wine11/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TMPDIR=/tmp
cd /home/MaxRM/WinTest/Minecraft_PE_0.10.4.40_ARM32_Win32Craft || exit 1
exec wine Win32Craft.0.10.4-arm32.exe --feature-level=10_0 "$@"
```

Результат: `StartMenuScreen@Touch`, `renderEnabled=1`, 19 draw calls на кадр,
13–20 FPS (42–64 мс/кадр), без исключений. `--trace-game-state` показывает
смену экранов и вызовы отрисовки.

Для работы MCPE понадобились три вещи, которых не было в Wine 10:

### 1. `ThreadPoolTimer` (WinRT)

Win32Craft-шим использует `Windows.System.Threading.ThreadPoolTimer` для
`DispatcherTimer`. В Wine 11 эта WinRT-часть отсутствовала — реализована
вручную в `dlls/combase`. Для функциональной корректности (а не
производительности) на каждый таймер создаётся отдельный поток:
`CreateEvent` + `CreateThread` + `WaitForSingleObject`, а не
`CreateTimerQueueTimer`. После этого таймеры MCPE тикают ~50 раз в секунду.

### 2. Include-файлы шейдеров (`d3dcompiler`)

MCPE компилирует `data/shaders/dx11/color_uv.vertex.hlsl` с
`D3D_COMPILE_STANDARD_FILE_INCLUDE`. Wine-овский обработчик искал только
последний `\`, поэтому подставлял текущий каталог вместо каталога шейдера,
не открывал `ShaderConstants.fxh` и возвращал `E_FAIL` (`E4002: Failed to
open`).

Патч: [`patches/d3dcompiler-include-forward-slash.patch`](patches/d3dcompiler-include-forward-slash.patch).
Он принимает и `/`, и `\`, и дополнительно пробует голое имя include.
`d3dcompiler_47` собирается из того же `compiler.c` через `PARENTSRC`,
поэтому патч чинит обе DLL.

### 3. Звук: молчаливое ALSA-устройство

Без звукового endpoint `FAudio_OpenDevice` возвращал ошибку, после чего
`FAudio_platform_win32.c` вызывал `IMMDevice_Activate(NULL, ...)` и падал в
`XAudio2_8.dll+0x14BE4`. Лечится файлом `/home/MaxRM/.asoundrc`:

```
pcm.!default {
    type null
}
```

С ним проба XAudio2 проходит (`status=1 hr=0`), и асинхронная загрузка MCPE
завершается.

### Почему `--feature-level=10_0`

По умолчанию шим ограничивает уровень фич 9_1, и игра компилирует
`vs_4_0_level_9_1`. vkd3d при этом выдаёт SM4-байткод, который wined3d
отвергает на FL9_1. С `--feature-level=10_0` игра компилирует `vs_4_0`/
`ps_4_0`, и всё работает.

Важно: **нельзя** добавлять `ucrtbase=n`/`vcruntime140=n` — Wine-собственные
DLL (`winex11`, `explorer`) импортируют `ucrtbase`, без него драйвер окна не
загружается, `CreateWindowExW` возвращает NULL, а `GetLastError` остаётся
1400. Нужны только app-local нативные MSVC-рантаймы
(`msvcr120_app`, `msvcp120_app`, `vccorlib120_app`).

## MCBE 1.2.8 (Win32Craft ARM32) — работает

Запуск (launcher уже установлен):

```sh
su - MaxRM -c 'nohup /home/MaxRM/start-mcbe128.sh >/tmp/mcbe128.out 2>&1 &'
```

`/home/MaxRM/start-mcbe128.sh`:

```sh
#!/bin/bash
export DISPLAY="${DISPLAY:-:1}"
export XAUTHORITY=/home/MaxRM/.Xauthority
export WINEPREFIX=/home/MaxRM/.wine11
export WINEARCH=win32
export WINEDEBUG="${WINEDEBUG:--all}"
export WINE_X11_NO_POINTER_GRAB=1   # WM получает клики по заголовку (VNC)
export WINEDLLOVERRIDES="mscoree,mshtml=;vccorlib140=n;msvcp140=n;vcruntime140=n;concrt140=n"
export PATH=/home/MaxRM/opt/wine11/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TMPDIR=/tmp
cd /home/MaxRM/WinTest/Minecraft_1.2.8.0_ARM32_Win32Craft || exit 1
exec wine Win32Craft.1.2.8-arm32.exe --feature-level=10_0 "$@"
```

Проверено: главное меню, экран миров, создание мира и работа в мире — без
исключений (`win32craft.log` без `unhandled exception`).

Окно закрывается штатно: клик по «X» в заголовке или `Alt+F4` →
`message loop ended (WM_QUIT)`, `Win32Bootstrap returning 0`. Для этого в
launcher'е включён `WINE_X11_NO_POINTER_GRAB=1` (см. раздел про захват
указателя): без него Wine забирает указатель себе, и клики по заголовку не
доходят до оконного менеджера. Благодаря фиксу протухшего clip-окна MCBE
запускается и тогда, когда в том же префиксе уже работает MCPE.

### Причина №1: встроенный `vccorlib140` Wine

Игра везёт с собой настоящие MSVC-рантаймы ARM
(`vccorlib140.dll`, `msvcp140.dll`, `vcruntime140.dll`, `concrt140.dll`,
`ucrtbase.dll` + `api-ms-win-*`), но Wine подсовывал свои встроенные DLL.
Встроенная заглушка `vccorlib140` падала в `SpeechSynthesizer` (page fault).
Лечится форсированием app-local версий:

```sh
WINEDLLOVERRIDES="mscoree,mshtml=;vccorlib140=n;msvcp140=n;vcruntime140=n;concrt140=n"
```

`ucrtbase=n` и `vcruntime140=n` для Wine-собственных DLL добавлять нельзя —
см. предупреждение в разделе MCPE 0.10.4.40.

### Причина №2: vkd3d не умел `CalculateLevelOfDetail`

После фикса рантайма игра падала уже на компиляции шейдера:

```
data/shaders/hlsl/util.fxh:8: E5005: Method 'CalculateLevelOfDetailUnclamped'
is not defined on type 'Texture2D<float4>'.
D3DCompile #2 FAILED ... HRESULT 0x80004005
unhandled exception 0xc0000005 at 009B8F2A
```

`D3DCompile` реализован в Wine через vkd3d (`d3dcompiler_47` импортирует
`vkd3d_D3DCompile2VKD3D` из `wined3d.dll`). В HLSL-фронтенде vkd3d не было
метода `CalculateLevelOfDetail(Unclamped)`, игра не проверяла ошибку
компиляции и разыменовывала null.

Реализовано **generic-фиксом в vkd3d**, без правок шейдеров игры:

- `hlsl.h` — `HLSL_RESOURCE_LOD`, флаг `lod_unclamped` в
  `hlsl_resource_load_params` и `hlsl_ir_resource_load`;
- `hlsl.y` — `CalculateLevelOfDetail` / `CalculateLevelOfDetailUnclamped`
  в `texture_methods[]` (`add_calculate_lod_method_call`);
- `hlsl_codegen.c` — эмиссия `VSIR_OP_LOD` (бэкенды SPIR-V и tpf уже её
  поддерживали, не хватало только фронтенда);
- `glsl.c` — эмиссия `textureQueryLod()`; `.y` — unclamped LOD,
  clamped получается как `clamp(..., 0.0, float(textureQueryLevels(s)-1))`,
  компонент выбирается swizzle'ом ресурса (0 — clamped, 1 — unclamped).

Патч: [`patches/vkd3d-calculate-lod.patch`](patches/vkd3d-calculate-lod.patch)
(отдельный diff для апстрима; уже включён в `wine11-arm32-local.patch`,
применять нужно что-то одно).

### Производительность (замерено)

| Сцена | Время кадра | FPS |
|---|---|---|
| Главное меню | 65–92 мс | 9–10 |
| В мире, llvmpipe, 1280×720 | 168–252 мс | 3.5–3.8 |

Методика: собственный heartbeat игры
(`ARM32 heartbeat: ... frames done=N (+M in the last 30 s)`), 10 окон подряд:
3.47–3.80 FPS, среднее **3.68 FPS**; среднее с момента старта цикла — 5.19 FPS
(включает более быстрые кадры меню).

Это дисплей `:1` — Xvfb + llvmpipe, то есть **программный** рендер.
Аппаратный `:2` (KGSL, 960×540) для MCBE ещё не замерялся.

### Мышь по VNC

Курсор «прилипает» к центру окна игры. Это ограничение VNC-клиентов
(TightVNC, AnyDesk, RustDesk), а не Wine: игра перехватывает указатель и
центрирует его для управления камерой, а VNC передаёт абсолютные координаты.
На реальном оборудовании с обычной мышью всё работает нормально.

## Wine 11.22 armhf: сборка

Собрано нативно в Debian 13 armhf:

- PE-компилятор: Debian `clang` 19 + `lld` + sysroot llvm-mingw
  (`/usr/armv7-w64-mingw32`, заголовки и `libclang_rt.builtins-arm.a`).
- Обёртка `/home/MaxRM/Projects/Wine/toolchain/bin/armv7-w64-mingw32-clang`:

```sh
#!/bin/sh
exec /usr/bin/clang --target=armv7-windows-gnu -march=armv7-a -mfpu=neon \
  -fuse-ld=lld -rtlib=compiler-rt -stdlib=libc++ \
  -Wno-unused-command-line-argument "$@" -lc++ -lc++abi -lunwind -lgcc
```

- `configure` (out-of-tree, `/home/MaxRM/Projects/wine-11.22-build`):

```sh
PATH=/home/MaxRM/Projects/Wine/toolchain/bin:$PATH \
../wine-11.22/configure --prefix=/home/MaxRM/opt/wine11 \
  --enable-archs=arm --with-mingw=llvm-mingw --disable-tests \
  CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0"
```

- `make -j6` (nproc=7, RAM 7.5 ГБ).
- `-mfpu=neon` обязателен: без него падает сборка
  `libs/ffmpeg/libavutil/arm/float_dsp_neon.S`.
- `-fuse-ld=lld` обязателен в обёртке: `winegcc` сам его не передаёт, иначе
  `ld: unrecognised emulation mode: thumb2pe`.
- `-lgcc` — своя `libgcc.a` с `__gnu_h2f_ieee`/`__gnu_f2h_ieee`
  ([`libgcc-arm-half.c`](libgcc-arm-half.c)), иначе не линкуются
  `colorcnv.dll` и всё, что тянет ffmpeg.
- `lld-link` должен быть в `PATH`:
  `ln -sfn /usr/lib/llvm-19/bin/lld-link /usr/local/bin/lld-link`. Иначе
  winebuild падает с вводящим в заблуждение
  `error: winebuild : No such file or directory`.
- Патч [`patches/winebuild-arm32-resources.patch`](patches/winebuild-arm32-resources.patch)
  обязателен: без него линковка `shell32.dll` и других ресурсоёмких DLL
  падает на 32-битном хосте из-за `mmap` всего `.res` на каждый `.incbin`
  (см. `BUILD-WINE11.md`).
- Подробности и инкрементальная пересборка — в
  [`BUILD-WINE11.md`](BUILD-WINE11.md). Там же раздел «Откуда исходники»:
  ссылка на тарбол `wine-11.22.tar.xz`, git-тег `wine-11.22` и список
  всех локальных патчей для своей ветки.

## Что дальше

1. Довести `:2` до повседневного использования: оставить LXDE на `:1` или
   перенести рабочий стол в rootful Xwayland `:2` (один быстрый дисплей вместо
   двух). Решение за пользователем.
2. ~~Зависание MCPE на `:2`~~ — **починено** (потерянное пробуждение в
   command stream wined3d, патч в `dlls/wined3d/cs.c`). Осталось проверить,
   не стало ли 640×480 быстрее по VNC, и при желании выбрать его дефолтом.
3. ~~MCBE 1.2.8: воспроизвести краш с `--feature-level=10_0`, снять лог/трейс,
   починить.~~ — **починено**: app-local MSVC-рантайм + поддержка
   `CalculateLevelOfDetail` в vkd3d; игра доходит до мира. Осталось замерить
   FPS на аппаратном `:2` (KGSL) и при желании поиграть с разрешением.
   MCPE 0.10.4.40 при этом остаётся рабочим.
4. HDS работает, включая drag-n-drop; отсутствует только анимация
   двух синих прямоугольников-разделителей — косметика.
5. REDCON: под Wine 11 ещё не перепроверялся (упирался в WinRT
   `ApplicationLanguages`/`SetRestrictedErrorInfo`).
6. Для Tab 2 GTP5110 переносить этот же armhf-rootfs/Wine 11; проверить
   объём RAM (1 ГБ) и версию ядра.

