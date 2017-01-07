#!/usr/bin/env bash

docker build -t mosquitto-broker-1:1.4.8 .
docker tag mosquitto-broker-1:1.4.8 registry.livesense.com.au:5000/mosquitto-broker-1:1.4.8
docker push registry.livesense.com.au:5000/mosquitto-broker-1:1.4.8
