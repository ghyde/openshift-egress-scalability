#!/bin/bash

###############################################################################
# This script takes a list of MAC addresses and IP address, whitelisting them #
# in OpenStack.                                                               #
###############################################################################

USAGE="$0 <neutron_port_uuid> [egress_info_file]"

if [ "$#" -lt 1 ]; then
  echo ${USAGE}
  exit 1
fi

NEUTRON_PORT_UUID=$1
INPUT_FILE=$2

set -e

PAIRS=""
while read line; do
  MAC=$(echo ${line} | cut -d' ' -f1)
  IP=$(echo ${line} | cut -d' ' -f2)
  PAIRS="${PAIRS} ip_address=${IP},mac_address=${MAC}"
done < "${INPUT_FILE:-/dev/stdin}"

neutron port-update ${NEUTRON_PORT_UUID} --allowed-address-pairs list=true type=dict ${PAIRS}
