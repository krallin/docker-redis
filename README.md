# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/redis

[![Docker Repository on Quay.io](https://quay.io/repository/aptible/redis/status)](https://quay.io/repository/aptible/redis)

Redis on Docker

## Installation and Usage

    docker pull quay.io/aptible/redis

This is an image conforming to the [Aptible database specification](https://support.aptible.com/topics/paas/deploy-custom-database/). To run a server for development purposes, execute

    docker create --name data quay.io/aptible/redis
    docker run --volumes-from data -e PASSPHRASE=pass quay.io/aptible/redis --initialize
    docker run --volumes-from data -P quay.io/aptible/redis

The first command sets up a data container named `data` which will hold the configuration and data for the database. The second command creates a Redis instance with the passphrase of your choice. The third command starts the database server.

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

Copyright (c) 2015 [Aptible](https://www.aptible.com) and contributors.

[<img src="https://s.gravatar.com/avatar/f7790b867ae619ae0496460aa28c5861?s=60" style="border-radius: 50%;" alt="@fancyremarker" />](https://github.com/fancyremarker)
