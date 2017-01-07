#!/usr/bin/env bash

docker run -d  --restart=always -p 1883:1883 --name mosquitto-bridge registry.livesense.com.au:5000/mosquitto-bridge-ha:1.4.8
