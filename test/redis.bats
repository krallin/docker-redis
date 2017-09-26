#!/usr/bin/env bats

TEST_BASE_DIRECTORY="/tmp/test-root"

setup() {
  # Create a temporary dir structure for the test
  export DATA_DIRECTORY="${TEST_BASE_DIRECTORY}/data"
  export CONFIG_DIRECTORY="${TEST_BASE_DIRECTORY}/config"
  export STUNNEL_ROOT_DIRECTORY="${TEST_BASE_DIRECTORY}/stunnel"
  export SSL_CERTS_DIRECTORY="${TEST_BASE_DIRECTORY}/certs"
  mkdir -p "$DATA_DIRECTORY" "$CONFIG_DIRECTORY" "$STUNNEL_ROOT_DIRECTORY" "$SSL_CERTS_DIRECTORY"

  # Now, pick different ports to check that our image will accept those
  export REDIS_PORT="$(pick-free-port)"
  export SSL_PORT="$(pick-free-port)"

  if [[ "$REDIS_PORT" = "$SSL_PORT" ]]; then
    echo "Test precondition failed! REDIS_PORT = SSL_PORT = $REDIS_PORT"
    exit 1
  fi

  # Load our test CA as a trusted CA.
  cp "${BATS_TEST_DIRNAME}/ssl/ca.pem" "$SSL_CERTS_DIRECTORY"
  c_rehash "$SSL_CERTS_DIRECTORY"

  # Load our test certs
  export SSL_CERTIFICATE="$(cat "${BATS_TEST_DIRNAME}/ssl/server-cert.pem")"
  export SSL_KEY="$(cat "${BATS_TEST_DIRNAME}/ssl/server-key.pem")"

  export DATABASE_PASSWORD="password12345"

  export REDIS_DATABASE_URL="redis://:$DATABASE_PASSWORD@localhost"
  export REDIS_DATABASE_URL_FULL="redis://:$DATABASE_PASSWORD@localhost:${REDIS_PORT}"

  export SSL_DATABASE_URL="rediss://:$DATABASE_PASSWORD@localhost"
  export SSL_DATABASE_URL_FULL="rediss://:$DATABASE_PASSWORD@localhost:${SSL_PORT}"

  rm -rf "$DATA_DIRECTORY"
  mkdir -p "$DATA_DIRECTORY"
  rm -rf "$CONFIG_DIRECTORY"
  mkdir -p "$CONFIG_DIRECTORY"
}


teardown() {
  unset REDIS_DATABASE_URL
  stop_redis
  rm -r "$TEST_BASE_DIRECTORY"
}


start_redis () {
  PASSPHRASE="$DATABASE_PASSWORD" run-database.sh --initialize
  run-database.sh > "$BATS_TEST_DIRNAME/redis.log" &
  timeout 4 sh -c "while  ! grep 'accept connections' '$BATS_TEST_DIRNAME/redis.log' ; do sleep 0.1; done"
}


stop_redis () {
  PID="$(pidof supervisord)" || return 0
  kill -TERM "$PID"
  while [ -n "$PID" ] && [ -e /proc/$PID ]; do sleep 0.1; done
}

local_s_client() {
  echo OK | openssl s_client -connect localhost:"$@"
}

@test "It should install Redis to /usr/local/bin/redis-server" {
  test -x /usr/local/bin/redis-server
}

@test "It should support Redis connections" {
  start_redis
  run-database.sh --client "$REDIS_DATABASE_URL" SET test_key test_value
  run run-database.sh --client "$REDIS_DATABASE_URL_FULL" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "test_value" ]]
}

@test "It should support SSL connections" {
  start_redis
  run-database.sh --client "$SSL_DATABASE_URL" SET test_key test_value
  run run-database.sh --client "$SSL_DATABASE_URL_FULL" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "test_value" ]]
}

@test "It should not run two Redis instances" {
  start_redis
  run-database.sh --client "$REDIS_DATABASE_URL" SET test_key test_value
  run run-database.sh --client "$SSL_DATABASE_URL" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "test_value" ]]
}

@test "It should require SSL on the SSL port" {
  start_redis
  run run-database.sh --client "redis://:$DATABASE_PASSWORD@localhost:${SSL_PORT}/db" INFO
  [[ "$status" -eq 1 ]]
}

backup_restore_test() {
  local url="$1"

  run-database.sh --client "$url" SET test_key test_value
  run-database.sh --dump "$url" > redis.dump
  stop_redis

  # Drop ALL the data!!!
  rm -rf "$DATA_DIRECTORY"
  mkdir "$DATA_DIRECTORY"

  # Restart. Data should be gone.
  start_redis
  run run-database.sh --client "$url" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "" ]]

  # Restore. Data should be back.
  run-database.sh --restore "$url" < redis.dump
  run run-database.sh --client "$url" GET test_key
  [ "$status" -eq "0" ]
  [[ "$output" = "test_value" ]]
}

@test "It should backup and restore over the Redis protocol" {
  # Load a key
  start_redis
  backup_restore_test "$REDIS_DATABASE_URL"
}

@test "It should backup and restore over SSL" {
  # Load a key
  start_redis
  backup_restore_test "$SSL_DATABASE_URL"
}

export_exposed_ports() {
  REDIS_PORT_VAR="EXPOSE_PORT_$REDIS_PORT"
  export $REDIS_PORT_VAR=$REDIS_PORT

  SSL_PORT_VAR="EXPOSE_PORT_$SSL_PORT"
  export $SSL_PORT_VAR=$SSL_PORT
}

@test "It should return valid JSON for --discover and --connection-url" {
  run-database.sh --discover | python -c 'import sys, json; json.load(sys.stdin)'

  # We pretend that both ports are exposed. Depending on the image, only one will be used.
  # We separately test that the port makes sense.
  export_exposed_ports
  EXPOSE_HOST=localhost PASSPHRASE="$DATABASE_PASSWORD" DATABASE=db \
    run-database.sh --connection-url | python -c 'import sys, json; json.load(sys.stdin)'
}

@test "It should return a usable connection URL for --connection-url" {
  start_redis

  export_exposed_ports
  EXPOSE_HOST=localhost PASSPHRASE="$DATABASE_PASSWORD" DATABASE=db \
    run-database.sh --connection-url > "${TEST_BASE_DIRECTORY}/url"

  pushd "${TEST_BASE_DIRECTORY}"
  URL="$(python -c "import sys, json; print json.load(open('url'))['credentials'][0]['connection_url']")"
  popd

  [[ "$REDIS_DATABASE_URL_FULL" = "$URL" ]]
  run-database.sh --client "$URL" INFO

  pushd "${TEST_BASE_DIRECTORY}"
  URL="$(python -c "import sys, json; print json.load(open('url'))['credentials'][1]['connection_url']")"
  popd

  [[ "$SSL_DATABASE_URL_FULL" = "$URL" ]]
  run-database.sh --client "$URL" INFO
}

@test "stunnel allows TLS1.2" {
  start_redis
  run local_s_client "$SSL_PORT" -tls1_2
  [ "$status" -eq 0 ]
}

@test "stunnel allows TLS1.1" {
  start_redis
  run local_s_client "$SSL_PORT" -tls1_1
  [ "$status" -eq 0 ]
}

@test "stunnel allows TLS1.0" {
  start_redis
  run local_s_client "$SSL_PORT" -tls1
  [ "$status" -eq 0 ]
}

@test "stunnel disallows SSLv3" {
  start_redis
  run local_s_client "$SSL_PORT" -ssl3
  [ "$status" -ne 0 ]
}
