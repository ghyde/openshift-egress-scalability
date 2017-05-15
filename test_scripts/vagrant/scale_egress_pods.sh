#!/bin/bash

########################################################################
# This script scales egress pods such that the total number of running #
# pods equals <max_egress_pods>.                                       #
########################################################################

USAGE="$0 <max_egress_pods>"

if [ "$#" -ne 1 ]; then
  echo ${USAGE}
  exit 1
fi

TEMPLATE_PATH="../../openshift/load_generator/templates"
MAX_EGRESS_PODS="$1"
EGRESS_NODE=node1  # Server hosting egress pods

# Ensure input is not negative
if [[ "${MAX_EGRESS_PODS}" -lt "0" ]]; then
  echo "Error: max_egress_pods cannot be negative."
  exit 1
fi

# Check if node has entered promiscuous mode
in_promiscuous_mode () {
  # Manually enable/disable promiscuous mode:
  # ifconfig eth0 promisc
  # ifconfig eth0 -promisc

  local INTERFACE=eth0

  if vagrant ssh ${EGRESS_NODE} -c "netstat -I=${INTERFACE} | grep ${INTERFACE} | awk '{print $NF}' | grep -q P" >/dev/null 2>/dev/null; then
    echo "In promiscuous mode"
  fi
}

get_vm_ip () {
    # Arguments: <vm_name> <interface>
    vagrant ssh "$1" -c "ip address show $2" 2>/dev/null | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//'
}

generate_ip () {
  local output=${ADMIN1_IP}
  local count=${LAST_EGRESS_IP}
  while [[ "${output}" == "${ADMIN1_IP}"
        || "${output}" == "${MASTER1_IP}"
        || "${output}" == "${NODE1_IP}"
        || "${output}" == "${NODE2_IP}"
        ]]; do
    output="${BASE_SUBNET}.$(( count += 1 ))"
  done
  echo $output
}

set -e

# Get list of all egress pods
CURRENT_EGRESS_PODS=$(oc get pod | grep egress | cut -d' ' -f1 | cut -d'-' -f2 | sort -rn)

# Get current egress pod count
EGRESS_COUNT=$(oc get pod | grep egress | wc -l)

if [[ "${EGRESS_COUNT}" -eq "${MAX_EGRESS_PODS}" ]]; then
  # Don't have to do anything
  exit 0
elif [[ "${EGRESS_COUNT}" -gt "${MAX_EGRESS_PODS}" ]]; then
  # Delete excess egress pods
  for (( i=1; i<=$(( EGRESS_COUNT - MAX_EGRESS_PODS)); i++)); do
    number=$(echo ${CURRENT_EGRESS_PODS} | cut -d' ' -f${i})
    oc delete pod egress-${number}
    # Wait for pod to stop
    while oc get pod | grep -q egress-${number}; do :; done
    in_promiscuous_mode
  done
else
  # Get IP address for VMs
  ADMIN1_IP=$(get_vm_ip admin1 eth0)
  MASTER1_IP=$(get_vm_ip master1 eth0)
  NODE1_IP=$(get_vm_ip node1 eth0)
  NODE2_IP=$(get_vm_ip node2 eth0)
  BASE_SUBNET=$(echo ${ADMIN1_IP} | cut -d"." -f1-3)

  # Find start point for deploying new pods
  LAST_EGRESS_POD=$(echo ${CURRENT_EGRESS_PODS} | cut -d' ' -f1)
  if [ -z "${LAST_EGRESS_POD}" ]; then
    LAST_EGRESS_IP=1
  else
    LAST_EGRESS_IP=${LAST_EGRESS_POD}
  fi

  # Create new egress routers
  for (( i=0; i<$(( MAX_EGRESS_PODS - EGRESS_COUNT )); i++ )); do
    NEW_IP=$(generate_ip)
    LAST_EGRESS_IP=$(echo ${NEW_IP} | cut -d'.' -f4)
    oc process -f ${TEMPLATE_PATH}/egress_router.yml -v EGRESS_NAME=egress-${LAST_EGRESS_IP},EGRESS_GATEWAY=${BASE_SUBNET}.1,EGRESS_SOURCE=${NEW_IP},EGRESS_DESTINATION=${ADMIN1_IP} | oc create -f -
    # Wait for egress router to start
    while ! oc get pod | grep egress-${LAST_EGRESS_IP} | grep -q Running; do :; done
    in_promiscuous_mode
  done
fi
