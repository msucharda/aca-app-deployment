targetScope = 'resourceGroup'

@description('Base name for the container registry')
param name string

@description('Location for the container registry')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for ACR')
param privateDnsZoneId string

@description('Principal ID of the managed identity to grant AcrPull')
param managedIdentityPrincipalId string

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: replace('${name}${resourceSuffix}', '-', '')
  location: location
  tags: tags
  sku: {
    name: 'Premium' // Required for private endpoints
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// AcrPull role assignment — must be defined before any container apps
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, managedIdentityPrincipalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${acr.name}-pe'
  params: {
    name: 'pe-${acr.name}'
    location: location
    tags: tags
    serviceResourceId: acr.id
    groupId: 'registry'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = acr.id
output name string = acr.name
output loginServer string = acr.properties.loginServer
