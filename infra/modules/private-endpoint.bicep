targetScope = 'resourceGroup'

@description('Name for the private endpoint')
param name string

@description('Location for the private endpoint')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Resource ID of the target service')
param serviceResourceId string

@description('Group ID for the private endpoint (e.g., vault, sqlServer, searchService)')
param groupId string

@description('Subnet ID for the private endpoint')
param subnetId string

@description('Resource ID of the private DNS zone')
param privateDnsZoneId string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: serviceResourceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(split(privateDnsZoneId, '/')[8], '.', '-')
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output id string = privateEndpoint.id
