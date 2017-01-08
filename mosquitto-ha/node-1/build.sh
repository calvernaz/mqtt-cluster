#!/usr/bin/env bash

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

registry=$1

docker build -t mosquitto-broker-1:1.4.8 $__dir
docker tag mosquitto-broker-1:1.4.8 $registry/mosquitto-broker-1:1.4.8
docker push $registry/mosquitto-broker-1:1.4.8
