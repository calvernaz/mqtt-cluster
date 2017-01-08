#!/usr/bin/env bash

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker build -t mosquitto-bridge-ha:1.4.8 $__dir
docker tag mosquitto-bridge-ha:1.4.8 $1/mosquitto-bridge-ha:1.4.8
docker push $1/mosquitto-bridge-ha:1.4.8
