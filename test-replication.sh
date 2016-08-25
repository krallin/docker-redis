#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

MASTER_CONTAINER="redis-master"
MASTER_DATA_CONTAINER="${MASTER_CONTAINER}-data"
SLAVE_CONTAINER="redis-slave"
SLAVE_DATA_CONTAINER="${SLAVE_CONTAINER}-data"

CLONE_CONTAINER="redis-clone"
CLONE_DATA_CONTAINER="${CLONE_CONTAINER}-data"

FIFO_CONTAINER="redis-fifo"
FIFO_EXPORT="redis-fifo-out"
FIFO_IMPORT="redis-fifo-in"


function cleanup {
  docker rm -f \
    "$MASTER_CONTAINER" "$MASTER_DATA_CONTAINER" \
    "$SLAVE_CONTAINER" "$SLAVE_DATA_CONTAINER" \
    "$CLONE_CONTAINER" "$CLONE_DATA_CONTAINER" \
    "$FIFO_CONTAINER" "$FIFO_EXPORT" "$FIFO_IMPORT" \
    >/dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

PASSPHRASE=testpass


echo "Initializing data containers"

docker create --name "$MASTER_DATA_CONTAINER" "$IMG"
docker create --name "$SLAVE_DATA_CONTAINER" "$IMG"
docker create --name "$CLONE_DATA_CONTAINER" "$IMG"
docker run --name "$FIFO_CONTAINER" --entrypoint /bin/sh  "$IMG" -c "mkfifo /var/db/fifo"


echo "Initializing master"

docker run -it --rm \
  -e PASSPHRASE="${PASSPHRASE}" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "$IMG" --initialize

MASTER_PORT=63791
docker run -d --name="${MASTER_CONTAINER}" \
  -e "PORT=$MASTER_PORT" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "${IMG}"

MASTER_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$MASTER_CONTAINER")"
MASTER_URL="redis://:$PASSPHRASE@$MASTER_IP:$MASTER_PORT"


echo "Adding test data"

docker run -it --rm "$IMG" --client "$MASTER_URL" SET test_before TEST_DATA


echo "Initializing slave"

docker run -it --rm \
  --volumes-from "$SLAVE_DATA_CONTAINER" \
  "$IMG" --initialize-from "$MASTER_URL"

SLAVE_PORT=63792
docker run -d --name "$SLAVE_CONTAINER" \
  -e "PORT=$SLAVE_PORT" \
  --volumes-from "$SLAVE_DATA_CONTAINER" \
  "$IMG"


SLAVE_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$SLAVE_CONTAINER")"
SLAVE_URL="redis://:$PASSPHRASE@$SLAVE_IP:$SLAVE_PORT"


echo "Adding test data"

docker run -it --rm "$IMG" --client "$MASTER_URL" SET test_after TEST_DATA


echo "Checking test data"

docker run -it --rm "$IMG" --client "$SLAVE_URL" GET test_before | grep "TEST_DATA"
docker run -it --rm "$IMG" --client "$SLAVE_URL" GET test_after  | grep "TEST_DATA"

echo "Replication test OK!"


echo "Creating empty clone"

docker run -it --rm \
  -e PASSPHRASE="${PASSPHRASE}" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "$IMG" --initialize

CLONE_PORT=63793
docker run -d --name="${CLONE_CONTAINER}" \
  -e "PORT=$CLONE_PORT" \
  --volumes-from "$CLONE_DATA_CONTAINER" \
  "${IMG}"

CLONE_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$CLONE_CONTAINER")"
CLONE_URL="redis://:$PASSPHRASE@$CLONE_IP:$CLONE_PORT"


echo "Checking master has no data"
docker run -it --rm "$IMG" --client "$CLONE_URL" GET test_after | grep "TEST_DATA" && false


echo "Cloning master"

docker run --name "$FIFO_EXPORT" -d  \
  --volumes-from "${FIFO_CONTAINER}" \
  --entrypoint "/bin/sh" \
  "$IMG" "-c" "ln -s '/var/db/fifo' '/dump-output' && run-database.sh --dump '$MASTER_URL'"

docker run --name "$FIFO_IMPORT" -it \
  --volumes-from "${FIFO_CONTAINER}" \
  --entrypoint "/bin/sh" \
  "$IMG" "-c" "ln -s '/var/db/fifo' '/restore-input' && run-database.sh --restore '$CLONE_URL'"

docker run -it --rm "$IMG" --client "$CLONE_URL" GET test_after | grep "TEST_DATA"


echo "Clone test OK!"
