standardShellPipeline {
  dockerRegistryUrl = 'https://ghcr.io'
  dockerRegistryCredentialsId = 'GITHUB_USERNAME_PASSWORD'
  credentials = [ string( credentialsId: 'SLACK_WEBHOOK', variable: 'SLACK_WEBHOOK' ) ]
  slackDestinations = [ 'shankins@${env.SLACK_WEBHOOK}' ]
}