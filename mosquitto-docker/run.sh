#!/usr/bin/env bash

docker run -d -it -p 1883:1883 --name mosquitto \
	   -v `pwd`/mosquitto/config/mosquitto.conf:/mosquitto/config/mosquitto.conf  \
	   -v `pwd`/mosquitto/log:/mosquitto/log \
	   -v `pwd`/mosquitto/data:/mosquitto/data \
	   mosquitto:1.4.8
