# Authentication Modes & Patterns

This document outlines the authentication strategies used across the portfolio, covering local development, CI/CD pipelines, and production scenarios.

---

## 🔐 Authentication Overview

All scripts in this portfolio support multiple authentication modes to accommodate different execution contexts:

- **Interactive (Local Development)** - User-based authentication with browser prompts
- **Service Principal (CI/CD)** - Non-interactive authentication for pipelines
- **Managed Identity (Azure Resources)** - Identity-based authentication for Azure Automation, VMs, Functions
- **Federated Credentials (Modern CI/CD)** - OIDC-based authentication without secrets

---

## 📋 Authentication Modes by Context

### 1. Local Development / Interactive

**Use Case:** Running scripts manually from your workstation

**Authentication Methods:**
- `Connect-AzAccount` - Interactive browser-based login
- `Get-Credential` - Prompts for username/password (Windows/SQL authentication)
- Current user context (Windows Integrated Authentication)

**Example:**
```powershell
# Azure authentication
Connect-AzAccount -TenantId "your-tenant-id"

# SQL Server with Windows Auth (current user)
Invoke-Sqlcmd -ServerInstance "SQLSERVER01" -Database "master" -Query "SELECT @@VERSION"

# SQL Server with SQL Auth (prompted credentials)
$cred = Get-Credential
Invoke-Sqlcmd -ServerInstance "SQLSERVER01" -Credential $cred -Query "SELECT @@VERSION"
```

**Pros:**
- ✅ Simple and intuitive
- ✅ Uses your existing permissions
- ✅ MFA support via browser

**Cons:**
- ❌ Not suitable for automation
- ❌ Requires human interaction
- ❌ Session expires

---

### 2. Service Principal (CI/CD Pipelines)

**Use Case:** Azure DevOps pipelines, GitHub Actions, automated scripts

**Authentication Methods:**
- Service Principal with Client Secret
- Service Principal with Certificate
- Azure DevOps Service Connection

**Setup:**
```powershell
# Create Service Principal
$sp = New-AzADServicePrincipal -DisplayName "platform-automation-sp" -Role "Contributor"

# Assign specific permissions
New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Virtual Machine Contributor" -Scope "/subscriptions/{subscription-id}"
```

**Authentication in Scripts:**
```powershell
# Method 1: Client Secret (stored in Key Vault or pipeline variables)
$securePassword = ConvertTo-SecureString $env:SP_CLIENT_SECRET -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($env:SP_CLIENT_ID, $securePassword)
Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $env:TENANT_ID

# Method 2: Certificate-based (more secure)
Connect-AzAccount -ServicePrincipal -CertificateThumbprint $env:CERT_THUMBPRINT `
    -ApplicationId $env:SP_CLIENT_ID -TenantId $env:TENANT_ID
```

**Azure DevOps Pipeline Example:**
```yaml
steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'platform-automation-connection'  # Service Connection
    ScriptType: 'FilePath'
    ScriptPath: 'automation/powershell/scripts/examples/Set-AzureVmTagsFromPolicy.ps1'
    ScriptArguments: '-SubscriptionId $(subscriptionId) -Mode Apply'
    azurePowerShellVersion: 'LatestVersion'
```

**Pros:**
- ✅ Non-interactive (fully automated)
- ✅ Granular RBAC permissions
- ✅ Auditable (service principal actions are logged)
- ✅ Secrets can be rotated

**Cons:**
- ❌ Requires secret management
- ❌ Secrets can be compromised if not handled properly
- ❌ Additional setup overhead

**Security Best Practices:**
- 🔒 Store secrets in Azure Key Vault, never in code
- 🔒 Use certificate-based auth over client secrets when possible
- 🔒 Apply least-privilege permissions (specific roles, specific scopes)
- 🔒 Rotate secrets regularly (90-day maximum)
- 🔒 Enable audit logging for service principal activities

---

### 3. Managed Identity (Azure Resources)

**Use Case:** Azure Automation Runbooks, Azure VMs, Azure Functions, Container Instances

**Authentication Methods:**
- System-Assigned Managed Identity
- User-Assigned Managed Identity

**How It Works:**
- Azure automatically manages the identity lifecycle
- No secrets to store or rotate
- Identity is tied to the Azure resource
- Permissions assigned via RBAC

**Setup:**
```powershell
# Enable System-Assigned Managed Identity on Azure Automation Account
Set-AzAutomationAccount -ResourceGroupName "automation-rg" `
    -Name "platform-automation" `
    -AssignSystemIdentity

# Assign permissions to the Managed Identity
$automationAccount = Get-AzAutomationAccount -ResourceGroupName "automation-rg" -Name "platform-automation"
New-AzRoleAssignment -ObjectId $automationAccount.Identity.PrincipalId `
    -RoleDefinitionName "Virtual Machine Contributor" `
    -Scope "/subscriptions/{subscription-id}"
```

**Authentication in Runbooks:**
```powershell
# Azure Automation Runbook
# No credentials needed - uses the Automation Account's Managed Identity
Connect-AzAccount -Identity

# Get resources using the Managed Identity's permissions
Get-AzVM -ResourceGroupName "production-rg"
```

**Pros:**
- ✅ No secrets to manage
- ✅ Automatic credential rotation
- ✅ Tightly scoped to specific Azure resources
- ✅ Simplest and most secure option for Azure workloads

**Cons:**
- ❌ Only works within Azure
- ❌ Cannot be used for local development
- ❌ Limited to Azure resources that support Managed Identity

**Use Cases in This Portfolio:**
- `automation/azure-runbooks/Check-And-Start-VM.ps1` - Azure Automation Runbook
- `automation/azure-runbooks/Monitor-Backup-Health.ps1` - Azure Automation Runbook
- `automation/powershell/scripts/examples/Monitor-AzureADSecretExpirations-GraphSDK.ps1` - Azure AD secret monitoring (Microsoft Graph SDK)
- `observability/dynatrace/azure-runbooks/Monitor-AzureADSecretExpirations-DynatraceRunbook.ps1` - Azure AD monitoring with Dynatrace integration

---

### 4. Federated Credentials (OIDC - Modern CI/CD)

**Use Case:** GitHub Actions, Azure DevOps (modern), GitLab CI/CD

**How It Works:**
- Uses OpenID Connect (OIDC) tokens
- No long-lived secrets stored in CI/CD
- Trust relationship between CI/CD platform and Azure AD
- Tokens are short-lived and automatically issued

**Setup (GitHub Actions Example):**
```powershell
# Create App Registration
$app = New-AzADApplication -DisplayName "github-actions-oidc"

# Create Federated Credential
New-AzADAppFederatedCredential -ApplicationObjectId $app.Id `
    -Audience "api://AzureADTokenExchange" `
    -Issuer "https://token.actions.githubusercontent.com" `
    -Name "github-actions-main" `
    -Subject "repo:your-org/your-repo:ref:refs/heads/main"

# Create Service Principal
$sp = New-AzADServicePrincipal -ApplicationId $app.AppId

# Assign permissions
New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Contributor"
```

**GitHub Actions Workflow:**
```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Run Automation
        run: |
          pwsh -File automation/powershell/scripts/examples/Set-AzureVmTagsFromPolicy.ps1 -Mode Apply
```

**Pros:**
- ✅ No secrets stored in CI/CD
- ✅ Short-lived tokens (minutes)
- ✅ Automatic token refresh
- ✅ Modern security best practice
- ✅ Reduced attack surface

**Cons:**
- ❌ Requires modern CI/CD platform support
- ❌ More complex initial setup
- ❌ Not supported by all Azure services yet

---

## 🔄 Authentication Decision Tree

```
┌─────────────────────────────────────┐
│ Where is the script running?        │
└─────────────────────────────────────┘
                 │
    ─────────────┼─────────────
    │                          │
    ▼                          ▼
┌─────────┐              ┌──────────┐
│ Locally │              │ Azure    │
└─────────┘              └──────────┘
    │                          │
    ▼                          ▼
Interactive Auth      Managed Identity
(Connect-AzAccount)   (Connect-AzAccount -Identity)
                              │
                              │
                    ┌─────────────────┐
                    │ CI/CD Pipeline? │
                    └─────────────────┘
                              │
                    ──────────┼──────────
                    │                   │
                    ▼                   ▼
            ┌──────────────┐    ┌──────────────┐
            │ Modern       │    │ Traditional  │
            │ (OIDC)       │    │ (SPN)        │
            └──────────────┘    └──────────────┘
                    │                   │
                    ▼                   ▼
        Federated Credential    Service Principal
        (No secrets)            (Client Secret/Cert)
```

---

## 📝 Implementation Examples in This Portfolio

### Azure VM Tagging Script
```powershell
# Supports multiple auth modes automatically
# Local: Uses current Connect-AzAccount session
# CI/CD: Uses Azure DevOps Service Connection
# Azure Automation: Uses Managed Identity

.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "abc-123" -Mode Apply
```

### SQL Permissions Orchestrator
```powershell
# Local development
.\SQL-Permissions-Orchestrator.ps1 -ConfigPath "config.json" -Environment "DEV"

# CI/CD with Service Principal
# Pipeline sets environment variables: SP_CLIENT_ID, SP_CLIENT_SECRET, TENANT_ID
.\SQL-Permissions-Orchestrator.ps1 -ConfigPath "config.json" -Environment "PROD" -NonInteractive
```

### Azure Automation Runbooks
```powershell
# Automatically uses Managed Identity when running in Azure Automation
# No authentication code needed in the script
Connect-AzAccount -Identity
Get-AzVM | Where-Object {$_.PowerState -eq 'VM deallocated'}
```

---

## 🛡️ Security Recommendations

### For Local Development
1. Use your personal account with MFA enabled
2. Never store credentials in scripts or config files
3. Use `Get-Credential` for temporary credential capture
4. Clear PowerShell history after working with sensitive data

### For CI/CD Pipelines
1. **Prefer Federated Credentials (OIDC)** over Service Principals with secrets
2. If using Service Principals:
   - Store secrets in Azure Key Vault or pipeline secret variables
   - Use certificate-based auth when possible
   - Rotate secrets every 90 days maximum
3. Apply least-privilege permissions (specific roles, specific scopes)
4. Enable audit logging for all service principal activities
5. Use separate service principals per environment (Dev/UAT/Prod)

### For Azure Resources
1. **Always use Managed Identity** when running in Azure
2. Prefer System-Assigned over User-Assigned for simplicity
3. Apply RBAC at the most granular scope possible
4. Regularly audit Managed Identity permissions

---

## 📚 Related Documentation

- [Microsoft Identity Platform](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
- [Azure Managed Identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Workload Identity Federation](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [Azure DevOps Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)

---

## 🔍 Troubleshooting

### "Connect-AzAccount: No subscription found"
**Cause:** Authenticated but no subscription access
**Solution:** Verify RBAC permissions on the subscription

### "Service Principal authentication failed"
**Cause:** Incorrect credentials or expired secret
**Solution:** Verify `CLIENT_ID`, `CLIENT_SECRET`, and `TENANT_ID` are correct

### "Managed Identity not found"
**Cause:** Managed Identity not enabled on the resource
**Solution:** Enable System-Assigned Managed Identity in Azure Portal

### "Insufficient privileges"
**Cause:** Service Principal or Managed Identity lacks required permissions
**Solution:** Assign appropriate RBAC role at correct scope

---

**Last Updated:** January 2026  
**Maintained By:** Platform SRE Team
