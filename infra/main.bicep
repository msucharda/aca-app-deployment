targetScope = 'subscription'

@description('Name of the environment (used for resource naming)')
param environmentName string

@description('Primary location for all resources')
param location string

@description('Whether to create a new VNet or use an existing one')
param createVnet bool = false

@description('Resource group name of the existing VNet (ignored when createVnet=true)')
param vnetResourceGroupName string = ''

@description('Name of the existing VNet (ignored when createVnet=true)')
param vnetName string = ''

@description('Address prefix for the VNet (only used when createVnet=true)')
param vnetAddressPrefix string = '10.0.0.0/24'

@description('Address prefix for the ACA subnet (minimum /27 with workload profiles)')
param acaSubnetAddressPrefix string = '10.0.0.0/25'

@description('Address prefix for the private endpoint subnet (e.g., 10.0.0.128/25)')
param privateEndpointSubnetAddressPrefix string = '10.0.0.128/25'

@description('Name of the SQL database')
param sqlDatabaseName string = 'appdb'

@description('Entra admin object ID for SQL Server')
param sqlEntraAdminObjectId string

@description('Entra admin login name for SQL Server')
param sqlEntraAdminLogin string

@description('Tags to apply to all resources')
param tags object = {}

// --- Naming ---
var resourceSuffix = take(uniqueString(subscription().id, environmentName, location), 6)
var resourceGroupName = 'rg-${environmentName}'
var baseName = '${environmentName}-${resourceSuffix}'

var allTags = union(tags, {
  'azd-env-name': environmentName
})

// --- Resource Group ---
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: allTags
}

// --- VNet + Networking ---
// When createVnet=true, everything goes into the main RG.
// When createVnet=false, networking deploys into the existing VNet's RG.

resource vnetRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!createVnet) {
  name: !empty(vnetResourceGroupName) ? vnetResourceGroupName : 'placeholder'
}

var effectiveVnetName = createVnet ? 'vnet-${baseName}' : vnetName

module networkingNew 'modules/networking.bicep' = if (createVnet) {
  name: 'networking'
  scope: rg
  params: {
    vnetName: effectiveVnetName
    createVnet: true
    vnetAddressPrefix: vnetAddressPrefix
    location: location
    tags: allTags
    acaSubnetAddressPrefix: acaSubnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
  }
}

module networkingExisting 'modules/networking.bicep' = if (!createVnet) {
  name: 'networking-existing'
  scope: vnetRg
  params: {
    vnetName: effectiveVnetName
    createVnet: false
    acaSubnetAddressPrefix: acaSubnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
  }
}

var peSubnetId = createVnet ? networkingNew.outputs.peSubnetId : networkingExisting.outputs.peSubnetId
var acaSubnetId = createVnet ? networkingNew.outputs.acaSubnetId : networkingExisting.outputs.acaSubnetId
var dnsZoneIds = createVnet ? networkingNew.outputs.dnsZoneIds : networkingExisting.outputs.dnsZoneIds

// --- User-Assigned Managed Identity ---
module identity 'modules/identity.bicep' = {
  name: 'identity'
  scope: rg
  params: {
    name: 'id-${baseName}'
    location: location
    tags: allTags
  }
}

// --- Monitoring ---
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    name: baseName
    location: location
    tags: allTags
  }
}

// --- Key Vault ---
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: environmentName
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.keyVault
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// --- Container Registry ---
module acr 'modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    name: 'acr${environmentName}'
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.acr
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// --- Storage Account + File Share ---
module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: 'st${environmentName}'
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.file
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// --- ACA Environment ---
module acaEnv 'modules/aca-env.bicep' = {
  name: 'aca-env'
  scope: rg
  params: {
    name: baseName
    location: location
    tags: allTags
    acaSubnetId: acaSubnetId
    logAnalyticsCustomerId: monitoring.outputs.logAnalyticsWorkspaceCustomerId
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
}


// --- Azure SQL ---
module sql 'modules/sql.bicep' = {
  name: 'sql'
  scope: rg
  params: {
    name: 'sql-${environmentName}'
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.sql
    managedIdentityPrincipalId: identity.outputs.principalId
    databaseName: sqlDatabaseName
    entraAdminObjectId: sqlEntraAdminObjectId
    entraAdminLogin: sqlEntraAdminLogin
  }
}

// --- Azure AI Search ---
module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  scope: rg
  params: {
    name: 'srch-${environmentName}'
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.search
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// --- Azure OpenAI ---
module openai 'modules/openai.bicep' = {
  name: 'openai'
  scope: rg
  params: {
    name: 'oai-${environmentName}'
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.openai
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// --- Document Intelligence ---
module docIntelligence 'modules/document-intelligence.bicep' = {
  name: 'doc-intelligence'
  scope: rg
  params: {
    name: 'di-${environmentName}'
    location: location
    tags: allTags
    peSubnetId: peSubnetId
    privateDnsZoneId: dnsZoneIds.cognitiveServices
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// --- Outputs ---
output RESOURCE_GROUP_NAME string = rg.name
output ACA_ENV_NAME string = acaEnv.outputs.name
output SQL_SERVER_FQDN string = sql.outputs.fqdn
output SQL_DATABASE_NAME string = sql.outputs.databaseName
output OPENAI_ENDPOINT string = openai.outputs.endpoint
output DOC_INTELLIGENCE_ENDPOINT string = docIntelligence.outputs.endpoint
output MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.clientId
output KEY_VAULT_NAME string = keyVault.outputs.name
output ACR_LOGIN_SERVER string = acr.outputs.loginServer
