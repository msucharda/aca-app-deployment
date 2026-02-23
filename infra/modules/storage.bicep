targetScope = 'resourceGroup'

@description('Base name for the storage account')
param name string

@description('Location for the storage account')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the private endpoint')
param peSubnetId string

@description('Private DNS zone ID for file service')
param privateDnsZoneId string

@description('Principal ID of the managed identity')
param managedIdentityPrincipalId string

@description('Name of the file share')
param fileShareName string = 'appdata'

var resourceSuffix = take(uniqueString(subscription().id, resourceGroup().name, name), 6)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: replace('${name}${resourceSuffix}', '-', '')
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

// Storage File Data SMB Share Contributor
resource fileShareContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, managedIdentityPrincipalId, '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: '${storageAccount.name}-file-pe'
  params: {
    name: 'pe-${storageAccount.name}-file'
    location: location
    tags: tags
    serviceResourceId: storageAccount.id
    groupId: 'file'
    subnetId: peSubnetId
    privateDnsZoneId: privateDnsZoneId
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
output fileShareName string = fileShare.name
