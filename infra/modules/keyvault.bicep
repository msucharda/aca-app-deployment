targetScope = 'resourceGroup'

@description('Base name for the Key Vault')
param name string

@description('Location for the Key Vault')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for Key Vault')
param privateDnsZoneId string

@description('Principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: take('kv${replace(name, '-', '')}${resourceSuffix}', 24)
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Key Vault Secrets User role
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, managedIdentityPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${keyVault.name}-pe'
  params: {
    name: 'pe-${keyVault.name}'
    location: location
    tags: tags
    serviceResourceId: keyVault.id
    groupId: 'vault'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
