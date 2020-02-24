#!/usr/bin/env bash
set -euo pipefail
export PATH=$WORKSPACE/bin:$PATH

HEALTH_APIS_SLACK_ID=100343

pingdom save-check fhir-resource \
  -a name=dstu2-condition \
  -a host=api.va.gov \
  -a url=/services/fhir/v0/dstu2/Condition?patient=1011537977V693883 \
  -a authorization_token=$ARGONAUT_TOKEN \
  -a integrationids_csv=$HEALTH_APIS_SLACK_ID

