#!/bin/bash

#####################################################
# This script runs a series of load tests.          #
#                                                   #
# Execute command:                                  #
# time bash -c "./run_test.sh | tee -a results.csv" #
#####################################################

JOBS="1 2 10 25 50 100"
CONCURRENCY="1 10 50 100 200"
ITERATIONS="3"
MAX_CONCURRENT_PROCESSES="$(grep "MAX_CONCURRENT_PROCESSES=" ./deploy_job.sh | cut -d'=' -f2)"
EGRESS_PODS="$(oc get pod | grep egress | wc -l)"

echo "EGRESS_PODS,JOB_PODS,PROCESSES_PER_POD,MEAN_EXEC_TIME"

for JOB in $JOBS; do
  for CON in $CONCURRENCY; do
    if [[ "$(( JOB * CON ))" -gt "${MAX_CONCURRENT_PROCESSES}" ]]; then
      break
    fi

    MEAN=$(./deploy_job.sh ${JOB} ${CON} ${ITERATIONS} | grep 'Mean: ' | cut -d' ' -f2)
    echo "${EGRESS_PODS},${JOB},${CON},${MEAN}"
  done
done
