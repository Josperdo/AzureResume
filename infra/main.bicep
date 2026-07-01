targetScope = 'resourceGroup'

@description('Azure region for the Cosmos DB account.')
param location string = resourceGroup().location

@description('Azure region for the Static Web App. SWA is only available in a small subset of regions (centralus, eastus2, westus2, westeurope, eastasia) -- unlike Cosmos DB, which is available almost everywhere, so this is intentionally a separate param from `location`.')
param staticWebAppLocation string = 'eastus2'

@description('Base name used to derive resource names.')
param appName string = 'azureresume'

// Cosmos DB account names must be globally unique (they form part of the
// account's public DNS name) -- Static Web App resource names only need to be
// unique within the resource group, so no uniqueString() needed there.
var cosmosAccountName = toLower('${appName}-${uniqueString(resourceGroup().id)}')

module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos-deployment'
  params: {
    location: location
    cosmosAccountName: cosmosAccountName
  }
}

module staticWebApp 'modules/staticWebApp.bicep' = {
  name: 'static-web-app-deployment'
  params: {
    location: staticWebAppLocation
    staticSiteName: appName
    cosmosAccountName: cosmosAccountName
  }
  dependsOn: [
    cosmos
  ]
}

// No monitoring module wired in yet -- Application Insights / Log Analytics
// are explicitly phase 2, not MVP. See ROADMAP.md.

output staticSiteName string = staticWebApp.outputs.staticSiteName
output staticSiteDefaultHostname string = staticWebApp.outputs.defaultHostname
output cosmosAccountName string = cosmosAccountName
