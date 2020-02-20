# lighthouse-external-monitoring

Configuration and tooling for automated configuration for monitoring APIs from an external perspective.

#### Requirements
- Monitor APIs from the external client perspective, i.e. from outside the VA network.
- Provide alerts of outages via Slack and PagerDuty, where different APIs report to different
  Slack channels and/or have different PagerDuty escalation paths.
- Provide real time availability status to consumers via Statuspage.

#### Design Goals
- Self service health check model. API teams can add their own checks that are deployed automatically.
- Increased resiliency by reducing the number of components.
- Simplify maintenance with a focused repository that is not co-mingled with unrelated items. 
- Broader external perspective. Monitor APIs from outside of the VA and AWS networks.
- Configuration changes must be applied to different environments at different times, e.g.
  monitoring changes may be applied to dev-api.va.gov before they are applied to api.va.gov.

#### Is/Is Not
This repository
- IS responsible for automated configuration of health checks.
- IS NOT responsible for Statuspage, PagerDuty, or Slack configuration,
  e.g. this repository would link check api.va.gov/services/fhir/v0/dstu2/metadata to the
  _on-call-support_ escalation policy in PagerDuty, but not define the escalation policy itself. 
- IS NOT responsible for _in VA network_ checks, e.g. DNS look up of internal assets.

#### Check Requirements
A _check_ is a periodic API service call that is validated to determine a service is available. 
It mimics external usage.
 
- Support HTTP and HTTPS protocols.
- Support GET and POST methods.
- Support network connectivity DNS look ups and Ping checks.
- Ability to specify customer HTTP request headers, e.g. client keys.
- Ability to specify query parameters.
- Ability to verify expected status codes.
- Ability to verify response content by string comparison (contains/not contains)
- Ability to include sensitive information via secret management, e.g. client key, in configuration.
- Ability to specify frequency, time for down, alert frequency.

---

# Pingdom Monitoring

Pingdom will be used to provide all public API availability checks.

Pingdom will be integrated with
- Slack to provide notification to teams,
- PagerDuty to provide alerts to on-call support and provides escalation policies,
- Statuspage to provide real-time updates.

> _Note:_ 
> This approach replaces Blackbox Exporter, Prometheus, and Statuspage Forwarder currently used.
> Blackbox Exporter and Prometheus will continue to be used for other aspects of monitoring, 
> at least for the near future.
> Statuspage Forwarder can be completely decommissioned and it's codebase archived.

![Components](docs/components.png)

### Implementation details
- Pingdom API provides the ability to create/update checks.
- This repository will house Pingdom check configuration, 
  per [Pingdom Check API](https://docs.pingdom.com/api/#tag/Checks/paths/~1checks/post).
- This repository will provide the tooling to apply Pingdom configuration changes via Jenkins or 
  AWS CodeBuild.
- Secret management and substitution will be provided (mechanism TBD)