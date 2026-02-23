targetScope = 'resourceGroup'

@description('Name of the VNet')
param vnetName string

@description('Whether to create a new VNet')
param createVnet bool = false

@description('Address space for the VNet (only used when createVnet=true)')
param vnetAddressPrefix string = '10.0.0.0/22'

@description('Location for VNet (only used when createVnet=true)')
param location string = resourceGroup().location

@description('Tags (only used when createVnet=true)')
param tags object = {}

@description('Address prefix for the ACA subnet')
param acaSubnetAddressPrefix string

@description('Address prefix for the private endpoint subnet')
param privateEndpointSubnetAddressPrefix string

// Create VNet if requested, otherwise reference existing
resource newVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (createVnet) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (!createVnet) {
  name: vnetName
}

// Use the ID from whichever VNet resource is active
var vnetId = createVnet ? newVnet.id : existingVnet.id

resource acaSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${vnetName}/snet-aca'
  dependsOn: [newVnet]
  properties: {
    addressPrefix: acaSubnetAddressPrefix
    delegations: [
      {
        name: 'Microsoft.App.environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${vnetName}/snet-pe'
  dependsOn: [acaSubnet]
  properties: {
    addressPrefix: privateEndpointSubnetAddressPrefix
  }
}

// Private DNS Zones
var dnsZones = [
  'privatelink.azurecr.io'
  'privatelink.vaultcore.azure.net'
  'privatelink.database.windows.net'
  'privatelink.search.windows.net'
  'privatelink.openai.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.file.core.windows.net'
]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in dnsZones: {
    name: zone
    location: 'global'
  }
]

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in dnsZones: {
    parent: privateDnsZones[i]
    name: '${vnetName}-link'
    location: 'global'
    dependsOn: [acaSubnet] // ensures VNet exists before linking
    properties: {
      virtualNetwork: {
        id: vnetId
      }
      registrationEnabled: false
    }
  }
]

output acaSubnetId string = acaSubnet.id
output peSubnetId string = peSubnet.id
output vnetId string = vnetId

output dnsZoneIds object = {
  acr: privateDnsZones[0].id
  keyVault: privateDnsZones[1].id
  sql: privateDnsZones[2].id
  search: privateDnsZones[3].id
  openai: privateDnsZones[4].id
  cognitiveServices: privateDnsZones[5].id
  file: privateDnsZones[6].id
}
