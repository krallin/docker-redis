#!/bin/bash

ARGUMENT_FILE="$CONFIG_DIRECTORY"/arguments
if [[ "$1" == "--initialize" ]]; then
  echo "--requirepass "$PASSPHRASE"" > "$ARGUMENT_FILE"
  exit
fi

touch $ARGUMENT_FILE # don't crash and burn if initialize wasn't called.
redis-server /etc/redis.conf --dir "$DATA_DIRECTORY" $(cat "$ARGUMENT_FILE")
