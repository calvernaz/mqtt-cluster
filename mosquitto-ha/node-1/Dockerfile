FROM alpine:3.4

LABEL Maintainer="Cesar Alvernaz @ Weirdloop"
LABEL Description="Eclipse Mosquitto MQTT Broker"

RUN apk --no-cache --update add mosquitto=1.4.8-r2 && \
    mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log && \
    chown -R mosquitto:mosquitto /mosquitto

COPY mosquitto.conf /mosquitto/config/
COPY pwfile /etc/mosquitto/

RUN mosquitto_passwd -U /etc/mosquitto/pwfile

ENV MOSQUITTO_HOME /mosquitto

WORKDIR /mosquitto

CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
