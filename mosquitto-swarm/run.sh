#!/usr/bin/env bash

docker run -d -it -p 1883:1883 --name mosquitto mosquitto-swarm:1.4.8
