## Docker

Build the docker image with mosquitto

```sh
docker build -t mosquitto:1.8.4 .
```

Run it

```sh
docker run -d -it -p 1883:1883 --name mosquitto \
	   -v `pwd`/mosquitto/config/mosquitto.conf:/mosquitto/config/mosquitto.conf  \
	   -v `pwd`/mosquitto/log:/mosquitto/log \
	   -v `pwd`/mosquitto/data:/mosquitto/data \
	   mosquitto:1.4.8
```


## Docker Swarm

Run the create swarm cluster script

```sh
./create-swarm.sh
```

Setup your host to point towards the leader node

```sh
eval "$(docker-machine env node-1)"
```

Create the overlay network

```sh
docker network create --driver overlay olnet
```

Create the service

```sh
docker service create --with-registry-auth --name mosquitto --network olnet --mount type=volume,source=data,target=/mosquitto/data  --mount type=volume,source=log,target=/mosquitto/log -p mode=ingress,target=1883,published=1883,protocol=tcp registry.livesense.com.au:5000/mosquitto-swarm:1.4.8
```

Scale for 5 replicas and check where they running

```sh
docker service scale mosquitto=5
```

```sh
docker service ps mosquitto
```

```docker service ps --no-trunc mosquitto```
```docker service inspect --pretty mosquitto```
