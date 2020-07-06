#!/usr/bin/env bash
set -euo pipefail

# Disable debugging to prevent secrets from being leaked in the build log
set +x

if [ "${RELEASE:-false}" == false ]
then
  echo "Skipping build since this would affect Pingdom"
  exit 0
fi

#
# Pingdom will honor this as the debug log.
#
export DEBUG_FILE=./debug.log
export WORKING_DIR=$(pwd)

trap onExit EXIT
onExit() {
  local status=$?
  echo "All done! (status $status)"
  if [ $status != 0 ]
  then
    echo "DEBUG LOG"
    cat $DEBUG_FILE
  fi
  exit $status
}

export PATH=${WORKSPACE:-.}/bin:$PATH
if [ "${DEBUG:-false}" == "true" ]; then export DEBUG; fi


. user-ids.conf
. integration-ids.conf

#
# PINGDOM_TOKEN will be used by the pingdom script as the Pingdom API key.
#
export PINGDOM_TOKEN=$(get-secret "/dvp/monitoring/pingdom-token")

#
# Load secrets early to make sure we have all the secrets we need before attempting to
# create checks. We can also eliminate duplicate secret fetches.
#
# NOTE: AWS Systems Manager secret naming convention <env>/<product>/<key-name>
#

export HEALTH_APIS_STATIC_ACCESS_TOKEN=$(get-secret "/dvp/production/health/static-access-token")

for check in ./pingdom-checks/${CHECK_FILTER:-*.ping}; do
  bash -euo pipefail $check || exit 1
done

