FROM quay.io/aptible/ubuntu:12.10

# Install latest stable Redis from source
RUN apt-get update
RUN apt-get -y install wget build-essential zlib1g-dev libssl-dev \
      libreadline6-dev libyaml-dev && cd /tmp && \
      wget -q http://download.redis.io/redis-stable.tar.gz && \
      tar xvzf redis-stable.tar.gz && \
      cd redis-stable && make install && \
      cd .. && rm -rf redis-stable

EXPOSE 6379

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

CMD ["/usr/local/bin/redis-server"]
