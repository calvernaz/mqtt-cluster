#!/usr/bin/env sh

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"


MOSQUITTO_CONF=mosquitto.conf
BROKER_NODES=(node-1 node-2)
REPLACE_BRIDGE_ADDR=BRIDGE_ADDRESS
REPLACE_BRIDGE_PASSWD=password
MOSQUITTO_PASSWD=$(which mosquitto_passwd)


usage() {
  echo "$__base [-h] [-r] [-u] [-p]"
  echo ""
  echo "  -h                  print this message"
  echo "  -r  <public-ip>     replace bridge address with IP address"
  echo "  -u                  update the file with hashed password"
  echo "  -p                  replace remote bridge password"
  echo ""
  exit 1
}

repl_bridge_addr() {
    local replace=$2
	echo "$*"
	for i in ${BROKER_NODES[@]}; do
		if [ ! -f ${i}/$MOSQUITTO_CONF ]; then
				echo "File not found!"
		fi

		echo "Replacing" ${i}/$MOSQUITTO_CONF
		sed -i "" "s/${REPLACE_BRIDGE_ADDR}/${replace}/g" ${i}/$MOSQUITTO_CONF
	done
}

repl_passwd_file() {
	for i in ${BROKER_NODES[@]}; do
		echo "Replacing ${i}/pwfile"
		$MOSQUITTO_PASSWD -U "${i}/pwfile"
	done
}

repl_bridge_passwd() {
    local replace=$2

	for i in ${BROKER_NODES[@]}; do
		if [ ! -f ${i}/$MOSQUITTO_CONF ]; then
				echo "File not found!"
		fi

		echo "Replacing" ${i}/$MOSQUITTO_CONF
		sed -i "" "s/${REPLACE_BRIDGE_PASSWD}/${replace}/g" ${i}/$MOSQUITTO_CONF
	done
}



while getopts ":r:ph" opt; do
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
			if [ -z "$MOSQUITTO_PASSWD" ]; then
					echo "mosquitto_passwd is not available"
					exit 2
			fi
			repl_passwd_file $opt
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
