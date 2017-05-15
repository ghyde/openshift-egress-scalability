#!/bin/bash

#####################################################
# This script removes egress routers from OpenStack #
#####################################################

USAGE="$0 <neutron_port_uuid>"

if [ "$#" -ne 1 ]; then
  echo ${USAGE}
  exit 1
fi

NEUTRON_PORT_UUID="$1"

neutron port-update ${NEUTRON_PORT_UUID} --no-allowed-address-pairs
