#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

MASTER_CONTAINER="redis-master"
MASTER_DATA_CONTAINER="${MASTER_CONTAINER}-data"
SLAVE_CONTAINER="redis-slave"
SLAVE_DATA_CONTAINER="${SLAVE_CONTAINER}-data"


function cleanup {
  docker rm -f "$MASTER_CONTAINER" "$MASTER_DATA_CONTAINER" "$SLAVE_CONTAINER" "$SLAVE_DATA_CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

PASSPHRASE=testpass


echo "Initializing data containers"

docker create --name "$MASTER_DATA_CONTAINER" "$IMG"
docker create --name "$SLAVE_DATA_CONTAINER" "$IMG"


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

# Check the data now

docker run -it --rm "$IMG" --client "$MASTER_URL" GET test_before | grep "TEST_DATA"
docker run -it --rm "$IMG" --client "$MASTER_URL" GET test_after  | grep "TEST_DATA"

echo "Test OK!"
