#!/bin/bash

############################################
# This script spawns load generators jobs. #
############################################

USAGE="$0 <jobs> <concurrency> <iterations>"

if [ "$#" -ne 3 ]; then
  echo ${USAGE}
  exit 1
fi

MAX_CONCURRENT_PROCESSES=200
TEMPLATE_PATH="../../openshift/load_generator/templates"
JOBS="$1"
CONCURRENCY="$2"
MAX_ITERATIONS="$3"
REQUESTS=$(( CONCURRENCY * 100 / JOBS ))

# Ensure number of requests is >0
if [[ "${REQUESTS}" -lt "1" ]]; then
  REQUESTS="1"
fi

# Ensure inputs are not negative
if [[ "${JOBS}" -lt "0" ]]; then
  echo "Error: jobs cannot be negative."
  exit 1
fi
if [[ "${CONCURRENCY}" -lt "0" ]]; then
  echo "Error: concurrency cannot be negative."
  exit 1
fi
if [[ "${MAX_ITERATIONS}" -lt "0" ]]; then
  echo "Error: iterations connot be negative."
  exit 1
fi

# Ensure web server doesn't get overloaded
if [[ "$(( JOBS * CONCURRENCY ))" -gt "${MAX_CONCURRENT_PROCESSES}" ]]; then
  echo -e "Error: Max concurrency exceeded.\n       Ensure JOBS * CONCURRENCY <= ${MAX_CONCURRENT_PROCESSES}."
  exit 1
fi

SERVICE_NAME="external-website"
APP_NAME=load-generator
IMAGE_STREAM=$(oc get is ${APP_NAME} --output=jsonpath='{.Status.DockerImageRepository}'):latest
COUNT=0
TOTAL_TIME=0

# Gather data
for (( i=0; i<${MAX_ITERATIONS}; i++ )); do
  echo "creating job \"${APP_NAME}\""
  oc delete job ${APP_NAME} >/dev/null 2>/dev/null || :
  # Wait for old jobs to finish terminating
  while oc get pod | grep ${APP_NAME} | grep -q Terminating; do :; done

  # Start load generator job
  oc process -f ${TEMPLATE_PATH}/job.yml -v APP_NAME=${APP_NAME},PARALLEL=${JOBS},IMAGE=${IMAGE_STREAM},REQUESTS=${REQUESTS},CONCURRENCY=${CONCURRENCY},URL="http://${SERVICE_NAME}/" | oc create -f -
  while ! oc get pod | grep load-generator | grep -v '\-build' | grep -q -e Running -e Completed; do :; done

  SUCCEEDED=1
  while [ "${SUCCEEDED}" -ne "0" ]; do
    SUCCEEDED=0
    TEMP_COUNT=0
    TEMP_TOTAL_TIME=0
    for pod in $(oc get pod | grep -v '\-build' | grep ${APP_NAME} | grep -v Error | awk '{print $1}'); do
      echo "pod \"${pod}\""
      # Wait for job to start
      while ! oc get pod | grep ${pod} | grep -q -e Running -e Completed -e Error; do :; done
      # Get job's total mean time
      RESULT=$(oc logs -f ${pod} | grep "Total:" | awk '{print $3}')
      if [ -z "${RESULT}" ]; then
        echo "Failed to get result for pod \"${pod}\". Trying again."
        SUCCEEDED=1
        # Wait for pod to error out
        while ! oc get pod | grep ${pod} | grep -q Error; do :; done
        break
      fi
      TEMP_TOTAL_TIME=$(( TEMP_TOTAL_TIME + RESULT ))
      TEMP_COUNT=$(( TEMP_COUNT + 1 ))
    done
  done
  TOTAL_TIME=$(( TOTAL_TIME + TEMP_TOTAL_TIME ))
  COUNT=$(( COUNT + TEMP_COUNT ))
done

echo "Mean: $(( TOTAL_TIME / COUNT )) ms"
