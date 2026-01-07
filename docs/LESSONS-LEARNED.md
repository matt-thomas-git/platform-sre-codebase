# Lessons Learned from Production

## Real-World Challenges & Solutions

This document captures valuable lessons learned from 2+ years of managing enterprise cloud infrastructure and automation at scale.

---

## Azure Infrastructure

### Load Balancer SKU Upgrades

**Challenge**: Azure deprecated Basic SKU load balancers, requiring migration to Standard SKU across 10+ production environments.

**What Went Wrong Initially**:
- First attempt didn't account for outbound connectivity requirements
- VMs lost internet access after upgrade
- Manual rollback required

**Solution Implemented**:
```powershell
# Always configure outbound rules BEFORE upgrading
$outboundRule = New-AzLoadBalancerOutboundRuleConfig `
    -Name "OutboundRule" `
    -FrontendIpConfiguration $frontendIP `
    -BackendAddressPool $backendPool `
    -Protocol All `
    -IdleTimeoutInMinutes 15
```

**Lesson Learned**: 
- Always test connectivity AFTER infrastructure changes
- Implement automated HTTPS health checks
- Have rollback plan ready before starting
- Document all dependencies (outbound rules, NAT rules, etc.)

**Impact**: Zero downtime upgrades after implementing proper validation

---

### VM Tagging Governance

**Challenge**: 200+ VMs with inconsistent or missing tags, making cost allocation impossible.

**What Went Wrong Initially**:
- Manual tagging was error-prone and time-consuming
- No enforcement mechanism
- Tags would drift over time

**Solution Implemented**:
```powershell
# Automated tagging based on resource group naming convention
$tags = @{
    Environment = if ($rgName -match "-prod-") { "Production" } else { "Non-Production" }
    ManagedBy = "Automation"
    CostCenter = Get-CostCenterFromRG -ResourceGroup $rgName
}
```

**Lesson Learned**:
- Automation is the only way to maintain consistency at scale
- Naming conventions should encode metadata
- Regular audits catch drift early
- Azure Policy can enforce tagging requirements

**Impact**: 100% tag compliance, accurate cost allocation

---

## SQL Server Automation

### TempDB Growth Issues

**Challenge**: Multiple SQL Servers experiencing TempDB growth issues due to files not set to UNLIMITED.

**What Went Wrong Initially**:
- Manual checks across 50+ servers were incomplete
- Some servers had mixed settings (some files unlimited, others not)
- TempDB filled up causing production outages

**Solution Implemented**:
```powershell
# Automated checker and fixer
$query = @"
SELECT 
    name,
    physical_name,
    CASE WHEN max_size = -1 THEN 'UNLIMITED' ELSE 'LIMITED' END as MaxSize,
    max_size
FROM sys.master_files
WHERE database_id = 2
"@

# Fix all files that aren't unlimited
if ($file.MaxSize -ne 'UNLIMITED') {
    $fixQuery = "ALTER DATABASE tempdb MODIFY FILE (NAME = '$($file.name)', MAXSIZE = UNLIMITED)"
}
```

**Lesson Learned**:
- Standardize configurations across all servers
- Automate discovery of configuration drift
- Test fixes on non-production first
- Document WHY settings exist (not just WHAT they are)

**Impact**: Zero TempDB-related outages after standardization

---

### Multi-Server Permission Management

**Challenge**: Applying SQL permissions to 200+ databases across multiple servers was taking 2+ hours manually.

**What Went Wrong Initially**:
- Copy-paste errors led to incorrect permissions
- Missed databases in the process
- No audit trail of what was changed

**Solution Implemented**:
```powershell
# Automated with validation
foreach ($server in $servers) {
    # Check current permissions first
    $existing = Get-SqlPermissions -Server $server -User $username
    
    # Only apply if missing
    if ($permission -notin $existing) {
        Grant-SqlPermission -Server $server -User $username -Permission $permission
        Write-Log "Granted $permission to $username on $server"
    } else {
        Write-Log "Permission already exists, skipping"
    }
}
```

**Lesson Learned**:
- Always check before applying (idempotency)
- Log everything for audit trail
- Provide dry-run mode for validation
- Interactive confirmation for production changes

**Impact**: 2 hours → 10 minutes, zero permission errors

---

## Windows Updates & Patching

### Dynatrace Maintenance Windows

**Challenge**: Patching servers without triggering false alerts in monitoring system.

**What Went Wrong Initially**:
- Forgot to set maintenance windows
- Alert fatigue from expected downtime alerts
- Manual process was error-prone

**Solution Implemented**:
```powershell
# Automated maintenance window creation
$maintenanceWindow = @{
    name = "Patching-$serverName-$(Get-Date -Format 'yyyy-MM-dd')"
    description = "Automated patching maintenance window"
    schedule = @{
        start = (Get-Date).AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:ss")
        end = (Get-Date).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ss")
    }
    scope = @{
        entities = @($entityId)
    }
}
```

**Lesson Learned**:
- Integrate monitoring with automation
- Set maintenance windows BEFORE starting work
- Buffer time for unexpected issues
- Clean up old maintenance windows

**Impact**: Zero false alerts during patching windows

---

### Pre-Flight Checks

**Challenge**: Patches occasionally failed due to insufficient disk space or stopped services.

**What Went Wrong Initially**:
- Started patching without checking prerequisites
- Had to abort mid-patching
- Extended maintenance windows

**Solution Implemented**:
```powershell
# Comprehensive pre-checks
$checks = @(
    @{ Name = "Disk Space"; Test = { (Get-PSDrive C).Free -gt 10GB } }
    @{ Name = "Windows Update Service"; Test = { (Get-Service wuauserv).Status -eq 'Running' } }
    @{ Name = "Pending Reboot"; Test = { -not (Test-PendingReboot) } }
)

foreach ($check in $checks) {
    if (-not (& $check.Test)) {
        throw "Pre-check failed: $($check.Name)"
    }
}
```

**Lesson Learned**:
- Never skip pre-flight checks
- Fail fast if prerequisites aren't met
- Document all prerequisites
- Automate the checks

**Impact**: 99% first-time success rate for patching

---

## Security & Compliance

### App Registration Expiry

**Challenge**: App registrations expiring without warning, breaking service connections.

**What Went Wrong Initially**:
- No visibility into which app registrations were in use
- Couldn't safely rotate secrets
- Production outages from expired credentials

**Solution Implemented**:
```powershell
# Audit all Azure DevOps service connections
$connections = Get-AzDevOpsServiceConnections -Organization $org
foreach ($conn in $connections) {
    $appReg = Get-AzADApplication -ApplicationId $conn.AppId
    $daysUntilExpiry = ($appReg.PasswordCredentials.EndDate - (Get-Date)).Days
    
    if ($daysUntilExpiry -lt 30) {
        Write-Warning "App registration $($appReg.DisplayName) expires in $daysUntilExpiry days"
    }
}
```

**Lesson Learned**:
- Maintain inventory of all service principals
- Monitor expiration dates proactively
- Document which apps are used where
- Rotate secrets before expiry, not after

**Impact**: Zero outages from expired credentials

---

### SOC 1 Audit Preparation

**Challenge**: Auditors requested Windows Update history for specific date ranges across all servers.

**What Went Wrong Initially**:
- Manual collection from each server took days
- Inconsistent data format
- Difficult to prove completeness

**Solution Implemented**:
```powershell
# Automated audit report generation
$servers | ForEach-Object {
    $updates = Get-WmiObject -Class Win32_QuickFixEngineering -ComputerName $_ |
        Where-Object { $_.InstalledOn -ge $startDate -and $_.InstalledOn -le $endDate }
    
    $updates | Select-Object PSComputerName, HotFixID, Description, InstalledOn
} | Export-Csv -Path "SOC1-Audit-$(Get-Date -Format 'yyyy-MM-dd').csv"
```

**Lesson Learned**:
- Automate compliance reporting
- Keep audit scripts ready year-round
- Test scripts before audit season
- Provide data in auditor-friendly format

**Impact**: 4 hours → 5 minutes for audit evidence

---

## CI/CD Pipelines

### Pipeline Variable Management

**Challenge**: Secrets hardcoded in scripts, making rotation difficult and insecure.

**What Went Wrong Initially**:
- Passwords in plain text in scripts
- Difficult to rotate without updating all scripts
- Security risk

**Solution Implemented**:
```yaml
variables:
  - group: production-secrets  # Stored in Azure Key Vault
  
steps:
  - task: PowerShell@2
    inputs:
      script: |
        $password = $env:SQL_PASSWORD  # From variable group
        # Use password securely
    env:
      SQL_PASSWORD: $(SqlAdminPassword)
```

**Lesson Learned**:
- Never hardcode secrets
- Use Azure Key Vault for secret storage
- Reference secrets via pipeline variables
- Rotate secrets regularly

**Impact**: Improved security posture, easier secret rotation

---

## Monitoring & Observability

### Certificate Expiry Monitoring

**Challenge**: SSL certificates expiring without warning, causing service outages.

**What Went Wrong Initially**:
- Manual tracking in spreadsheets
- Missed renewal dates
- Emergency renewals under pressure

**Solution Implemented**:
```powershell
# Automated certificate expiry checking
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*$domain*" }
$daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days

if ($daysUntilExpiry -lt 30) {
    Send-Alert -Message "Certificate for $domain expires in $daysUntilExpiry days"
}
```

**Lesson Learned**:
- Automate certificate monitoring
- Alert 30+ days before expiry
- Document renewal process
- Test renewal in non-production first

**Impact**: Zero certificate-related outages

---

## General Automation Principles

### The Importance of Idempotency

**Challenge**: Scripts that couldn't be safely re-run caused issues during troubleshooting.

**Lesson Learned**:
- Always check if action is needed before performing it
- Scripts should be safe to run multiple times
- Use `-ErrorAction SilentlyContinue` for existence checks

**Example**:
```powershell
# Bad - creates duplicate entries
Add-AzLoadBalancerBackendAddressPool -VM $vm

# Good - checks first
if ($vm.Id -notin $backendPool.BackendIpConfigurations.Id) {
    Add-AzLoadBalancerBackendAddressPool -VM $vm
}
```

---

### Retry Logic is Essential

**Challenge**: Transient network errors causing script failures.

**Lesson Learned**:
- Azure APIs occasionally return transient errors
- Implement exponential backoff
- Log retry attempts
- Set reasonable max retries (3-5)

**Example**:
```powershell
$retryCount = 0
$maxRetries = 3
$delay = 2

while ($retryCount -lt $maxRetries) {
    try {
        $result = Invoke-AzureOperation
        break
    }
    catch {
        $retryCount++
        if ($retryCount -eq $maxRetries) { throw }
        Start-Sleep -Seconds ($delay * [Math]::Pow(2, $retryCount))
    }
}
```

---

### Logging Saves Time

**Challenge**: Troubleshooting failures without adequate logging.

**Lesson Learned**:
- Log everything: start time, end time, parameters, results
- Use structured logging with timestamps
- Color-code console output for readability
- Export logs to files for later analysis

**Impact**: Troubleshooting time reduced by 75%

---

### Test in Non-Production First

**Challenge**: Untested scripts causing production issues.

**Lesson Learned**:
- ALWAYS test in Dev/UAT first
- Use `-WhatIf` for dry runs
- Implement test server flags
- Get peer review before production deployment

**Example**:
```powershell
if ($Environment -eq "Production" -and !$Confirm) {
    throw "Production changes require -Confirm switch"
}
```

---

## Key Takeaways

1. **Automation is Worth the Investment** - Initial time investment pays off exponentially
2. **Idempotency is Non-Negotiable** - Scripts must be safe to re-run
3. **Logging is Your Best Friend** - You can't troubleshoot what you can't see
4. **Test Everything** - Assumptions lead to outages
5. **Document as You Go** - Future you will thank present you
6. **Security First** - Never compromise on security for convenience
7. **Monitor Proactively** - Fix issues before they become outages
8. **Automate Compliance** - Manual compliance doesn't scale
9. **Version Control Everything** - Git is your safety net
10. **Learn from Failures** - Every outage is a learning opportunity

---

## Metrics That Matter

- **Time Saved**: 20+ hours/week through automation
- **Error Reduction**: 95% fewer manual errors
- **Uptime Improvement**: 99.9% availability
- **Audit Success**: 100% SOC 1 compliance
- **Cost Savings**: $50K+ annually through optimization
- **Response Time**: 75% faster incident resolution

---

## Future Improvements

Based on lessons learned, future enhancements should include:

- **Infrastructure as Code**: Full Terraform adoption for all Azure resources
- **GitOps**: Automated deployment from Git commits
- **Containerization**: Docker containers for consistent execution environments
- **Automated Testing**: Pester tests for all PowerShell modules
- **Self-Service**: Portal for common operations
- **Predictive Monitoring**: ML-based anomaly detection
- **Chaos Engineering**: Proactive failure testing

---

*"The best time to automate was yesterday. The second best time is now."*
