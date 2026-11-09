# Переменные окружения Wine (подключать через `source`).
# Используется wine-run.sh и ручными запусками:
#   source /home/MaxRM/Projects/Wine/wine-env.sh

export WINEPREFIX=/home/MaxRM/Projects/Wine/prefix
export WINEARCH=win32

# VNC-сервер Linux Deploy (Xtightvnc :0). Нужен только для GUI-программ.
export DISPLAY=${DISPLAY:-:0}
export XAUTHORITY=${XAUTHORITY:-/home/MaxRM/.Xauthority}

# Не пытаться ставить wine-mono/wine-gecko при создании префикса.
export WINEDLLOVERRIDES="mscoree,mshtml="
