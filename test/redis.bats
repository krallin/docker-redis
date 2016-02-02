#!/usr/bin/env bats

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export OLD_CONFIG_DIRECTORY="$CONFIG_DIRECTORY"
  export DATA_DIRECTORY="/tmp/datadir"
  export CONFIG_DIRECTORY="/tmp/configdir"
  export DATABASE_PASSWORD="password12345"
  export DATABASE_URL="redis://:$DATABASE_PASSWORD@localhost/db"
  rm -rf "$DATA_DIRECTORY"
  mkdir -p "$DATA_DIRECTORY"
  rm -rf "$CONFIG_DIRECTORY"
  mkdir -p "$CONFIG_DIRECTORY"
}


teardown() {
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  export CONFIG_DIRECTORY="$OLD_CONFIG_DIRECTORY"
  unset OLD_DATA_DIRECTORY
  unset OLD_CONFIG_DIRECTORY
  unset DATABASE_URL
  stop_redis
}


start_redis () {
  PASSPHRASE="$DATABASE_PASSWORD" run-database.sh --initialize
  run-database.sh > "$BATS_TEST_DIRNAME/redis.log" &
  timeout 4 sh -c "while  ! grep 'ready to accept connections' '$BATS_TEST_DIRNAME/redis.log' ; do sleep 0.1; done"
}


stop_redis () {
  PID=$(pgrep redis-server) || return 0
  pkill redis-server
  while [ -n "$PID" ] && [ -e /proc/$PID ]; do sleep 0.1; done
}


@test "It should install Redis " {
  run redis-server --version
  [[ "$output" =~ "2.8.24"  ]]
}

@test "It should install Redis to /usr/local/bin/redis-server" {
  test -x /usr/local/bin/redis-server
}

@test "It should start Redis" {
  start_redis
  run-database.sh --client "$DATABASE_URL" SET test_key test_value
  run run-database.sh --client "$DATABASE_URL" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "test_value" ]]
}

@test "It should backup and restore" {
  # Load a key
  start_redis
  run-database.sh --client "$DATABASE_URL" SET test_key test_value
  run-database.sh --dump "$DATABASE_URL" > redis.dump
  stop_redis

  # Drop ALL the data!!!
  rm -rf "$DATA_DIRECTORY"
  mkdir "$DATA_DIRECTORY"

  # Restart. Data should be gone.
  start_redis
  run run-database.sh --client "$DATABASE_URL" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "" ]]

  # Restore. Data should be back.
  run-database.sh --restore "$DATABASE_URL" < redis.dump
  run run-database.sh --client "$DATABASE_URL" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "test_value" ]]
}
