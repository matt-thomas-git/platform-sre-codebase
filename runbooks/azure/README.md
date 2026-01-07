# Azure Runbooks

Operational runbooks for Azure infrastructure troubleshooting and maintenance procedures.

## Overview

This directory contains step-by-step runbooks for common Azure operational tasks, incident response, and troubleshooting procedures. These runbooks are designed to be followed by on-call engineers and operations teams.

## Available Runbooks

### backup-verification.md
**Purpose:** Verify Azure Backup jobs are completing successfully

**When to Use:**
- Weekly backup verification checks
- After backup policy changes
- Investigating backup failures
- Compliance audits

**Key Steps:**
1. Check Recovery Services Vault status
2. Verify backup job completion
3. Test restore capability
4. Document results

---

## Runbook Categories

### 🔧 Infrastructure Management

**Topics Covered:**
- VM lifecycle management (start/stop/resize)
- Disk management and expansion
- Network configuration changes
- Resource group organization

**Example Scenarios:**
- Deallocated VM won't start
- Disk space expansion needed
- NSG rule changes
- Load balancer SKU upgrades

---

### 🔐 Security & Compliance

**Topics Covered:**
- NSG rule auditing
- Key Vault secret rotation
- Certificate expiration handling
- RBAC permission reviews

**Example Scenarios:**
- Certificate expiring soon
- Unauthorized access attempts
- Compliance audit preparation
- Secret rotation procedures

---

### 📊 Monitoring & Alerting

**Topics Covered:**
- Azure Monitor alert investigation
- Log Analytics query troubleshooting
- Metric threshold tuning
- Alert fatigue reduction

**Example Scenarios:**
- False positive alerts
- Missing critical alerts
- Query performance issues
- Dashboard creation

---

### 💾 Backup & Recovery

**Topics Covered:**
- Backup job verification
- Restore testing procedures
- Backup policy management
- Recovery Services Vault maintenance

**Example Scenarios:**
- Backup job failures
- Restore point verification
- Policy compliance checks
- Disaster recovery testing

---

## Runbook Template

All runbooks follow this standard structure:

```markdown
# [Runbook Title]

## Overview
Brief description of the issue or task

## Symptoms
- Observable symptoms
- Error messages
- Affected systems

## Prerequisites
- Required permissions
- Tools needed
- Access requirements

## Investigation Steps
1. Step-by-step investigation
2. Commands to run
3. What to look for

## Resolution Steps
1. Step-by-step fix
2. Commands to execute
3. Validation checks

## Verification
- How to confirm resolution
- Tests to perform
- Metrics to check

## Prevention
- How to prevent recurrence
- Monitoring to add
- Process improvements

## Escalation
- When to escalate
- Who to contact
- Information to provide
```

---

## How to Use These Runbooks

### 1. During Incidents

```
1. Identify the issue category
2. Find the relevant runbook
3. Follow steps sequentially
4. Document actions taken
5. Update runbook if needed
```

### 2. For Training

- New team members should review all runbooks
- Practice procedures in non-production
- Conduct tabletop exercises
- Update based on lessons learned

### 3. For Automation

- Runbooks can be automated using:
  - Azure Automation Runbooks
  - Azure DevOps Pipelines
  - PowerShell scripts
  - Azure Functions

---

## Common Azure CLI Commands

### Resource Management

```bash
# List all VMs
az vm list --output table

# Get VM status
az vm get-instance-view --name VM-NAME --resource-group RG-NAME

# Start/Stop VM
az vm start --name VM-NAME --resource-group RG-NAME
az vm deallocate --name VM-NAME --resource-group RG-NAME
```

### Backup Operations

```bash
# List Recovery Services Vaults
az backup vault list --output table

# Check backup jobs
az backup job list --vault-name VAULT-NAME --resource-group RG-NAME

# Trigger backup
az backup protection backup-now --item-name ITEM-NAME --vault-name VAULT-NAME --resource-group RG-NAME
```

### Network Troubleshooting

```bash
# List NSG rules
az network nsg rule list --nsg-name NSG-NAME --resource-group RG-NAME --output table

# Test connectivity
az network watcher test-connectivity --source-resource VM-NAME --dest-address DEST-IP --dest-port 443
```

---

## Common PowerShell Commands

### VM Management

```powershell
# Get VM status
Get-AzVM -ResourceGroupName "RG-NAME" -Name "VM-NAME" -Status

# Start VM
Start-AzVM -ResourceGroupName "RG-NAME" -Name "VM-NAME"

# Get VM sizes available
Get-AzVMSize -Location "East US 2"
```

### Backup Verification

```powershell
# Get backup jobs
Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -Status Failed

# Get backup items
Get-AzRecoveryServicesBackupItem -VaultId $vault.ID -BackupManagementType AzureVM
```

---

## Troubleshooting Quick Reference

### VM Won't Start

1. Check VM status: `az vm get-instance-view`
2. Review Activity Log for errors
3. Check quota limits
4. Verify disk health
5. Check NSG rules blocking boot diagnostics

### Backup Failures

1. Check backup job status
2. Review error messages
3. Verify VM agent status
4. Check disk space on VM
5. Validate backup policy

### Network Connectivity Issues

1. Check NSG rules (source and destination)
2. Verify route tables
3. Test with Network Watcher
4. Check service endpoints
5. Validate DNS resolution

---

## Best Practices

### 1. Documentation

- ✅ Document all actions taken
- ✅ Include timestamps
- ✅ Note any deviations from runbook
- ✅ Update runbook with learnings

### 2. Communication

- ✅ Notify stakeholders before changes
- ✅ Provide status updates
- ✅ Document in incident ticket
- ✅ Conduct post-incident review

### 3. Safety

- ✅ Test in non-production first
- ✅ Have rollback plan ready
- ✅ Take snapshots before changes
- ✅ Verify backups are current

### 4. Automation

- ✅ Automate repetitive tasks
- ✅ Use infrastructure as code
- ✅ Implement monitoring
- ✅ Create self-healing systems

---

## Contributing

To add a new runbook:

1. Use the standard template above
2. Include real examples and commands
3. Test procedures in non-production
4. Get peer review
5. Submit pull request

---

## Related Documentation

- [Azure Documentation](https://docs.microsoft.com/en-us/azure/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure PowerShell Reference](https://docs.microsoft.com/en-us/powershell/azure/)
- [../../docs/LESSONS-LEARNED.md](../../docs/LESSONS-LEARNED.md) - Production incident learnings

---

**Note:** These runbooks are based on real production scenarios and have been sanitized for portfolio use.
