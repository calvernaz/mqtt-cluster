#!/usr/bin/env sh

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"


MOSQUITTO_CONF=mosquitto.conf
BROKER_NODES=(bridge node-1 node-2)
REPLACE_BRIDGE_ADDR=BRIDGE_ADDRESS
REPLACE_BRIDGE_PASSWD=password

# Tools
MOSQUITTO_PASSWD_CMD=$(which mosquitto_passwd)
DOCKER_CMD=$(which docker)

usage() {
  echo "$__base [-h] [-r] [-u] [-p] [-b]"
  echo ""
  echo "  -h                  print this message"
  echo "  -r  <public-ip>     replace bridge address with IP address"
  echo "  -p  <password>      replace remote bridge password"
  echo "  -u                  update the file with hashed password"
  echo "  -b  <registry>      build the docker images (all)"
  echo ""
  exit 1
}

repl_bridge_addr() {
    local replace=$2

	for i in ${BROKER_NODES[@]}; do
		if [ ! -f ${i}/$MOSQUITTO_CONF ]; then
				echo "File not found!"
		fi

		echo "Replacing" ${i}/$MOSQUITTO_CONF
		sed -i "" "s/${REPLACE_BRIDGE_ADDR}/${replace}/g" ${i}/$MOSQUITTO_CONF
	done
}

repl_passwd_file() {
	if [ -z "$MOSQUITTO_PASSWD_CMD" ]; then
			echo "mosquitto_passwd is not available"
			exit 2
	fi

	$MOSQUITTO_PASSWD_CMD -U pwfile

	for i in ${BROKER_NODES[@]}; do
		echo "Copying ${i}/pwfile"
		cp pwfile ${i}/
	done
}

repl_bridge_passwd() {
    local replace=$2

	for i in ${BROKER_NODES[@]}; do
		if [ ! -f ${i}/$MOSQUITTO_CONF ]; then
				echo "File not found!"
		fi

		echo "Replacing" ${i}/$MOSQUITTO_CONF
		sed -i "" -E "s/${REPLACE_BRIDGE_PASSWD}\$/${replace}/g" ${i}/$MOSQUITTO_CONF
	done
}

build_docker_images() {
	local registry=$2

	if [ -z "$DOCKER_CMD" ]; then
			echo "docker is not available"
			exit 2
	fi

	for i in ${BROKER_NODES[@]}; do
		echo "Building" ${i} "image"
		sh ${i}/build.sh $registry
	done
}


while getopts ":r:buhp:" opt; do
	case ${opt} in
		h)
			usage
			;;
		r)
			repl_bridge_addr $*
			;;
		p)
			repl_bridge_passwd $*
			;;
		u)
			repl_passwd_file $*
			;;
		b)
			build_docker_images $*
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
		:) echo "${OPTARG} requires an argument"; exit 1;
			;;
	esac
done

if [ $# -eq 0 ];then
		usage
fi
