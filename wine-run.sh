#!/bin/bash
# Запуск программы в Wine ARM32 с окружением из этой папки.
#   ./wine-run.sh apps/putty32.exe
#   ./wine-run.sh cmd
#   ./wine-run.sh winecfg
DIR=$(dirname "$(readlink -f "$0")")
. "$DIR/wine-env.sh"

if [ $# -eq 0 ]; then
  echo "usage: $0 <exe|builtin> [args...]"
  echo "example: $0 winecfg"
  exit 1
fi

exec wine "$@"
