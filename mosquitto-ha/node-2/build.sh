#!/usr/bin/env bash

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker build -t mosquitto-broker-2:1.4.8 $__dir
docker tag mosquitto-broker-2:1.4.8 $1/mosquitto-broker-2:1.4.8
docker push $1/mosquitto-broker-2:1.4.8
