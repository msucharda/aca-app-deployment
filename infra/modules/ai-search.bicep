targetScope = 'resourceGroup'

@description('Base name for the AI Search service')
param name string

@description('Location for the AI Search service')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for Search')
param privateDnsZoneId string

@description('Principal ID of the managed identity')
param managedIdentityPrincipalId string

@description('SKU for the search service')
param skuName string = 'basic'

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: '${name}-${resourceSuffix}'
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    publicNetworkAccess: 'disabled'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// Search Index Data Reader role
resource searchReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, managedIdentityPrincipalId, '1407120a-92aa-4202-b7e9-c0e197c71c8f')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${searchService.name}-pe'
  params: {
    name: 'pe-${searchService.name}'
    location: location
    tags: tags
    serviceResourceId: searchService.id
    groupId: 'searchService'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = searchService.id
output name string = searchService.name
