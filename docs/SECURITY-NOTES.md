# Security & Secrets Management

This document outlines security best practices, secrets handling, data sanitization, and least-privilege principles used across this portfolio.

---

## 🔒 Security Principles

All scripts in this portfolio follow these core security principles:

1. **Least Privilege** - Request only the minimum permissions needed
2. **Defense in Depth** - Multiple layers of security controls
3. **Secrets Never in Code** - No hardcoded credentials or sensitive data
4. **Audit Everything** - Comprehensive logging of all security-relevant actions
5. **Fail Secure** - Default to deny, explicit allow

---

## 🔐 Secrets Management

### Never Store Secrets In:
- ❌ Source code files (.ps1, .py, .tf)
- ❌ Configuration files committed to Git
- ❌ Environment variables (in production)
- ❌ Plain text files
- ❌ PowerShell history
- ❌ Log files or console output

### Approved Secrets Storage:

#### 1. Azure Key Vault (Recommended for Production)
```powershell
# Store secret in Key Vault
$secretValue = ConvertTo-SecureString "MySecretPassword" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "platform-kv" -Name "sql-admin-password" -SecretValue $secretValue

# Retrieve secret in script
$secret = Get-AzKeyVaultSecret -VaultName "platform-kv" -Name "sql-admin-password" -AsPlainText
$securePassword = ConvertTo-SecureString $secret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("sqladmin", $securePassword)
```

#### 2. Azure DevOps Secret Variables
```yaml
variables:
  - group: 'production-secrets'  # Variable group with secrets
  
steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'platform-connection'
    ScriptPath: 'automation/script.ps1'
    ScriptArguments: '-Password $(sql-admin-password)'  # Secret variable
```

#### 3. Get-Credential (Local Development Only)
```powershell
# Prompt user for credentials (local development)
$credential = Get-Credential -Message "Enter SQL Server credentials"
Invoke-Sqlcmd -ServerInstance "SQLSERVER01" -Credential $credential -Query "SELECT @@VERSION"
```

#### 4. Managed Identity (No Secrets Needed)
```powershell
# Best option - no secrets at all
Connect-AzAccount -Identity
# Azure manages authentication automatically
```

---

## 🧹 Data Sanitization

### Portfolio Sanitization Checklist

This repository has been sanitized to remove all company-specific and sensitive information:

#### ✅ Removed/Replaced:
- [x] Company names → "CustomerA", "CompanyX"
- [x] Product names → Generic equivalents
- [x] Tenant IDs → "00000000-0000-0000-0000-000000000000"
- [x] Subscription IDs → "abc-123-def-456"
- [x] Resource Group names → "production-rg", "dev-rg"
- [x] Server hostnames → "SQLSERVER01", "WEBSERVER01"
- [x] Domain names → "domain.local", "company.com"
- [x] IP addresses → "10.0.0.0/24", "192.168.1.0/24"
- [x] Email addresses → "admin@company.com"
- [x] Key Vault names → "platform-kv"
- [x] Storage account names → "platformstorage"
- [x] Internal URLs → Generic examples
- [x] Ticket/Change request numbers → Removed
- [x] Real usernames → "DOMAIN\AppUser", "serviceaccount"

#### Configuration File Sanitization:
```json
// Before (Real)
{
  "tenantId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "subscriptionId": "12345678-1234-1234-1234-123456789012",
  "resourceGroup": "clorox-prod-eastus2-rg",
  "sqlServer": "clorox-sql-prod-01.database.windows.net"
}

// After (Sanitized)
{
  "tenantId": "00000000-0000-0000-0000-000000000000",
  "subscriptionId": "your-subscription-id",
  "resourceGroup": "production-rg",
  "sqlServer": "sqlserver01.database.windows.net"
}
```

### Sanitization Script Example:
```powershell
# Sanitize configuration files before committing
$configPath = "config/production-config.json"
$config = Get-Content $configPath | ConvertFrom-Json

# Replace sensitive values
$config.tenantId = "00000000-0000-0000-0000-000000000000"
$config.subscriptionId = "your-subscription-id"
$config.companyName = "CompanyX"

$config | ConvertTo-Json -Depth 10 | Set-Content $configPath
```

---

## 🎯 Least Privilege Access

### RBAC Role Assignment Principles

#### 1. Scope to Minimum Required Level
```powershell
# Bad - Too broad (entire subscription)
New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "Contributor" `
    -Scope "/subscriptions/$subscriptionId"

# Good - Scoped to specific resource group
New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "Virtual Machine Contributor" `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/production-vms-rg"

# Better - Scoped to specific resource
New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "Virtual Machine Contributor" `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/production-vms-rg/providers/Microsoft.Compute/virtualMachines/web-01"
```

#### 2. Use Specific Roles, Not Generic
```powershell
# Bad - Overly permissive
New-AzRoleAssignment -RoleDefinitionName "Contributor"

# Good - Specific to task
New-AzRoleAssignment -RoleDefinitionName "Virtual Machine Contributor"
New-AzRoleAssignment -RoleDefinitionName "SQL DB Contributor"
New-AzRoleAssignment -RoleDefinitionName "Network Contributor"
```

#### 3. SQL Server Permissions
```sql
-- Bad - Too much access
ALTER SERVER ROLE sysadmin ADD MEMBER [DOMAIN\AppUser]

-- Good - Specific database roles only
USE [ProductionDB]
ALTER ROLE db_datareader ADD MEMBER [DOMAIN\AppUser]
ALTER ROLE db_datawriter ADD MEMBER [DOMAIN\AppUser]

-- Better - Custom role with exact permissions needed
CREATE ROLE app_role
GRANT SELECT, INSERT, UPDATE ON dbo.Orders TO app_role
GRANT EXECUTE ON dbo.usp_ProcessOrder TO app_role
ALTER ROLE app_role ADD MEMBER [DOMAIN\AppUser]
```

---

## 🔍 Audit Logging

### What to Log

#### ✅ Always Log:
- Authentication attempts (success and failure)
- Permission changes (role assignments, grants)
- Resource creation/modification/deletion
- Configuration changes
- Access to sensitive data
- Script execution start/end times
- Errors and exceptions

#### ❌ Never Log:
- Passwords or secrets
- API keys or tokens
- Connection strings with embedded credentials
- Personal Identifiable Information (PII)
- Credit card numbers or financial data

### Secure Logging Example:
```powershell
function Write-SecureLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [hashtable]$Context = @{}
    )
    
    # Sanitize context to remove secrets
    $sanitizedContext = @{}
    foreach ($key in $Context.Keys) {
        if ($key -match 'password|secret|key|token|credential') {
            $sanitizedContext[$key] = "***REDACTED***"
        } else {
            $sanitizedContext[$key] = $Context[$key]
        }
    }
    
    $logEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Level = $Level
        Message = $Message
        Context = $sanitizedContext
        User = $env:USERNAME
        Computer = $env:COMPUTERNAME
    }
    
    $logEntry | ConvertTo-Json -Compress | Add-Content -Path "audit.log"
}

# Usage
Write-SecureLog -Message "SQL permissions updated" -Level "INFO" -Context @{
    Server = "SQLSERVER01"
    Database = "ProductionDB"
    User = "DOMAIN\AppUser"
    Role = "db_datareader"
    Password = "SuperSecret123"  # Will be redacted automatically
}
```

---

## 🛡️ Input Validation & Injection Prevention

### SQL Injection Prevention

#### ❌ Vulnerable (String Concatenation):
```powershell
# NEVER DO THIS
$username = Read-Host "Enter username"
$query = "SELECT * FROM Users WHERE Username = '$username'"
Invoke-Sqlcmd -Query $query
# Vulnerable to: ' OR '1'='1
```

#### ✅ Safe (Parameterized Queries):
```powershell
# Always use parameterized queries
$username = Read-Host "Enter username"
$query = "SELECT * FROM Users WHERE Username = @Username"
Invoke-Sqlcmd -Query $query -Variable "Username='$username'"
```

### Command Injection Prevention

#### ❌ Vulnerable:
```powershell
# NEVER DO THIS
$serverName = Read-Host "Enter server name"
Invoke-Expression "Get-Service -ComputerName $serverName"
# Vulnerable to: server01; Remove-Item C:\*
```

#### ✅ Safe:
```powershell
# Validate input first
$serverName = Read-Host "Enter server name"
if ($serverName -notmatch '^[a-zA-Z0-9\-]+$') {
    throw "Invalid server name format"
}
Get-Service -ComputerName $serverName
```

### Path Traversal Prevention

#### ❌ Vulnerable:
```powershell
# NEVER DO THIS
$fileName = Read-Host "Enter file name"
Get-Content "C:\Logs\$fileName"
# Vulnerable to: ..\..\..\Windows\System32\config\SAM
```

#### ✅ Safe:
```powershell
# Validate and sanitize paths
$fileName = Read-Host "Enter file name"
$fileName = Split-Path $fileName -Leaf  # Remove any path components
$fullPath = Join-Path "C:\Logs" $fileName
if (-not $fullPath.StartsWith("C:\Logs\")) {
    throw "Invalid file path"
}
Get-Content $fullPath
```

---

## 🔐 Credential Handling Best Practices

### 1. Use PSCredential Objects
```powershell
# Good - Secure credential handling
$username = "DOMAIN\ServiceAccount"
$password = Get-AzKeyVaultSecret -VaultName "platform-kv" -Name "service-password" -AsPlainText
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# Use credential
Invoke-Command -ComputerName "SERVER01" -Credential $credential -ScriptBlock { Get-Service }
```

### 2. Clear Credentials from Memory
```powershell
# After use, clear sensitive variables
$password = $null
$securePassword = $null
$credential = $null
[System.GC]::Collect()
```

### 3. Never Log Credentials
```powershell
# Bad
Write-Host "Connecting with password: $password"

# Good
Write-Host "Connecting to server as $username"
```

---

## 🌐 Network Security

### 1. Use TLS/SSL for All Connections
```powershell
# SQL Server - require encryption
Invoke-Sqlcmd -ServerInstance "SQLSERVER01" -TrustServerCertificate -Encrypt

# Azure - always uses HTTPS
Connect-AzAccount

# Web requests - enforce TLS 1.2+
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-RestMethod -Uri "https://api.example.com"
```

### 2. Validate Certificates
```powershell
# Don't blindly trust certificates in production
# Bad
Invoke-WebRequest -Uri "https://internal-api.com" -SkipCertificateCheck

# Good - validate certificate
$response = Invoke-WebRequest -Uri "https://internal-api.com"
# Certificate is validated automatically
```

---

## 📋 Security Checklist for New Scripts

Before committing any script, verify:

- [ ] No hardcoded credentials or secrets
- [ ] No company-specific information (names, IDs, domains)
- [ ] Input validation on all user-provided data
- [ ] Parameterized queries for SQL operations
- [ ] Least-privilege permissions documented
- [ ] Audit logging for security-relevant actions
- [ ] Secrets redacted from logs
- [ ] TLS/encryption for network connections
- [ ] Error messages don't reveal sensitive information
- [ ] `-WhatIf` support for destructive operations
- [ ] Configuration files use `.example` suffix
- [ ] README documents required permissions

---

## 🚨 Incident Response

### If Secrets Are Accidentally Committed:

1. **Immediately rotate the compromised secret**
   ```powershell
   # Rotate Azure Key Vault secret
   $newSecret = ConvertTo-SecureString (New-Guid).ToString() -AsPlainText -Force
   Set-AzKeyVaultSecret -VaultName "platform-kv" -Name "compromised-secret" -SecretValue $newSecret
   ```

2. **Remove from Git history**
   ```bash
   # Use BFG Repo-Cleaner or git filter-branch
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch config/secrets.json" \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force push to remote**
   ```bash
   git push origin --force --all
   ```

4. **Audit access logs** for unauthorized use

5. **Document the incident** and lessons learned

---

## 📚 Related Documentation

- [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/security-features)
- [Azure Security Baseline](https://docs.microsoft.com/en-us/security/benchmark/azure/)

---

**Last Updated:** January 2026  
**Maintained By:** Platform SRE Team
