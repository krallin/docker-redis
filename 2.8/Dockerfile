FROM quay.io/aptible/alpine

ENV REDIS_VERSION 2.8.24
ENV REDIS_SHA1SUM 636efa8b522dfbf7f3dba372237492c11181f8e0

ADD ./install-redis.sh /install-redis.sh
RUN /install-redis.sh

# rdbtools is used for importing an RDB dump remotely.
RUN apk-install py-pip && pip install rdbtools
ADD templates/redis.conf /etc/redis.conf

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

ENV DATA_DIRECTORY /var/db

VOLUME ["$DATA_DIRECTORY"]
EXPOSE 6379

ENV CONFIG_DIRECTORY /etc/redis
VOLUME ["$CONFIG_DIRECTORY"]
EXPOSE 6379

ADD run-database.sh /usr/bin/
ADD utilities.sh /usr/bin/
ENTRYPOINT ["run-database.sh"]
