# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/redis

Redis, on top of Ubuntu 12.10.

## Installation and Usage

    docker pull quay.io/aptible/redis
    docker run quay.io/aptible/redis

### Specifying a password at runtime

    docker run -P quay.io/aptible/redis sh -c "echo requirepass password >> /etc/redis.conf && /usr/local/bin/redis-server /etc/redis.conf"

## Available Tags

* `latest`: Currently Redis 2.8.7

## Tests

Tests are run as part of the `Dockerfile` build. To execute them separately within a container, run:

    bats test

## Deployment

To push the Docker image to Quay, run the following command:

    make release

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2014 [Aptible](https://www.aptible.com), [Frank Macreery](https://github.com/fancyremarker), and contributors.
