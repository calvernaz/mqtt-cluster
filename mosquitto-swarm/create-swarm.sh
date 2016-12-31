# --------------------------------------------------------------
# script to create a new Docker Swarm from scratch on VirtualBox
# --------------------------------------------------------------
#!/usr/bin/bash

NUM_NODES=5
LEADER_NODE=node-1

# clean up
for NODE in $(seq 1 $NUM_NODES); do
  echo 'y' | docker-machine rm node-$NODE
done;

# create nodes
for NODE in $(seq 1 $NUM_NODES); do
  docker-machine create --driver virtualbox node-$NODE
done;

LEADER_IP=`docker-machine ip $LEADER_NODE`

# initialize swarm
docker-machine ssh $LEADER_NODE docker swarm init --advertise-addr $LEADER_IP

# Now let's get the swarm join token for a worker node
JOIN_TOKEN=`docker-machine ssh $LEADER_NODE docker swarm join-token worker -q`

# all other nodes join as workers
for n in $(seq 2 $NUM_NODES); do
  docker-machine ssh node-$n docker swarm join --token $JOIN_TOKEN $LEADER_IP:2377
done;

# promote node 2 and 3 to master role
docker-machine ssh $LEADER_NODE docker node promote node-2 node-3

# finally show all nodes
docker-machine ssh $LEADER_NODE docker node ls
