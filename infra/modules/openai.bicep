targetScope = 'resourceGroup'

@description('Base name for the OpenAI resource')
param name string

@description('Location for the OpenAI resource')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for OpenAI')
param privateDnsZoneId string

@description('Principal ID of the managed identity')
param managedIdentityPrincipalId string

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource openai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${name}-${resourceSuffix}'
  location: location
  tags: tags
  kind: 'OpenAI'
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

// Cognitive Services OpenAI User role
resource openaiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openai
  name: guid(openai.id, managedIdentityPrincipalId, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${openai.name}-pe'
  params: {
    name: 'pe-${openai.name}'
    location: location
    tags: tags
    serviceResourceId: openai.id
    groupId: 'account'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = openai.id
output name string = openai.name
output endpoint string = openai.properties.endpoint
