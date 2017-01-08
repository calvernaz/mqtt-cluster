## Secure Mosquitto Broker


### Create Password File

Create a file (under `mosquitto-docker/mosquitto/passwd/`) called `pwdfile` with an username and password (`username:password`)

```sh
foo:foobar
```

Now hash the password using `mosquitto_passwd`

```sh
mosquitto_passwd -U passwd
```

The file would be updated and included in the image.

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

## AWS Cluster Deploy

## Prerequisites

You need a few things already prepared in order to get started. You need at least Docker 1.12 set up. I was using the stable version of Docker for mac for preparing this guide.

```sh
$ docker --version
Docker version 1.12.0, build 8eab29e
```

You also need Docker machine installed.

```sh
$ docker-machine --version
docker-machine version 0.8.0, build b85aac1
```

You need an AWS account. Either you should have you `credentials` file filled:

```sh
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

Create the manager node first.

```sh
docker-machine create -d amazonec2 --amazonec2-vpc-id $VPC --amazonec2-region $REGION \
--amazonec2-zone $ZONE --amazonec2-instance-type t2.micro --amazonec2-subnet-id $SUBNET \
--amazonec2-security-group mqtt-cluster mqtt-cluster-manager
```

Create the two worker nodes. You can run these commands in parallel with the first one.

```sh
docker-machine create -d amazonec2 --amazonec2-vpc-id $VPC --amazonec2-region $REGION \
--amazonec2-zone $ZONE --amazonec2-instance-type t2.micro --amazonec2-subnet-id $SUBNET \
--amazonec2-security-group mqtt-cluster mqtt-cluster-node1

docker-machine create -d amazonec2 --amazonec2-vpc-id $VPC --amazonec2-region $REGION \
--amazonec2-zone $ZONE --amazonec2-instance-type t2.micro --amazonec2-subnet-id $SUBNET \
--amazonec2-security-group mqtt-cluster mqtt-cluster-node2
```

Get the internal IP address of the manager.

```sh
 docker-machine ssh mqtt-cluster-manager ip addr show eth0
```

Keep track of that IP address. Mine was `172.30.0.175`.
Point your docker client to the cluster manager.

```sh
eval $(docker-machine env mqtt-cluster-manager)
```

## MQTT HA

### Network

Start by listing your VPC instances:

```sh
aws ec2 describe-instances --filters Name=vpc-id,Values=$VPC
```

We will allocate addresses to reach each machine, remember this:

```sh
When an EC2 instance queries the external DNS name of an Elastic IP, \
the EC2 DNS server returns the internal IP address of the instance \
to which the Elastic IP address is currently assigned.
```

Let's start with the cluster manager machine:

- Allocate an address, will return an allocation id and the public IP
- Then allocate that address to the instance

```sh
eval $(docker-machine env mqtt-cluster-manager)

aws ec2 allocate-address --domain vpc

aws ec2 associate-address --allocation-id eipalloc-xxxx --instance-id i-xxxxxxx
```

Don't forget to change the instance id and allocation id.


### Configure MQTT brokers

Now, it's time to create three images, one acts as a bridge while the other two brokers connect to the bridge, in that so any client message will be propagated through the bridge to the other brokers.

First let's configure the mosquitto docker images,

```sh
./repl.sh -r 52.X.X.X

./repl.sh -u

./repl.sh -p <remote.bridge.password>
```

Then build them.
You might need to run in a new shell, the docker host might be polluted with remote env.


```sh
./repl.sh -b your.registry:5000
```

At this stage everything should be ready for deployment in our ec2 cluster.

- Bridge

```sh
eval $(docker-machine env mqtt-cluster-manager)

docker run -d  --restart=always -p 1883:1883 --name mosquitto-bridge \
registry.livesense.com.au:5000/mosquitto-bridge-ha:1.4.8
```

- Node 1

```sh
eval $(docker-machine env mqtt-cluster-node1)

docker run -d  --restart=always -p 1883:1883 --name mosquitto-broker-1 \
registry.livesense.com.au:5000/mosquitto-broker-1:1.4.8
```

- Node 2

```sh
eval $(docker-machine env mqtt-cluster-node2)

docker run -d  --restart=always -p 1883:1883 --name mosquitto-broker-2 \
registry.livesense.com.au:5000/mosquitto-broker-2:1.4.8
```

Note: The script doesn't apply to second runs. Revert previous changes and run the script again.

### Load Balancer

Create a new security group, open mosquitto port to the world

```sh
aws ec2 create-security-group --group-name mqtt-elb-sec --description "MQTT ELB SecGroup" --vpc-id $VPC
```

It outputs a new group id, that is input for the security group ingress
OA
```sh

ELB_SECURITY_GROUP=sg-xxxx
aws ec2 authorize-security-group-ingress --group-id $ELB_SECURITY_GROUP --protocol tcp \
--port 1883 --cidr 0.0.0.0/0
```

Create balancer creation

```sh
aws elb create-load-balancer --load-balancer-name mqtt-elb \
--listeners "Protocol=TCP,LoadBalancerPort=1883,InstanceProtocol=TCP,InstancePort=1883" \
--subnets $SUBNET --security-groups $ELB_SECURITY_GROUP
```

Link the ELB to the cluster,


```sh
aws ec2 create-security-group --group-name elb2mqtt --description "ELB2MQTT SecGroup" --vpc-id $VPC

ELB2MQTT_SECURITY_GROUP=sg-xxxxx
```


With the security GroupId output:

```sh
aws ec2 authorize-security-group-ingress --group-id $ELB2MQTT_SECURITY-GROUP --protocol tcp \
--port 1883 --source-group $ELB_SECURITY_GROUP
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
aws elb register-instances-with-load-balancer --load-balancer-name mqtt-elb --instances i-xxxx i-xxx i-xxxx
```

- After a few seconds check if the instances state are in `InService` state


## Test MQTT Pub/Sub
