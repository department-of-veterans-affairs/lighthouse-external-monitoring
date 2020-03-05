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
SANDBOX_FACILITIES_API_KEY=$(get-secret "/sandbox/facilities/api-key")
PRODUCTION_FACILITIES_API_KEY=$(get-secret "/production/facilities/api-key")
SANDBOX_ADDRESS_VALIDATION_API_KEY=$(get-secret "/sandbox/address-validation/api-key")
PRODUCTION_ADDRESS_VALIDATION_API_KEY=$(get-secret "/production/address-validation/api-key")
PRODUCTION_OAUTH_BASIC_AUTH_TOKEN=$(get-secret "/production/oauth/basic-auth-token")
PRODUCTION_OAUTH_REFRESH_TOKEN=$(get-secret "/production/oauth/refresh-token")
DEV_OAUTH_BASIC_AUTH_TOKEN=$(get-secret "/dev/oauth/basic-auth-token")
DEV_OAUTH_REFRESH_TOKEN=$(get-secret "/dev/oauth/refresh-token")
HEALTH_APIS_STATIC_ACCESS_TOKEN=$(get-secret "/production/health/static-access-token")
COMMUNITY_CARE_LAB_API_KEY=$(get-secret "/dev/community-care/api-key")


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

HEALTH_APIS_SLACK_ID=$TEST_SLACK_CHANNEL_ID
OAUTH_SLACK_ID=$TEST_SLACK_CHANNEL_ID
SSL_EXPIRATION_SLACK_ID=$TEST_SLACK_CHANNEL_ID
FACILITIES_SLACK_ID=$TEST_SLACK_CHANNEL_ID
ADDRESS_VALIDATION_SLACK_ID=$TEST_SLACK_CHANNEL_ID
DOMAIN_SLACK_ID=$TEST_SLACK_CHANNEL_ID

#
# Domain Checks
#
pingdom save-check \
  --template https-public-200 \
  -a name=production-domain \
  -a host=api.va.gov \
  -a url="/" \
  -a port="443" \
  -a responsetime_threshold="10000" \
  -a resolution="1" \
  -a group="domain-health" \
  -a integrationids_csv="$DOMAIN_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-domain \
  -a host=sandbox-api.va.gov \
  -a url="/" \
  -a port="443" \
  -a responsetime_threshold="10000" \
  -a resolution="1" \
  -a group="domain-health" \
  -a integrationids_csv="$DOMAIN_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=developer-portal-domain \
  -a host=developer.va.gov \
  -a url="/" \
  -a port="443" \
  -a responsetime_threshold="10000" \
  -a resolution="1" \
  -a group="domain-health" \
  -a integrationids_csv="$DOMAIN_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=dev-domain \
  -a host=dev-api.va.gov \
  -a url="/" \
  -a port="443" \
  -a responsetime_threshold="10000" \
  -a resolution="1" \
  -a group="domain-health" \
  -a integrationids_csv="$DOMAIN_SLACK_ID"

#
# Address Validation
#

pingdom save-check \
  --template post-request-with-apikey \
  -a name=sandbox-address-validation \
  -a host=sandbox-api.va.gov \
  -a url="/services/address_validation/v1/candidate" \
  -a group=address-validation \
  -a apikey="$SANDBOX_ADDRESS_VALIDATION_API_KEY" \
  -a postdata="$(escape-json '{"requestAddress": {"addressLine1": "1600 Pennsylvania Ave", "city": "Washington", "stateProvince": {"name": "DC"}, "requestCountry": {"countryName": "USA"}}}')" \
  -a integrationids_csv="$ADDRESS_VALIDATION_SLACK_ID"

pingdom save-check \
  --template post-request-with-apikey \
  -a name=production-address-validation \
  -a host=api.va.gov \
  -a url="/services/address_validation/v1/candidate" \
  -a group=address-validation \
  -a apikey="$PRODUCTION_ADDRESS_VALIDATION_API_KEY" \
  -a postdata="$(escape-json '{"requestAddress": {"addressLine1": "1600 Pennsylvania Ave", "city": "Washington", "stateProvince": {"name": "DC"}, "requestCountry": {"countryName": "USA"}}}')" \
  -a integrationids_csv="$ADDRESS_VALIDATION_SLACK_ID"

  #
  # Facilities
  #
  pingdom save-check \
    --template request-with-apikey \
    -a name=sandbox-facilities \
    -a host=sandbox-api.va.gov \
    -a url="/services/va_facilities/v0/facilities?lat=41.881832&long=-87.6233&limit=1" \
    -a group=facilities \
    -a apikey="$SANDBOX_FACILITIES_API_KEY" \
    -a integrationids_csv="$FACILITIES_SLACK_ID"

  pingdom save-check \
    --template request-with-apikey \
    -a name=production-facilities \
    -a host=api.va.gov \
    -a url="/services/va_facilities/v0/facilities?lat=41.881832&long=-87.6233&limit=1" \
    -a group=facilities \
    -a apikey="$PRODUCTION_FACILITIES_API_KEY" \
    -a integrationids_csv="$FACILITIES_SLACK_ID"

#
# SSL Checks
#
pingdom save-check \
  --template ssl-expiration-check \
  -a name=ssl-developer-portal \
  -a host=developer.va.gov \
  -a integrationids_csv="$SSL_EXPIRATION_SLACK_ID"

pingdom save-check \
  --template ssl-expiration-check \
  -a name=ssl-dev-api \
  -a host=dev-api.va.gov \
  -a integrationids_csv="$SSL_EXPIRATION_SLACK_ID"

pingdom save-check \
  --template ssl-expiration-check \
  -a name=ssl-production-api \
  -a host=api.va.gov \
  -a integrationids_csv="$SSL_EXPIRATION_SLACK_ID"

pingdom save-check \
  --template ssl-expiration-check \
  -a name=ssl-tools-health \
  -a host=tools.health.dev-developer.va.gov \
  -a integrationids_csv="$SSL_EXPIRATION_SLACK_ID"


#
# OAuth Checks
#
pingdom save-check \
  --template oauth-refresh-token \
  -a name=production-oauth-refresh-token \
  -a host=api.va.gov \
  -a url=/oauth2/token \
  -a authorization_token="$PRODUCTION_OAUTH_BASIC_AUTH_TOKEN" \
  -a refresh_token="$PRODUCTION_OAUTH_REFRESH_TOKEN" \
  -a integrationids_csv="$OAUTH_SLACK_ID"

pingdom save-check \
  --template oauth-refresh-token \
  -a name=dev-oauth-refresh-token \
  -a host=dev-api.va.gov \
  -a url=/oauth2/token \
  -a authorization_token="$DEV_OAUTH_BASIC_AUTH_TOKEN" \
  -a refresh_token="$DEV_OAUTH_REFRESH_TOKEN" \
  -a integrationids_csv="$OAUTH_SLACK_ID"


#
# FHIR Resource Checks
#
pingdom save-check \
  --template fhir-resource \
  -a name=production-dstu2-patient \
  -a host=api.va.gov \
  -a url="/services/fhir/v0/dstu2/Patient/1011537977V693883" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template fhir-resource \
  -a name=production-dstu2-condition \
  -a host=api.va.gov \
  -a url="/services/fhir/v0/dstu2/Condition?patient=1011537977V693883" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template fhir-resource \
  -a name=production-dstu2-medication-statement \
  -a host=api.va.gov \
  -a url="/services/fhir/v0/dstu2/MedicationStatement?patient=1011537977V693883" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template simple-resource \
  -a name=dev-health-alb \
  -a host=dev-api.va.gov \
  -a url="/services/fhir/v0/healthz" \
  -a group="health-apis" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template fhir-resource \
  -a name=dev-dstu2-patient \
  -a host=dev-api.va.gov \
  -a url="/services/fhir/v0/dstu2/Patient/1011537977V693883" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

#
# Urgent-Care Health Checks
#
pingdom save-check \
  --template fhir-resource \
  -a name=dev-r4-coverage-eligibility-response \
  -a host=dev-api.va.gov \
  -a url="/services/fhir/v0/r4/CoverageEligibilityResponse?patient=1017283148V813263" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template fhir-resource \
  -a name=production-r4-coverage-eligibility-response \
  -a host=api.va.gov \
  -a url="/services/fhir/v0/r4/CoverageEligibilityResponse?patient=1017237188V293031" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"


#
# Community-Care Health Checks
#
pingdom save-check \
  --template request-with-bearer-token \
  -a name=production-community-care-patient-primary-care \
  -a host=api.va.gov \
  -a url="/services/community-care/v0/eligibility/search?patient=1013294025V219497&serviceType=PrimaryCare&extendedDriveMin=50" \
  -a group="community-care" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template request-with-bearer-token \
  -a name=lab-community-care-patient-primary-care \
  -a host=dev-api.va.gov \
  -a url="/services/community-care/v0/eligibility/search?patient=1017283148V813263&serviceType=PrimaryCare&extendedDriveMin=50" \
  -a group="community-care" \
  -a authorization_token="$HEALTH_APIS_STATIC_ACCESS_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template request-with-apikey \
  -a name=lab-community-care-vaos-patient-primary-care \
  -a host=dev-api.va.gov \
  -a url="/services/community-care-vaos/v0/eligibility/search?patient=1017283148V813263&serviceType=PrimaryCare&extendedDriveMin=50" \
  -a group="community-care" \
  -a apikey="$COMMUNITY_CARE_LAB_API_KEY" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

#
# Production Metadata Checks
#
  pingdom save-check \
    --template https-public-200 \
    -a name=production-r4-metadata \
    -a host=api.va.gov \
    -a url="/services/fhir/v0/r4/metadata" \
    -a port="443" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

  pingdom save-check \
    --template https-public-200 \
    -a name=production-r4-openapi \
    -a host=api.va.gov \
    -a url="/services/fhir/v0/r4/openapi.json" \
    -a port="443" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

  pingdom save-check \
    --template https-public-200 \
    -a name=production-dstu2-metadata \
    -a host=api.va.gov \
    -a url="/services/fhir/v0/dstu2/metadata" \
    -a port="443" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

  pingdom save-check \
    --template https-public-200 \
    -a name=production-dstu2-openapi.json \
    -a host=api.va.gov \
    -a port="443" \
    -a url="/services/fhir/v0/dstu2/openapi.json" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

  pingdom save-check \
    --template https-public-200 \
    -a name=production-data-query-metadata \
    -a host=api.va.gov \
    -a url="/services/fhir/v0/argonaut/data-query/metadata" \
    -a port="443" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

  pingdom save-check \
    --template https-public-200 \
    -a name=production-data-query-openapi \
    -a host=api.va.gov \
    -a url="/services/fhir/v0/argonaut/data-query/openapi.json" \
    -a port="443" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

  pingdom save-check \
    --template https-public-200 \
    -a name=production-community-care-openapi \
    -a host=api.va.gov \
    -a url="/services/community-care/v0/eligibility/openapi.json" \
    -a port="443" \
    -a responsetime_threshold=10000 \
    -a resolution=1 \
    -a group=metadata \
    -a integrationids_csv="$HEALTH_APIS_SLACK_ID"
#
# Sandbox Metadata Checks
#
pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-r4-metadata \
  -a host=sandbox-api.va.gov \
  -a url="/services/fhir/v0/r4/metadata" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-r4-openapi \
  -a host=sandbox-api.va.gov \
  -a url="/services/fhir/v0/r4/openapi.json" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-dstu2-metadata \
  -a host=sandbox-api.va.gov \
  -a url="/services/fhir/v0/dstu2/metadata" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-dstu2-openapi.json \
  -a host=sandbox-api.va.gov \
  -a url="/services/fhir/v0/dstu2/openapi.json" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-data-query-metadata \
  -a host=sandbox-api.va.gov \
  -a url="/services/fhir/v0/argonaut/data-query/metadata" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-data-query-openapi \
  -a host=sandbox-api.va.gov \
  -a url="/services/fhir/v0/argonaut/data-query/openapi.json" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template https-public-200 \
  -a name=sandbox-community-care-openapi \
  -a host=sandbox-api.va.gov \
  -a url="/services/community-care/v0/eligibility/openapi.json" \
  -a port="443" \
  -a responsetime_threshold=10000 \
  -a resolution=1 \
  -a group=metadata \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

#
# Claims Health Checks
#
PRODUCTION_CLAIMS_API_KEY=$(get-secret "/production/claims/api-key")
SANDBOX_CLAIMS_API_KEY=$(get-secret "/sandbox/claims/api-key")

# v0
pingdom save-check \
  --template request-with-apikey \
  -a name=production-claims-v0-health-check \
  -a host=api.va.gov \
  -a url="/services/claims/v0/healthcheck" \
  -a apikey="$PRODUCTION_CLAIMS_API_KEY" \
  -a group="claims" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template request-with-apikey \
  -a name=sandbox-claims-v0-health-check \
  -a host=sandbox-api.va.gov \
  -a url="/services/claims/v0/healthcheck" \
  -a apikey="$SANDBOX_CLAIMS_API_KEY" \
  -a group="claims" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

# v1
pingdom save-check \
  --template request-with-apikey \
  -a name=production-claims-v1-health-check \
  -a host=api.va.gov \
  -a url="/services/claims/v1/healthcheck" \
  -a apikey="$PRODUCTION_CLAIMS_API_KEY" \
  -a group="claims" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template request-with-apikey \
  -a name=sandbox-claims-v1-health-check \
  -a host=sandbox-api.va.gov \
  -a url="/services/claims/v1/healthcheck" \
  -a apikey="$SANDBOX_CLAIMS_API_KEY" \
  -a group="claims" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

#
# Documents API Health Checks
#
PRODUCTION_DOCUMENTS_API_KEY=$(get-secret "/production/documents/api-key")
SANDBOX_DOCUMENTS_API_KEY=$(get-secret "/sandbox/documents/api-key")

#v0
pingdom save-check \
  --template request-with-apikey \
  -a name=production-documents-v0-health-check \
  -a host=api.va.gov \
  -a url="/services/vba_documents/v0/healthcheck" \
  -a apikey="$PRODUCTION_DOCUMENTS_API_KEY" \
  -a group="documents" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template request-with-apikey \
  -a name=sandbox-documents-v0-health-check \
  -a host=sandbox-api.va.gov \
  -a url="/services/vba_documents/v0/healthcheck" \
  -a apikey="$SANDBOX_DOCUMENTS_API_KEY" \
  -a group="documents" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

#v1
pingdom save-check \
  --template request-with-apikey \
  -a name=production-documents-v1-health-check \
  -a host=api.va.gov \
  -a url="/services/vba_documents/v1/healthcheck" \
  -a apikey="$PRODUCTION_DOCUMENTS_API_KEY" \
  -a group="documents" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template request-with-apikey \
  -a name=sandbox-documents-v1-health-check \
  -a host=sandbox-api.va.gov \
  -a url="/services/vba_documents/v1/healthcheck" \
  -a apikey="$SANDBOX_DOCUMENTS_API_KEY" \
  -a group="documents" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"



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
