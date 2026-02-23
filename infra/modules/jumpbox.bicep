targetScope = 'resourceGroup'

@description('Base name for jumpbox resources')
param name string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags to apply')
param tags object = {}

@description('Subnet ID for the jumpbox VM')
param vmSubnetId string

@description('VNet ID for Azure Bastion Developer SKU')
param vnetId string

@description('VM admin username')
param adminUsername string

@secure()
@description('VM admin password')
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_B2s'

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-${name}'
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${name}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnetId
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${name}'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: take('vm${name}', 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmName string = vm.name
output bastionName string = bastionHost.name
