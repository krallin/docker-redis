# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/redis

[![Docker Repository on Quay.io](https://quay.io/repository/aptible/redis/status)](https://quay.io/repository/aptible/redis)

Redis on Docker

## Installation and Usage

    docker pull quay.io/aptible/redis
    docker run quay.io/aptible/redis

### Specifying a password at runtime

    docker run -P quay.io/aptible/redis sh -c "echo requirepass password >> /etc/redis.conf && /usr/local/bin/redis-server /etc/redis.conf"

## Available Tags

* `latest`: Currently Redis 2.8.17

## Tests

Tests are run as part of the `Dockerfile` build. To execute them separately within a container, run:

    bats test

## Deployment

To push the Docker image to Quay, run the following command:

    make release

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2014 [Aptible](https://www.aptible.com), [Frank Macreery](https://github.com/fancyremarker), and contributors.

[<img src="https://s.gravatar.com/avatar/f7790b867ae619ae0496460aa28c5861?s=60" style="border-radius: 50%;" alt="@fancyremarker" />](https://github.com/fancyremarker)
