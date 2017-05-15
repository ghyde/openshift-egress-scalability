#!/bin/bash

#####################################################################
# This script exports the MAC addresses and IPs for all egress pods #
#####################################################################

set -e

# Get list of all egress pods
CURRENT_EGRESS_PODS=$(oc get pod | grep egress | cut -d' ' -f1)

for pod in ${CURRENT_EGRESS_PODS}; do
  MAC=$(oc exec ${pod} -- bash -c "ip addr show macvlan0" | grep ether | awk '{print $2}')
  IP=$(oc exec ${pod} -- bash -c "ip addr show macvlan0" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
  echo ${MAC} ${IP}
done
