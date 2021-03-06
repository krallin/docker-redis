#!/bin/bash
set -o errexit


# shellcheck disable=SC1091
. /usr/bin/utilities.sh


ARGUMENT_FILE="${CONFIG_DIRECTORY}/arguments"
DUMP_FILENAME="/tmp/dump.rdb"
DEFAULT_PORT=6379


start_server() {
  touch "$ARGUMENT_FILE" # don't crash and burn if initialize wasn't called.
  if [ -n "$MAX_MEMORY" ]; then
    echo "--maxmemory-policy allkeys-lru" >> "$ARGUMENT_FILE"
    echo "--maxmemory ${MAX_MEMORY}" >> "$ARGUMENT_FILE"
  fi
  # shellcheck disable=SC2046
  exec redis-server /etc/redis.conf --port "${PORT:-${DEFAULT_PORT}}" --dir "$DATA_DIRECTORY" $(cat "$ARGUMENT_FILE")
}


if [[ "$1" == "--initialize" ]]; then
  echo "--requirepass $PASSPHRASE" > "$ARGUMENT_FILE"

elif [[ "$1" == "--initialize-from" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/redis --initialize-from redis://..." && exit

  parse_url "$2"

  # shellcheck disable=SC2154
  {
    echo "--requirepass $password" > "$ARGUMENT_FILE"
    echo "--slaveof $host ${port:-${DEFAULT_PORT}}" >> "$ARGUMENT_FILE"
    echo "--masterauth $password" >> "$ARGUMENT_FILE"
  }

elif [[ "$1" == "--client" ]]; then
  [ -z "$2" ] && echo "docker run -it aptible/redis --client redis://..." && exit
  parse_url "$2"
  shift
  shift
  redis-cli -h "$host" -p "${port:-${DEFAULT_PORT}}" -a "$password" "$@"

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/redis --dump redis://... > dump.rdb" && exit
  parse_url "$2"
  redis-cli -h "$host" -p "${port:-${DEFAULT_PORT}}" -a "$password" --rdb "$DUMP_FILENAME"
  #shellcheck disable=SC2015
  [ -e /dump-output ] && exec 3>/dump-output || exec 3>&1
  cat "$DUMP_FILENAME" >&3
  rm "$DUMP_FILENAME"

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/redis --restore redis://... < dump.rdb" && exit
  parse_url "$2"
  #shellcheck disable=SC2015
  [ -e /restore-input ] && exec 3</restore-input || exec 3<&0
  cat > "$DUMP_FILENAME" <&3
  rdb --command protocol "$DUMP_FILENAME" | redis-cli -h "$host" -p "${port:-${DEFAULT_PORT}}" -a "$password" --pipe
  rm "$DUMP_FILENAME"

elif [[ "$1" == "--readonly" ]]; then
  echo "This image does not support read-only mode. Starting database normally."
  start_server

else
  start_server

fi
