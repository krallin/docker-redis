FROM quay.io/aptible/alpine

ENV DATA_DIRECTORY /var/db

RUN apk-install redis=2.8.17-r0
ADD templates/redis.conf /etc/redis.conf

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

VOLUME ["$DATA_DIRECTORY"]
EXPOSE 6379

ENV CONFIG_DIRECTORY /etc/redis
VOLUME ["$CONFIG_DIRECTORY"]

ADD run-database.sh /usr/bin/
ENTRYPOINT ["run-database.sh"]

EXPOSE 6379
