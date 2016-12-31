FROM alpine:3.4

LABEL Maintainer="Cesar Alvernaz @ Weirdloop"
LABEL Description="Eclipse Mosquitto MQTT Broker"

RUN apk --no-cache --update add mosquitto=1.4.8-r2 && \
    mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log && \
    cp /etc/mosquitto/mosquitto.conf /mosquitto/config && \
    chown -R mosquitto:mosquitto /mosquitto

WORKDIR /mosquitto

CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
