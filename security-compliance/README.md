# Security & Compliance

Security auditing, compliance reporting, and governance automation scripts.

## Overview

This directory contains scripts for security auditing, compliance reporting, and governance tasks. These scripts help maintain security posture, meet compliance requirements, and provide audit trails for regulatory purposes.

## Scripts

### AD-Group-Audit.ps1
**Purpose:** Audit Active Directory group memberships

**Features:**
- Exports all AD group members
- Identifies privileged groups
- Tracks membership changes over time
- Generates compliance reports

**Use Cases:**
- SOC1/SOC2 audits
- Quarterly access reviews
- Privileged access monitoring
- Compliance reporting

**Example:**
```powershell
.\AD-Group-Audit.ps1 -Groups "Domain Admins","Enterprise Admins" -OutputPath "C:\Audits"
```

---

### ADO-AppRegistration-Audit.ps1
**Purpose:** Audit Azure AD application registrations and service principals

**Features:**
- Lists all app registrations
- Identifies expiring secrets/certificates
- Checks for unused applications
- Exports permissions and API access

**Use Cases:**
- Security reviews
- Secret rotation planning
- Unused app cleanup
- Permission audits

**Example:**
```powershell
.\ADO-AppRegistration-Audit.ps1 -TenantId "your-tenant-id" -ExportPath "C:\Audits"
```

---

### Certificate-Expiry-Monitor.ps1
**Purpose:** Monitor SSL/TLS certificate expirations

**Features:**
- Scans certificate stores
- Checks web endpoints
- Alerts on expiring certificates
- Generates renewal reports

**Use Cases:**
- Prevent certificate outages
- Compliance requirements
- Renewal planning
- Security monitoring

**Example:**
```powershell
.\Certificate-Expiry-Monitor.ps1 -Servers @("WEB01","WEB02") -DaysWarning 30
```

---

### Server-Critical-Updates-Audit.ps1
**Purpose:** Audit Windows Update compliance

**Features:**
- Checks for missing critical updates
- Identifies servers needing patches
- Generates compliance reports
- Tracks patch history

**Use Cases:**
- SOC1 compliance
- Security vulnerability management
- Patch compliance reporting
- Risk assessment

**Example:**
```powershell
.\Server-Critical-Updates-Audit.ps1 -ServerList "servers.txt" -OutputPath "C:\Audits"
```

---

## Compliance Frameworks

### SOC1 / SOC2

**Requirements:**
- Access control reviews (quarterly)
- Privileged user monitoring
- Change management tracking
- Security patch compliance

**Scripts:**
- `AD-Group-Audit.ps1` - Access reviews
- `Server-Critical-Updates-Audit.ps1` - Patch compliance
- `ADO-AppRegistration-Audit.ps1` - Application access

---

### PCI-DSS

**Requirements:**
- Quarterly vulnerability scans
- Access control reviews
- Security patch management
- Encryption key management

**Scripts:**
- `Certificate-Expiry-Monitor.ps1` - Certificate management
- `AD-Group-Audit.ps1` - Access control
- `Server-Critical-Updates-Audit.ps1` - Patch management

---

### HIPAA

**Requirements:**
- Access auditing
- Encryption monitoring
- Security incident tracking
- Regular risk assessments

**Scripts:**
- `AD-Group-Audit.ps1` - Access auditing
- `Certificate-Expiry-Monitor.ps1` - Encryption monitoring

---

## Audit Schedule

### Daily
- Certificate expiration checks
- Failed login monitoring
- Privileged access monitoring

### Weekly
- Application registration review
- Service principal audit
- Unused account detection

### Monthly
- AD group membership audit
- Security patch compliance
- Access control review

### Quarterly
- Full compliance audit
- Risk assessment
- Policy review
- Audit report generation

---

## Report Formats

### CSV Export
```powershell
# Standard CSV format for Excel analysis
Export-Csv -Path "audit-report.csv" -NoTypeInformation
```

### HTML Report
```powershell
# HTML report with styling
ConvertTo-Html -Title "Security Audit Report" | Out-File "report.html"
```

### JSON Export
```powershell
# JSON for API integration
ConvertTo-Json -Depth 10 | Out-File "audit-data.json"
```

---

## Automation

### Azure DevOps Pipeline

```yaml
trigger:
  schedules:
  - cron: "0 2 * * 1"  # Every Monday at 2 AM
    displayName: Weekly Security Audit
    branches:
      include:
      - main

steps:
- task: PowerShell@2
  inputs:
    filePath: 'security-compliance/AD-Group-Audit.ps1'
    arguments: '-OutputPath $(Build.ArtifactStagingDirectory)'
    
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)'
    ArtifactName: 'security-audit-reports'
```

### Azure Automation Runbook

```powershell
# Schedule in Azure Automation for automated auditing
# Runs weekly and stores results in Azure Storage

param(
    [string]$StorageAccountName,
    [string]$ContainerName
)

# Run audit
$auditResults = .\AD-Group-Audit.ps1

# Upload to Azure Storage
$context = New-AzStorageContext -StorageAccountName $StorageAccountName
Set-AzStorageBlobContent -File $auditResults -Container $ContainerName -Context $context
```

---

## Best Practices

### 1. Data Protection

- ✅ Encrypt audit reports at rest
- ✅ Use secure transfer protocols
- ✅ Limit access to audit data
- ✅ Retain reports per compliance requirements
- ✅ Sanitize sensitive information

### 2. Audit Trail

- ✅ Log all audit script executions
- ✅ Track who ran audits and when
- ✅ Version control audit scripts
- ✅ Document changes to audit procedures
- ✅ Maintain historical audit data

### 3. Reporting

- ✅ Standardize report formats
- ✅ Include executive summaries
- ✅ Highlight critical findings
- ✅ Provide remediation recommendations
- ✅ Track remediation progress

### 4. Automation

- ✅ Schedule regular audits
- ✅ Alert on critical findings
- ✅ Automate report distribution
- ✅ Integrate with ticketing systems
- ✅ Monitor audit script health

---

## Common Audit Queries

### Active Directory

```powershell
# Find users with passwords that never expire
Get-ADUser -Filter {PasswordNeverExpires -eq $true} -Properties PasswordNeverExpires

# Find inactive user accounts
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly

# Find users in privileged groups
Get-ADGroupMember -Identity "Domain Admins" -Recursive
```

### Azure AD

```powershell
# Find users with admin roles
Get-AzureADDirectoryRole | ForEach-Object {
    Get-AzureADDirectoryRoleMember -ObjectId $_.ObjectId
}

# Find app registrations with expiring secrets
Get-AzureADApplication | Where-Object {
    $_.PasswordCredentials.EndDate -lt (Get-Date).AddDays(30)
}
```

### Windows Updates

```powershell
# Check for missing critical updates
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
$searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
$searchResult.Updates | Where-Object {$_.MsrcSeverity -eq "Critical"}
```

---

## Compliance Checklist

### Monthly Review

- [ ] Run AD group membership audit
- [ ] Review privileged access changes
- [ ] Check for expiring certificates
- [ ] Verify patch compliance
- [ ] Review failed login attempts
- [ ] Audit service account usage
- [ ] Check for orphaned accounts
- [ ] Review firewall rule changes

### Quarterly Review

- [ ] Full security audit
- [ ] Access control review
- [ ] Risk assessment
- [ ] Policy compliance check
- [ ] Vendor access review
- [ ] Disaster recovery test
- [ ] Security training completion
- [ ] Incident response review

---

## Remediation Tracking

### Issue Template

```markdown
**Issue:** [Description]
**Severity:** Critical / High / Medium / Low
**Discovered:** [Date]
**Owner:** [Name]
**Due Date:** [Date]
**Status:** Open / In Progress / Resolved

**Remediation Steps:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Verification:**
- [ ] Fix implemented
- [ ] Tested in non-production
- [ ] Deployed to production
- [ ] Verified in next audit
```

---

## Related Documentation

- [../../docs/SECURITY-NOTES.md](../../docs/SECURITY-NOTES.md) - Security best practices
- [../../docs/SECURITY-SCRUB-CHECKLIST.md](../../docs/SECURITY-SCRUB-CHECKLIST.md) - Sanitization checklist
- [../../automation/powershell/scripts/examples/](../../automation/powershell/scripts/examples/) - Automation scripts

---

**Note:** These scripts are production-tested and sanitized for portfolio use. All sensitive information has been removed.
