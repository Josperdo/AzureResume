@description('Azure region for the Static Web App.')
param location string

@description('Name of the Static Web App.')
param staticSiteName string

@description('Name of the already-deployed Cosmos DB account to pull the connection string from.')
param cosmosAccountName string

// FREE tier, SWA-managed Functions (no BYOF / linkedBackends -- that requires
// Standard, ~$9-12/mo, which blew this project's budget). See ROADMAP.md /
// Security.md #1 for the full reasoning behind this trade-off.
resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: staticSiteName
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

// Existing reference, not a new resource -- the account itself is created by
// modules/cosmos.bicep. main.bicep sequences this module after that one via
// an explicit dependsOn (this param is a plain string, not a module output,
// so Bicep can't infer the dependency automatically).
resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2026-03-15' existing = {
  name: cosmosAccountName
}

// Resolved live at deploy time via listConnectionStrings() -- never written to
// a parameter file, GitHub secret, or module output (this module doesn't
// output it). Filtered by description rather than trusting the returned
// array's index ordering as a guaranteed contract. See Security.md #1-#2.
var cosmosConnectionStrings = databaseAccount.listConnectionStrings().connectionStrings
// Non-null assertion: Cosmos's documented list-connection-strings response
// always includes a "Primary SQL Connection String" entry for Core/SQL API
// accounts, so this is safe -- but it's an assumption about an external API
// response shape, not something Bicep can verify statically.
var primaryConnectionString = first(filter(cosmosConnectionStrings, cs => cs.description == 'Primary SQL Connection String'))!

resource functionAppSettings 'Microsoft.Web/staticSites/config@2022-09-01' = {
  parent: staticSite
  name: 'functionappsettings'
  properties: {
    COSMOS_CONNECTION_STRING: primaryConnectionString.connectionString
  }
}

output staticSiteName string = staticSite.name
output defaultHostname string = staticSite.properties.defaultHostname
