@description('Azure region for the Cosmos DB account.')
param location string

@description('Name of the Cosmos DB account (must be globally unique).')
param cosmosAccountName string

@description('Name of the Cosmos SQL database.')
param databaseName string = 'resume'

@description('Name of the Cosmos SQL container.')
param containerName string = 'counters'

// Provisioned throughput with enableFreeTier: true -- NOT serverless. Cosmos's
// free tier (1000 RU/s + 25GB) only applies to provisioned/autoscale accounts,
// confirmed against current Microsoft Learn docs. See ROADMAP.md / Security.md #4.
resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2026-03-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: true
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

// Shared throughput at the database level (400 RU/s, within the free-tier
// allotment). The container below has no dedicated throughput of its own and
// inherits this -- avoids double-provisioning RU/s across db + container.
resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2026-03-15' = {
  parent: databaseAccount
  name: databaseName
  properties: {
    options: {
      throughput: 400
    }
    resource: {
      id: databaseName
    }
  }
}

// Partition key path is /id -- function_app.py reads/writes a single item
// whose id and partition key value are both the fixed constant "visitor-count"
// (see COUNTER_ID in function_app.py). No externally-supplied value is ever
// used as a partition key or document id.
resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2026-03-15' = {
  parent: sqlDatabase
  name: containerName
  properties: {
    options: {}
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
}

output accountName string = databaseAccount.name
output databaseName string = sqlDatabase.name
output containerName string = container.name
