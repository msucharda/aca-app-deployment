targetScope = 'resourceGroup'

@description('Base name for the SQL resources')
param name string

@description('Location for the SQL resources')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for SQL')
param privateDnsZoneId string

@description('Principal ID of the managed identity')
param managedIdentityPrincipalId string

@description('Name of the SQL database')
param databaseName string = 'appdb'

@description('SQL Database SKU name')
param skuName string = 'Basic'

@description('Entra admin object ID for the SQL server')
param entraAdminObjectId string

@description('Entra admin login name')
param entraAdminLogin string

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${name}-${resourceSuffix}'
  location: location
  tags: tags
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: entraAdminLogin
      sid: entraAdminObjectId
      principalType: 'Group'
      tenantId: subscription().tenantId
    }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
  }
}

// SQL DB Contributor role
resource sqlContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sqlServer
  name: guid(sqlServer.id, managedIdentityPrincipalId, '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${sqlServer.name}-pe'
  params: {
    name: 'pe-${sqlServer.name}'
    location: location
    tags: tags
    serviceResourceId: sqlServer.id
    groupId: 'sqlServer'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = sqlServer.id
output name string = sqlServer.name
output fqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = sqlDatabase.name
