# Infrastructure Deployment Guide

## Architecture Overview

This Bicep infrastructure deploys an Azure Container Apps (ACA) application with supporting AI and data services, all connected via private endpoints to a VNet.

### Resources

| Resource | Private Endpoint | Notes |
|---|---|---|
| Resource Group | — | Contains all resources |
| VNet + Subnets | — | Created or existing; 2 subnets (`snet-aca`, `snet-pe`) |
| User-Assigned Managed Identity | — | Shared identity for ACA and role assignments |
| Log Analytics + App Insights | — | Monitoring |
| Azure Container Registry | ✅ | Premium SKU; AcrPull role for MI |
| Azure Container Apps Environment | — | VNet-integrated, internal, Consumption workload profile |
| Azure Container App | — | File share mount, MI, ACR registry |
| Storage Account + File Share | ✅ | Local auth disabled; mounted to ACA at `/mnt/fileshare` |
| Key Vault | ✅ | RBAC mode; purge protection enabled |
| Azure SQL Server + Database | ✅ | Entra admin + SQL password auth; end users use managed identities |
| Azure AI Search | ✅ | Basic SKU |
| Azure OpenAI | ✅ | Cognitive Services OpenAI User role for MI |
| Document Intelligence | ✅ | Cognitive Services User role for MI |
| Azure Bastion | — | Developer SKU; no dedicated subnet or public IP required |
| Windows 11 VM (Jumpbox) | — | Standard_B2s; accessed via Bastion |

All services have **public network access disabled** except ACA (which is VNet-internal). Seven private DNS zones are created and linked to the VNet.

### Network Layout (default /22 VNet)

```
VNet: 10.0.0.0/22
├── snet-aca:     10.0.0.0/25    (128 IPs — ACA Environment, delegated to Microsoft.App/environments)
├── snet-pe:      10.0.0.128/25  (128 IPs — Private Endpoints)
└── snet-jumpbox: 10.0.1.0/28    (16 IPs  — Jumpbox VM)
```

> **Note:** ACA with Workload Profiles (Consumption) supports subnets as small as /27. The default /25 provides ample room. The old /23 minimum only applies to legacy Consumption-only environments.

## Prerequisites

1. **Azure CLI** with Bicep extension (`az bicep version` — tested with v0.39+)
2. **Azure subscription** with Contributor + User Access Administrator roles
3. **Existing VNet** (or set `createVnet=true` to have Bicep create one)
4. **SQL Entra admin** — the Object ID and UPN of the user/group to be SQL admin
5. **SQL admin credentials** — login and password for SQL Server password authentication
6. **Jumpbox admin credentials** — login and password for the Windows 11 jumpbox VM

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `environmentName` | ✅ | — | Used for resource naming (e.g., `myapp`) |
| `location` | ✅ | — | Azure region (e.g., `swedencentral`) |
| `createVnet` | | `false` | `true` to create a new VNet |
| `vnetResourceGroupName` | when `createVnet=false` | — | Resource group of existing VNet |
| `vnetName` | when `createVnet=false` | — | Name of existing VNet |
| `vnetAddressPrefix` | when `createVnet=true` | `10.0.0.0/22` | VNet CIDR |
| `acaSubnetAddressPrefix` | | `10.0.0.0/25` | ACA subnet CIDR (min /27) |
| `privateEndpointSubnetAddressPrefix` | | `10.0.0.128/25` | PE subnet CIDR |
| `jumpboxSubnetAddressPrefix` | | `10.0.1.0/28` | Jumpbox VM subnet CIDR |
| `sqlDatabaseName` | | `appdb` | SQL database name |
| `sqlEntraAdminObjectId` | ✅ | — | Entra admin Object ID |
| `sqlEntraAdminLogin` | ✅ | — | Entra admin UPN |
| `sqlAdminLogin` | ✅ | — | SQL Server admin login (server management only) |
| `sqlAdminPassword` | ✅ | — | SQL Server admin password (secure) |
| `sqlServiceLogin` | ✅ | — | SQL service account login (for application use) |
| `sqlServicePassword` | ✅ | — | SQL service account password (secure) |
| `jumpboxAdminUsername` | | `azureadmin` | Jumpbox VM admin username |
| `jumpboxAdminPassword` | ✅ | — | Jumpbox VM admin password (secure) |
| `tags` | | `{}` | Resource tags |

## Deployment

### Option 1: Create a new VNet

```bash
az deployment sub create \
  --name my-deployment \
  --location swedencentral \
  --template-file infra/main.bicep \
  --parameters \
    environmentName=myapp \
    location=swedencentral \
    createVnet=true \
    vnetAddressPrefix='10.0.0.0/22' \
    acaSubnetAddressPrefix='10.0.0.0/25' \
    privateEndpointSubnetAddressPrefix='10.0.0.128/25' \
    sqlEntraAdminObjectId=<your-object-id> \
    sqlEntraAdminLogin=<your-upn> \
    sqlAdminLogin=<sql-admin-login> \
    sqlAdminPassword=<sql-admin-password> \
    sqlServiceLogin=<sql-service-login> \
    sqlServicePassword=<sql-service-password> \
    jumpboxAdminPassword=<jumpbox-password>
```

### Option 2: Use an existing VNet

```bash
az deployment sub create \
  --name my-deployment \
  --location swedencentral \
  --template-file infra/main.bicep \
  --parameters \
    environmentName=myapp \
    location=swedencentral \
    createVnet=false \
    vnetResourceGroupName=rg-networking \
    vnetName=my-existing-vnet \
    acaSubnetAddressPrefix='10.0.0.0/25' \
    privateEndpointSubnetAddressPrefix='10.0.0.128/25' \
    sqlEntraAdminObjectId=<your-object-id> \
    sqlEntraAdminLogin=<your-upn> \
    sqlAdminLogin=<sql-admin-login> \
    sqlAdminPassword=<sql-admin-password> \
    sqlServiceLogin=<sql-service-login> \
    sqlServicePassword=<sql-service-password> \
    jumpboxAdminPassword=<jumpbox-password>
```

> When using an existing VNet, the subnets and private DNS zones are created inside the VNet's resource group.

### Option 3: AZD (Azure Developer CLI)

The parameters file supports AZD environment variable syntax:

```bash
azd env set AZURE_ENV_NAME myapp
azd env set AZURE_LOCATION swedencentral
azd env set AZURE_CREATE_VNET true
azd env set AZURE_SQL_ENTRA_ADMIN_OBJECT_ID <your-object-id>
azd env set AZURE_SQL_ENTRA_ADMIN_LOGIN <your-upn>
azd env set AZURE_SQL_ADMIN_LOGIN <sql-admin-login>
azd env set AZURE_SQL_ADMIN_PASSWORD <sql-admin-password>
azd env set AZURE_SQL_SERVICE_LOGIN <sql-service-login>
azd env set AZURE_SQL_SERVICE_PASSWORD <sql-service-password>
azd env set AZURE_JUMPBOX_ADMIN_PASSWORD <jumpbox-password>
azd provision
```

### Finding your Entra Admin Object ID

```bash
# Current logged-in user
az ad signed-in-user show --query id -o tsv

# By UPN
az ad user show --id user@domain.com --query id -o tsv
```

## Outputs

After deployment, these values are available:

| Output | Description |
|---|---|
| `RESOURCE_GROUP_NAME` | Deployed resource group |
| `ACA_APP_FQDN` | ACA application FQDN (internal) |
| `ACA_ENV_NAME` | ACA environment name |
| `SQL_SERVER_FQDN` | SQL Server FQDN |
| `SQL_DATABASE_NAME` | SQL database name |
| `SQL_SERVICE_LOGIN` | SQL service account login (for application use) |
| `OPENAI_ENDPOINT` | Azure OpenAI endpoint URL |
| `DOC_INTELLIGENCE_ENDPOINT` | Document Intelligence endpoint URL |
| `MANAGED_IDENTITY_CLIENT_ID` | User-Assigned MI client ID |
| `KEY_VAULT_NAME` | Key Vault name |
| `ACR_LOGIN_SERVER` | ACR login server |

```bash
az deployment sub show --name my-deployment --query properties.outputs -o json
```

## Post-Deployment: Create SQL Service Account

The SQL server admin credentials are for management only. After deployment, connect to the SQL server via the jumpbox (using Bastion) and run the following T-SQL to create the service account:

```sql
-- Connect to the master database as admin
CREATE LOGIN [<sqlServiceLogin>] WITH PASSWORD = '<sqlServicePassword>';

-- Switch to the application database
USE [appdb];
CREATE USER [<sqlServiceLogin>] FOR LOGIN [<sqlServiceLogin>];
ALTER ROLE db_datareader ADD MEMBER [<sqlServiceLogin>];
ALTER ROLE db_datawriter ADD MEMBER [<sqlServiceLogin>];
```

> Replace `<sqlServiceLogin>` and `<sqlServicePassword>` with the values provided during deployment. Adjust roles as needed — `db_datareader` and `db_datawriter` are a reasonable default for application services.

## Security

- All services except ACA use private endpoints with public network access disabled
- ACA has public ingress enabled — accessible from the internet via its FQDN
- SQL supports both Entra ID and password authentication; end users connect via Entra (managed identities), services use a dedicated service account (never the server admin)
- SQL admin credentials are for server management only — applications must use the service account
- Jumpbox VM is accessible only via Azure Bastion (no public IP on the VM)
- Storage Account has local auth disabled (`allowSharedKeyAccess: false`)
- Key Vault uses RBAC authorization (no access policies)
- User-Assigned Managed Identity has least-privilege RBAC roles on each service
- ACR requires authentication (no anonymous pull)

## File Structure

```
infra/
├── main.bicep                          # Subscription-scoped orchestrator
├── main.parameters.json                # AZD-compatible parameters
├── README.md                           # This file
└── modules/
    ├── networking.bicep                # VNet (optional), subnets, DNS zones
    ├── identity.bicep                  # User-Assigned Managed Identity
    ├── monitoring.bicep                # Log Analytics + App Insights
    ├── keyvault.bicep                  # Key Vault + PE
    ├── acr.bicep                       # Container Registry + PE
    ├── storage.bicep                   # Storage Account + File Share + PE
    ├── aca-env.bicep                   # ACA Environment (VNet-integrated)
    ├── aca-app.bicep                   # Container App (file share, MI)
    ├── sql.bicep                       # SQL Server + Database + PE
    ├── jumpbox.bicep                   # Windows 11 VM + Azure Bastion Basic
    ├── ai-search.bicep                 # Azure AI Search + PE
    ├── openai.bicep                    # Azure OpenAI + PE
    ├── document-intelligence.bicep     # Document Intelligence + PE
    └── private-endpoint.bicep          # Reusable PE + DNS zone group
```

## Cleanup

```bash
az group delete --name rg-<environmentName> --yes
```

> Soft-deleted Key Vaults and Cognitive Services accounts may need manual purging before redeploying with the same names. Cognitive Services: `az cognitiveservices account purge`. Key Vault: `az keyvault purge --name <name>` (if purge protection allows).
