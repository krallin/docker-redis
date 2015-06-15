FROM quay.io/aptible/alpine

ENV DATA_DIRECTORY /var/db

# rdbtools is used for importing an RDB dump remotely.
RUN apk-install redis=2.8.21-r0 py-pip=1.5.6-r2 && pip install rdbtools
ADD templates/redis.conf /etc/redis.conf

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

VOLUME ["$DATA_DIRECTORY"]
EXPOSE 6379

ENV CONFIG_DIRECTORY /etc/redis
VOLUME ["$CONFIG_DIRECTORY"]
EXPOSE 6379

ADD run-database.sh /usr/bin/
ADD utilities.sh /usr/bin/
ENTRYPOINT ["run-database.sh"]
