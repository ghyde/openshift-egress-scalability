#!/bin/bash

########################################################################
# This script scales egress pods such that the total number of running #
# pods equals <max_egress_pods>.                                       #
########################################################################

USAGE="$0 <gateway> <start_ip_address> <destination_ip> <max_egress_pods>"

if [ "$#" -ne 4 ]; then
  echo ${USAGE}
  exit 1
fi

TEMPLATE_PATH="../../openshift/load_generator/templates"
GATEWAY="$1"
START_IP=$(echo $2 | cut -d'.' -f4)
BASE_SUBNET=$(echo $2 | cut -d'.' -f1-3)
DEST_IP="$3"
MAX_EGRESS_PODS="$4"

# Ensure input is not negative
if [[ "${MAX_EGRESS_PODS}" -lt "0" ]]; then
  echo "Error: max_egress_pods cannot be negative."
  exit 1
fi

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
  done
else
  # Find start point for deploying new pods
  LAST_EGRESS_POD=$(echo ${CURRENT_EGRESS_PODS} | cut -d' ' -f1)
  if [ -z "${LAST_EGRESS_POD}" ]; then
    LAST_EGRESS_IP=$(( START_IP - 1 ))
  else
    LAST_EGRESS_IP=${LAST_EGRESS_POD}
  fi

  # Create new egress routers
  for (( i=0; i<$(( MAX_EGRESS_PODS - EGRESS_COUNT )); i++ )); do
    NEW_IP="${BASE_SUBNET}.$(( LAST_EGRESS_IP += 1 ))"
    oc process -f ${TEMPLATE_PATH}/egress_router.yml -v EGRESS_NAME=egress-${LAST_EGRESS_IP},EGRESS_GATEWAY=${GATEWAY},EGRESS_SOURCE=${NEW_IP},EGRESS_DESTINATION=${DEST_IP} | oc create -f -
    # Wait for egress router to start
    while ! oc get pod | grep egress-${LAST_EGRESS_IP} | grep -q Running; do :; done
  done
fi
