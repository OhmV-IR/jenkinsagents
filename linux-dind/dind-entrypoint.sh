#!/bin/bash
set -e

echo "Starting nested Docker engine..."

sudo dockerd \
    --host=unix:///var/run/docker.sock \
    --storage-driver=overlay2 \
    > /tmp/dockerd.log 2>&1 &

until sudo docker info >/dev/null 2>&1; do
    sleep 1
done

sudo chmod 666 /var/run/docker.sock

echo "Nested Docker engine is ready."

exec "$@"
