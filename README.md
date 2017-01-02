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

Quick check everything is up and running

```sh
docker node list
```

Create the overlay network

```sh
docker network create --driver overlay olnet
```

Create the service

```sh
docker login ...

docker service create --with-registry-auth --name mosquitto --network olnet \
-p mode=ingress,target=1883,published=1883,protocol=tcp private.registry:5000/mosquitto-swarm:1.4.8
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

## AWS

## Prerequisites

You need a few things already prepared in order to get started. You need at least Docker 1.12 set up. I was using the stable version of Docker for mac for preparing this guide.
```
$ docker --version
Docker version 1.12.0, build 8eab29e
```
You also need Docker machine installed.
```
$ docker-machine --version
docker-machine version 0.8.0, build b85aac1
```
You need an AWS account. Either you should have you `credentials` file filled:
```
$ cat ~/.aws/credentials
[default]
aws_access_key_id =
aws_secret_access_key =
```
Or you need to export these variables before going forward.
```
$ export AWS_ACCESS_KEY_ID=
$ export AWS_SECRET_ACCESS_KEY=
```
Also, you should have AWS CLI installed.
```
$ aws --version
aws-cli/1.10.44 Python/2.7.10 Darwin/15.5.0 botocore/1.4.34
```

## Set up
You should collect the following details from your AWS account.
```
$ VPC=vpc-abcd1234 # the VPC to create your nodes in
$ REGION=eu-west-1 # the region to use
$ SUBNET=subnet-abcd1234 # the subnet to attach your nodes
$ ZONE=b # the zone to use
```

### Steps

Create the docker swarm manager node first.

```sh
docker-machine create -d amazonec2 --amazonec2-vpc-id $VPC --amazonec2-region $REGION --amazonec2-zone $ZONE --amazonec2-instance-type t2.micro --amazonec2-subnet-id $SUBNET --amazonec2-security-group mqtt-cluster mqtt-cluster-manager
```

Create the two worker nodes. You can run these commands in parallel with the first one.


```sh
docker-machine create -d amazonec2 --amazonec2-vpc-id $VPC --amazonec2-region $REGION --amazonec2-zone $ZONE --amazonec2-instance-type t2.micro --amazonec2-subnet-id $SUBNET --amazonec2-security-group mqtt-cluster mqtt-cluster-node1

docker-machine create -d amazonec2 --amazonec2-vpc-id $VPC --amazonec2-region $REGION --amazonec2-zone $ZONE --amazonec2-instance-type t2.micro --amazonec2-subnet-id $SUBNET --amazonec2-security-group mqtt-cluster mqtt-cluster-node2
```

Get the internal IP address of the swarm manager.

```sh
 docker-machine ssh mqtt-cluster-manager ip addr show eth0
```

Keep track of that IP address. Mine was `172.30.0.175`.

Point your docker client to the swarm manager.

```sh
eval $(docker-machine env mqtt-cluster-manager)
```

Initialize Swarm mode.

```sh
docker swarm init --advertise-addr 172.30.0.175
```

This should output a command which you can use to join on the workers

```sh
docker swarm join --token TOKEN 172.30.0.175:2377
```

Modify the security group to allow the swarm communication (this is necessary because Docker Machine as of today does not support the new Swarm mode so it doesn't open the right ports)

```sh
aws ec2 describe-security-groups --filter "Name=group-name,Values=mqtt-cluster"
```

From this command you should get all the details of the security group. Including the GroupId. Copy that information and run the following commands:

```sh
SECURITY_GROUP_ID=sg-XXXXXXX
```

Then,

```sh
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 2377 --source-group $SECURITY_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 7946 --source-group $SECURITY_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol udp --port 7946 --source-group $SECURITY_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 4789 --source-group $SECURITY_GROUP_ID
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol udp --port 4789 --source-group $SECURITY_GROUP_ID
```

Now it's time to make the other nodes join the cluster:

```sh
eval $(docker-machine env mqtt-cluster-node1)
```

Run the join command in both nodes, so repeat the command above for the two other nodes (node1, node2)

```sh
docker swarm join --token SWMTKN-1-xxxx 172.30.0.175:2377
```

Finally, check how your cluster looks like:

```sh
eval $(docker-machine env mqtt-cluster-manager)

docker node ls
```

## MQTT Cluster


Create an overlay network,

```sh
docker network create --driver overlay olnet
```

Run the service, don't forget to rename the private registry

```sh
docker service create --with-registry-auth --name mosquitto --network olnet -p mode=ingress,target=1883,published=1883,protocol=tcp private.registry:5000/mosquitto-swarm:1.4.8
```

Check if it is running,

```sh
 docker service ls
```

Then spawn 3 replicas,

```sh
docker service scale mosquitto=3
```

## Load Balancer

Create a new security group, open mosquitto port to the world

```sh
aws ec2 create-security-group --group-name mqtt-elb-sec --description "MQTT ELB SecGroup" --vpc-id $VPC
```


It outputs a new group id, that is input for the security group ingress
OA
```sh

ELB_SECURITY_GROUP=sg-xxxx
aws ec2 authorize-security-group-ingress --group-id $ELB_SECURITY_GROUP --protocol tcp --port 1883 --cidr 0.0.0.0/0
```

Create balancer creation

```sh
aws elb create-load-balancer --load-balancer-name mqtt-elb --listeners "Protocol=TCP,LoadBalancerPort=1883,InstanceProtocol=TCP,InstancePort=1883" --subnets $SUBNET --security-groups $ELB_SECURITY_GROUP
```

Link the ELB to the cluster,


```sh
aws ec2 create-security-group --group-name elb2mqtt --description "ELB2MQTT SecGroup" --vpc-id $VPC

ELB2MQTT_SECURITY_GROUP=sg-xxxxx
```


With the security GroupId output:

```sh
aws ec2 authorize-security-group-ingress --group-id $ELB2MQTT_SECURITY-GROUP --protocol tcp --port 1883 --source-group $ELB_SECURITY_GROUP
```

Now we register to load balancer to the cluster instances:

- List:

```sh
aws ec2 describe-instances --filters Name=vpc-id,Values=$VPC
```

- Modify the security groups for all them

```sh
aws ec2 modify-instance-attribute --instance-id i-xxxx --groups ELB2MQTT_SECURITY_GROUP $SECURITY_GROUP_ID
aws ec2 modify-instance-attribute --instance-id i-xxxx --groups ELB2MQTT_SECURITY_GROUP $SECURITY_GROUP_ID
aws ec2 modify-instance-attribute --instance-id i-xxxx --groups ELB2MQTT_SECURITY_GROUP $SECURITY_GROUP_ID
```

- Register:

```sh
aws elb register-instances-with-load-balancer --load-balancer-name mqtt-elb --instances i-072d4516a112d4b69 i-02d45b0903ff1e537 i-035f68e31abb6d663
```

- After a few seconds check if the instances state are in `InService` state
