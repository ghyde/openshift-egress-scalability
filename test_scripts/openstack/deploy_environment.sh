#!/bin/bash

##########################################################################
# This script creates an OpenShift project for deploying egress pods and #
# load generator jobs.                                                   #
##########################################################################

USAGE="$0 <project_name>"

if [ "$#" -ne 1 ]; then
  echo ${USAGE}
  exit 1
fi

TEMPLATE_PATH="../../openshift/load_generator/templates"
PROJECT="$1"
SERVICE_NAME="external-website"

set -e

echo "creating project \"${PROJECT}\""
oc delete project ${PROJECT} >/dev/null 2>/dev/null || :
while ! oc new-project ${PROJECT} >/dev/null 2>/dev/null; do :; done

# Build load generator
oc process -f ${TEMPLATE_PATH}/load_generator.yml | oc create -f -
# Wait for build to complete
while ! oc get pod | grep load-generator-1-build | grep -q Running; do :; done
oc log -f load-generator-1-build

# Configure environment for egress router
oc create serviceaccount egress -n ${PROJECT}
oc adm policy add-scc-to-user privileged -z egress -n ${PROJECT} >/dev/null 2>/dev/null
oc process -f ${TEMPLATE_PATH}/service.yml -v SERVICE_NAME=${SERVICE_NAME} | oc create -f -
