#!/usr/bin/env bats

@test "It should install Redis " {
  run redis-server --version
  [[ "$output" =~ "2.8.9"  ]]
}

@test "It should install Redis to /usr/local/bin/redis-server" {
  test -x /usr/local/bin/redis-server
}
