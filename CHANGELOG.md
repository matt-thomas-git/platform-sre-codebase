# Changelog

All notable changes to this portfolio repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-01-07

### 🎉 Initial Public Release

This is the first public release of the Platform SRE Automation Portfolio, representing 2+ years of production automation work, fully sanitized for public sharing.

### Added

#### 📚 Documentation
- **README.md** - Comprehensive portfolio overview with "Start Here" section and featured projects
- **CONTRIBUTING.md** - Fork guidance, testing practices, and safe usage instructions
- **CHANGELOG.md** - This file, tracking repository changes
- **LICENSE** - MIT License for open sharing
- **docs/AUTH-MODES.md** - Authentication patterns (Interactive, SPN, Managed Identity, OIDC)
- **docs/IDEMPOTENCY-RERUNS.md** - Idempotency patterns and safe rerun strategies
- **docs/SECURITY-NOTES.md** - Security best practices, secrets management, sanitization guide
- **docs/ARCHITECTURE.md** - System design patterns and multi-region strategies
- **docs/BEST-PRACTICES.md** - Operational excellence guidelines
- **docs/CICD-EXPLAINED.md** - CI/CD pipeline patterns and examples
- **docs/LESSONS-LEARNED.md** - Production incident learnings
- **docs/PORTFOLIO-ASSESSMENT.md** - Portfolio structure and assessment
- **docs/SECURITY-SCRUB-CHECKLIST.md** - Sanitization verification checklist

#### 🔧 Automation Scripts

**PowerShell Module:**
- `PlatformOps.Automation.psm1` - Reusable automation module
- `Invoke-Retry.ps1` - Exponential backoff retry logic
- `Write-StructuredLog.ps1` - Consistent severity-based logging
- `Test-TcpPort.ps1` - Network connectivity testing

**Azure Automation:**
- `Set-AzureVmTagsFromPolicy.ps1` - Pattern-based VM tagging with WhatIf support
- `Set-AzureSqlFirewallRules.ps1` - Bulk firewall rule management
- `New-AzureVirtualNetwork.ps1` - VNet creation from configuration

**Server Management:**
- `Get-ServerAdminAudit.ps1` - Multi-server admin/RDP user auditing
- `Invoke-LogCleanup.ps1` - Automated log cleanup (SQL, IIS, SSH)
- `Get-SqlHealth.ps1` - Comprehensive SQL Server health checks

**Python Scripts:**
- `health_probe.py` - HTTP health monitoring
- `sql_permissions_manager.py` - SQL permissions automation

#### 🚀 CI/CD Pipelines

**Windows Updates Pipeline:**
- Multi-stage patching automation with pre/post checks
- Dynatrace maintenance window integration
- Safe rollback capabilities
- Server list management (Dev/UAT/Prod)

**SQL Permissions Pipeline:**
- Configuration-driven role assignments
- Multi-server orchestration
- Audit logging and rollback

**Server Maintenance Pipeline:**
- Orchestrated maintenance workflows
- Service health validation

#### 🏗️ Infrastructure as Code

**Terraform Modules:**
- `network/` - VNet, subnet, NSG configurations
- `compute-windows-vm/` - Windows VM with managed disks
- `monitoring/` - Azure Monitor integration
- `backup/` - Recovery Services Vault configuration
- `nsg-rules/` - Network security group rules

**Terraform Environments:**
- `envs/dev/` - Complete DEV environment (SQL Server VM with AHUB)
- `envs/uat/` - UAT deployment guide
- `envs/stage/` - Staging placeholder

#### 📊 Observability

**KQL Queries:**
- `disk-space-monitoring.kql` - Disk space alerts
- `backup-failures.kql` - Backup failure detection
- `sql-agent-failures.kql` - SQL Agent job monitoring
- `cert-expiry.kql` - Certificate expiration tracking

**Dynatrace Automation:**
- `Install-OneAgent-Regional.ps1` - Multi-region OneAgent deployment
- `Create-NetworkZones.ps1` - Network zone configuration via API
- `Create-MetricEvents.ps1` - Metric event automation
- `Monitor-AzureADSecretExpirations-GraphSDK.ps1` - Azure AD secret monitoring (Microsoft Graph SDK version)
- `Monitor-AzureADSecretExpirations-DynatraceRunbook.ps1` - Azure Automation Runbook with Dynatrace integration
- Comprehensive 400+ line Dynatrace README with deployment guide

#### 🔐 Security & Compliance

- `AD-Group-Audit.ps1` - Active Directory group membership auditing
- `ADO-AppRegistration-Audit.ps1` - Azure AD app registration monitoring
- `Certificate-Expiry-Monitor.ps1` - SSL/TLS certificate tracking
- `SOC1-WindowsUpdate-Audit.ps1` - Windows Update compliance reporting

#### 📖 Runbooks

**Azure:**
- `backup-verification.md` - Backup restore testing procedures

**SQL:**
- `tempdb-growth.md` - TempDB growth troubleshooting
- `job-failure-triage.md` - SQL Agent job failure response

### Security

- ✅ All company-specific information sanitized
- ✅ No credentials, secrets, or sensitive data
- ✅ Tenant IDs, subscription IDs replaced with placeholders
- ✅ Server hostnames, domains, IPs genericized
- ✅ Configuration files use `.example` suffix
- ✅ Comprehensive `.gitignore` for secrets protection

### Technical Highlights

- **Production-Ready:** Comprehensive error handling, structured logging, idempotent operations
- **Multi-Environment:** Dev/UAT/Prod support across all automation
- **CI/CD Friendly:** WhatIf/dry-run support, non-interactive modes
- **Well-Documented:** Detailed help, usage examples, architecture guides
- **Security-First:** Least privilege, secrets management, audit logging

---

## [Unreleased]

### Planned Enhancements

- [ ] GitHub Actions workflow examples (in addition to Azure DevOps)
- [ ] Additional Terraform modules (Azure SQL Database, App Service)
- [ ] Enhanced monitoring dashboards and alerts
- [ ] Ansible playbook examples for hybrid cloud scenarios
- [ ] Container orchestration examples (AKS, Docker Compose)

---

## Version History Summary

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2026-01-07 | Initial public release - 2+ years of production automation |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on safely forking and using this portfolio.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

**Note:** This portfolio represents real production work that has been carefully sanitized for public sharing. All technical patterns, automation logic, and operational practices are authentic and battle-tested.
