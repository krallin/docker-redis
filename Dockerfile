FROM quay.io/aptible/ubuntu:12.04

# Install latest stable Redis from source
RUN apt-get update
RUN apt-get -y install wget build-essential zlib1g-dev libssl-dev \
      libreadline6-dev libyaml-dev && cd /tmp && \
      wget -q http://download.redis.io/redis-stable.tar.gz && \
      tar xvzf redis-stable.tar.gz && \
      cd redis-stable && make install && mkdir -p /var/db/redis && \
      cd .. && rm -rf redis-stable

ADD templates/redis.conf /etc/redis.conf

VOLUME ["/var/db/redis"]
EXPOSE 6379

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

CMD ["/usr/local/bin/redis-server /etc/redis.conf"]
