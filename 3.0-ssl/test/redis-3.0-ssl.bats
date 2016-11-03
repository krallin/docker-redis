@test "It should install Redis 3.0" {
  run redis-server --version
  [[ "$output" =~ "3.0.7"  ]]
}

@test "It should run with REDIS_SSL set" {
  [[ -n "$REDIS_SSL" ]]
}
