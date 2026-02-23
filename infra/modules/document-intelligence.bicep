targetScope = 'resourceGroup'

@description('Base name for the Document Intelligence resource')
param name string

@description('Location for the Document Intelligence resource')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for Cognitive Services')
param privateDnsZoneId string

@description('Principal ID of the managed identity')
param managedIdentityPrincipalId string

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource docIntelligence 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${name}-${resourceSuffix}'
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${name}-${resourceSuffix}'
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
    disableLocalAuth: true
  }
}

// Cognitive Services User role
resource cognitiveServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: docIntelligence
  name: guid(docIntelligence.id, managedIdentityPrincipalId, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${docIntelligence.name}-pe'
  params: {
    name: 'pe-${docIntelligence.name}'
    location: location
    tags: tags
    serviceResourceId: docIntelligence.id
    groupId: 'account'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = docIntelligence.id
output name string = docIntelligence.name
output endpoint string = docIntelligence.properties.endpoint
