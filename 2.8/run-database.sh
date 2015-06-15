#!/bin/bash

. /usr/bin/utilities.sh
ARGUMENT_FILE="$CONFIG_DIRECTORY"/arguments
DUMP_FILENAME="/tmp/dump.rdb"

start_server()
{
  touch $ARGUMENT_FILE # don't crash and burn if initialize wasn't called.
  redis-server /etc/redis.conf --dir "$DATA_DIRECTORY" $(cat "$ARGUMENT_FILE")
}

if [[ "$1" == "--initialize" ]]; then
  echo "--requirepass "$PASSPHRASE"" > "$ARGUMENT_FILE"

elif [[ "$1" == "--client" ]]; then
  [ -z "$2" ] && echo "docker run -it aptible/redis --client redis://..." && exit
  parse_url "$2"
  redis-cli -h "$host" -p "${port:-6379}" -a "$password"

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/redis --dump redis://... > dump.rdb" && exit
  parse_url "$2"
  redis-cli -h "$host" -p "${port:-6379}" -a "$password" --rdb "$DUMP_FILENAME"
  cat "$DUMP_FILENAME"

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/redis --restore redis://... < dump.rdb" && exit
  parse_url "$2"
  cat > "$DUMP_FILENAME"
  rdb --command protocol "$DUMP_FILENAME" | redis-cli -h "$host" -p "${port:-6379}" -a "$password" --pipe

elif [[ "$1" == "--readonly" ]]; then
  echo "This image does not support read-only mode. Starting database normally."
  start_server

else
  start_server

fi
