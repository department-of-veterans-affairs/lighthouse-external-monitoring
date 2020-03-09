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

#
# PINGDOM_TOKEN will be used by the pingdom script as the Pingdom API key.
#
export PINGDOM_TOKEN=$(get-secret "/monitoring/pingdom-token")

#
# Load secrets early to make sure we have all the secrets we need before attempting to
# create checks. We can also eliminate duplicate secret fetches.
#
# NOTE: AWS Systems Manager secret naming convention <env>/<product>/<key-name>
#

export HEALTH_APIS_STATIC_ACCESS_TOKEN=$(get-secret "/production/health/static-access-token")


#
# These are Slack integration IDs. Unfortunately, there is no Pingdom API for determining these
# at run time and must be configured here.
#

#
# During the cutover phase, we'll route alerts to the shanktovoid to
# prevent duplicate spam in the real monitoring channel.
#
TEST_SLACK_CHANNEL_ID=100586

if [ -f ./secrets.conf ]; then
  TEST_SLACK_CHANNEL_ID=$(get-secret "/local/slack-integration/id")
fi

export TEST_SLACK_CHANNEL_ID

export HEALTH_APIS_SLACK_ID=$TEST_SLACK_CHANNEL_ID


allChecks(){
  find pingdom-checks -name *.ping
}

allChecks | xargs -n1 bash 


#
# URLs monitored by blackbox
#
# api.vets.gov
# api.vets.gov/
# va.gov
# api.va.gov
# api.va.gov/
# api.va.gov/health/
# api.va.gov/scorecard/
# api.va.gov/gids/status
# api.va.gov/healthcheck
# developer.va.gov
# developer.va.gov/
# api.va.gov/services/meta/v0/ping
# api.va.gov/services/appeals/v0/healthcheck
#


# DONE
# api.va.gov/services/va_facilities/v0/facilities?lat=41.881832&long=87.6233&limit=1
# api.va.gov/services/address_validation/v1/candidate
# api.va.gov/services/fhir/v0/r4/metadata
# api.va.gov/services/fhir/v0/r4/openapi.json
# api.va.gov/services/fhir/v0/dstu2/metadata
# api.va.gov/services/fhir/v0/dstu2/openapi.json
# api.va.gov/services/fhir/v0/argonaut/dataquery/metadata
# api.va.gov/services/fhir/v0/argonaut/dataquery/openapi.json
# api.va.gov/services/communitycare/v0/eligibility/openapi.json
# api.va.gov/services/claims/v0/healthcheck
# api.va.gov/services/claims/v1/healthcheck
# api.va.gov/services/vba_documents/v0/healthcheck
# api.va.gov/services/vba_documents/v1/healthcheck
