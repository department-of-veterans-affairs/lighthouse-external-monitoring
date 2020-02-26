#!/usr/bin/env bash
set -euo pipefail

#
# For local test, create a secrets file and set environment variables typically
# created as Jenkins secrets.
#
if [ -f ./secrets.conf ];then . secrets.conf; fi


export PATH=$WORKSPACE/bin:$PATH
if [ "${DEBUG:-false}" == "true" ]; then export DEBUG; fi


HEALTH_APIS_SLACK_ID=100343
OAUTH_SLACK_ID=100343
SSL_EXPIRATION_SLACK_ID=100343
FACILITIES_SLACK_ID=100343
ADDRESS_VALIDATION_SLACK_ID=100343


#
# Address Validation
#
pingdom save-check \
  --template post-request-with-apikey \
  -a name=production-address-validation \
  -a host=api.va.gov \
  -a url="/services/address_validation/v1/candidate" \
  -a group=address-validation \
  -a apikey="$PRODUCTION_HEALTH_CHECK_API_KEY" \
  -a postdata="$(escape-json '{"requestAddress": {"addressLine1": "1600 Pennsylvania Ave", "city": "Washington", "stateProvince": {"name": "DC"}, "requestCountry": {"countryName": "USA"}}}')" \
  -a integrationids_csv="$ADDRESS_VALIDATION_SLACK_ID"

#
# Facilities
#
pingdom save-check \
  --template request-with-apikey \
  -a name=production-facilities \
  -a host=api.va.gov \
  -a url="/services/va_facilities/v0/facilities?lat=41.881832&long=-87.6233&limit=1" \
  -a group=facilities \
  -a apikey="$PRODUCTION_HEALTH_CHECK_API_KEY" \
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
  -a host=api.va.gov \
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
  -a authorization_token="$ARGONAUT_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template fhir-resource \
  -a name=production-dstu2-condition \
  -a host=api.va.gov \
  -a url="/services/fhir/v0/dstu2/Condition?patient=1011537977V693883" \
  -a authorization_token="$ARGONAUT_TOKEN" \
  -a integrationids_csv="$HEALTH_APIS_SLACK_ID"

pingdom save-check \
  --template fhir-resource \
  -a name=production-dstu2-medication-statement \
  -a host=api.va.gov \
  -a url="/services/fhir/v0/dstu2/MedicationStatement?patient=1011537977V693883" \
  -a authorization_token="$ARGONAUT_TOKEN" \
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
  -a authorization_token="$ARGONAUT_TOKEN" \
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
# api.va.gov/services/claims/v0/healthcheck
# api.va.gov/services/claims/v1/healthcheck
# api.va.gov/services/vba_documents/v0/healthcheck
# api.va.gov/services/vba_documents/v1/healthcheck
# api.va.gov/services/va_facilities/v0/facilities?lat=41.881832&long=87.6233&limit=1
# api.va.gov/services/address_validation/v1/candidate
# api.va.gov/services/fhir/v0/r4/metadata
# api.va.gov/services/fhir/v0/r4/openapi.json
# api.va.gov/services/fhir/v0/dstu2/metadata
# api.va.gov/services/fhir/v0/dstu2/openapi.json
# api.va.gov/services/fhir/v0/argonaut/dataquery/metadata
# api.va.gov/services/fhir/v0/argonaut/dataquery/openapi.json
# api.va.gov/services/communitycare/v0/eligibility/openapi.json
#
