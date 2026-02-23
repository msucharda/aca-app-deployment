targetScope = 'resourceGroup'

@description('Name of the VNet')
param name string

@description('Location for the VNet')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Address space for the VNet')
param addressPrefix string = '10.0.0.0/22'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }
}

output name string = vnet.name
output id string = vnet.id
