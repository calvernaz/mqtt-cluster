#!/usr/bin/env bash

docker build . -t mosquitto-bridge-ha:1.4.8
docker tag mosquitto-bridge-ha:1.4.8 registry.livesense.com.au:5000/mosquitto-bridge-ha:1.4.8
