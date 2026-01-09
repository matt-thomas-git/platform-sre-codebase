# Platform SRE Automation Portfolio

A curated collection of production-ready automation, infrastructure-as-code, and operational tooling developed over 2+ years of Platform/SRE work. This repository showcases real-world solutions for Azure cloud infrastructure, Windows Server management, SQL Server operations, and observability automation.

---

## ⚡ Start Here

**New to this repository?** This 60-second tour will get you oriented:

1. **Browse the [Featured Projects](#-featured-projects)** below to see production-grade automation examples
2. **Read the ["If You Only Read 3 Things"](#-if-you-only-read-3-things)** section for the highlights
3. **Check [Getting Started](#-getting-started)** to run scripts safely with `-WhatIf` mode
4. **Review [Use Cases](#-use-cases)** to see real-world problems solved

### 📌 If You Only Read 3 Things

These three components showcase the depth and breadth of this portfolio:

1. **[PowerShell Automation Module](automation/powershell/Module/)** - Reusable functions with production-grade patterns
   - [`Invoke-Retry.ps1`](automation/powershell/Module/Public/Invoke-Retry.ps1) - Exponential backoff retry logic for resilient automation
   - [`Write-StructuredLog.ps1`](automation/powershell/Module/Public/Write-StructuredLog.ps1) - Consistent, severity-based logging across all scripts
   - Used by 15+ scripts across the portfolio for reliability

2. **[Windows Updates Pipeline](cicd-pipelines/windows-updates-pipeline/)** - Multi-stage production patching automation
   - [Pipeline README](cicd-pipelines/windows-updates-pipeline/README.md) - Complete orchestration with pre/post checks
   - Dynatrace maintenance window integration
   - Safe rollback capabilities
   - Handles 50+ servers across Dev/UAT/Prod environments

3. **[Dynatrace Automation Suite](observability/dynatrace/)** - Enterprise observability deployment
   - [Comprehensive Guide](observability/dynatrace/README.md) - 400+ lines covering deployment, API automation, best practices
   - Multi-region OneAgent deployment
   - Network zone configuration
   - Docker integration for container monitoring

---

## 🌟 Featured Projects

### 🔧 Infrastructure Automation
- **[Azure VM Tag Management](automation/powershell/scripts/examples/Set-AzureVmTagsFromPolicy.ps1)** - Pattern-based tagging with WhatIf support, multi-subscription capable
- **[Azure SQL Firewall Management](automation/powershell/scripts/examples/Set-AzureSqlFirewallRules.ps1)** - Bulk IP management with configuration-driven automation
- **[Terraform Azure Infrastructure](terraform/)** - SQL Server VMs with AHUB licensing, multi-disk configurations, modular design

### 🔐 Security & Compliance
- **[Server Admin Audit](automation/powershell/scripts/examples/Get-ServerAdminAudit.ps1)** - Multi-server parallel auditing for compliance reporting
- **[Certificate Expiry Monitor](security-compliance/Certificate-Expiry-Monitor.ps1)** - Proactive SSL/TLS certificate tracking
- **[SOC1 Windows Update Audit](security-compliance/SOC1-WindowsUpdate-Audit.ps1)** - Compliance reporting automation

### 📊 Observability & Monitoring
- **[SQL Server Health Check](automation/powershell/scripts/examples/Get-SqlHealth.ps1)** - Comprehensive database monitoring with backup verification
- **[KQL Query Library](observability/kql/)** - 30+ production Azure Monitor queries for disk space, backups, SQL jobs
- **[Dynatrace OneAgent Deployment](observability/dynatrace/deployment/)** - Regional deployment automation

### 🚀 CI/CD Pipelines
- **[Windows Update Pipeline](cicd-pipelines/windows-updates-pipeline/)** - Safe patching with monitoring integration
- **[SQL Permissions Pipeline](cicd-pipelines/sql-permissions-pipeline/)** - Automated role management with audit logging
- **[Server Maintenance Pipeline](cicd-pipelines/server-maint-pipeline/)** - Orchestrated maintenance workflows

---

## 📊 Repository Statistics

- **Total Files:** 130+ files (code, configs, documentation)
- **PowerShell Scripts:** 28 automation scripts
- **Python Scripts:** 2 (health probe + SQL permissions manager)
- **Terraform Files:** 20 (.tf files across 5 modules + DEV environment)
- **KQL Queries:** 4 Azure Monitor query files
- **Documentation:** 37 markdown files (guides, runbooks, READMEs)
- **CI/CD Pipelines:** 3 Azure DevOps + 1 GitHub Actions (cross-platform examples)
- **JSON Configs:** 4 configuration examples
- **PowerShell Module:** 1 reusable module with 3 public functions
- **Lines of Code:** ~8,000+ lines of production-tested PowerShell, Python, Terraform, and KQL

## 🎯 What This Repository Demonstrates

### Technical Skills
- **Cloud Platforms:** Azure (VMs, SQL Database, Resource Groups, Subscriptions, Recovery Services Vaults)
- **Automation:** PowerShell (advanced scripting, modules, remoting), Python
- **Infrastructure as Code:** Terraform (Azure SQL Server VMs, AHUB, multi-disk configurations)
- **CI/CD:** Azure DevOps Pipelines + GitHub Actions (YAML, multi-stage, cross-platform)
- **Observability:** Dynatrace (API automation, deployment, monitoring, Docker integration)
- **Databases:** SQL Server (health checks, permissions, maintenance, backups)
- **Operating Systems:** Windows Server (administration, auditing, patching)
- **Backup & Disaster Recovery:** Azure Backup, Recovery Services Vaults, restore testing
- **Container Orchestration:** Docker (Dynatrace OneAgent integration)

### Operational Excellence
- Production-ready error handling and logging
- Idempotent operations with dry-run/WhatIf support
- Comprehensive documentation and runbooks
- Security-first approach (credential management, least privilege)
- Compliance and audit automation
- Multi-environment support (Dev/UAT/Prod)

## 📁 Repository Structure

```
platform-sre-portfolio/
├── automation/                    # Automation scripts and modules
│   ├── README.md                 # Automation overview
│   ├── azure-runbooks/           # Azure Automation runbooks
│   │   ├── README.md            # Azure runbooks documentation
│   │   ├── Check-And-Start-VM.ps1
│   │   └── Monitor-Backup-Health.ps1
│   ├── powershell/
│   │   ├── TEST-MODULE.ps1      # Module testing script
│   │   ├── Module/               # Reusable PowerShell module
│   │   │   ├── PlatformOps.Automation.psm1
│   │   │   └── Public/
│   │   │       ├── Invoke-Retry.ps1
│   │   │       ├── Test-TcpPort.ps1
│   │   │       └── Write-StructuredLog.ps1
│   │   ├── scripts/
│   │   │   ├── examples/        # Production automation scripts
│   │   │   │   ├── README.md
│   │   │   │   ├── USAGE-GUIDE.md
│   │   │   │   ├── Get-ServerAdminAudit.ps1
│   │   │   │   ├── Get-SqlHealth.ps1
│   │   │   │   ├── Invoke-LogCleanup.ps1
│   │   │   │   ├── New-AzureVirtualNetwork.ps1
│   │   │   │   ├── Set-AzureSqlFirewallRules.ps1
│   │   │   │   ├── Set-AzureVmTagsFromPolicy.ps1
│   │   │   │   └── config/
│   │   │   │       ├── azure-sql-firewall-config.example.json
│   │   │   │       ├── keyvault-config.example.json
│   │   │   │       └── vnet-config.example.json
│   │   │   └── migration/       # Migration scripts
│   │   │       └── README.md
│   │   └── tests/               # PowerShell tests
│   └── python/
│       ├── README.md
│       ├── health_probe.py
│       ├── sql_permissions_manager.py
│       ├── requirements.txt
│       ├── endpoints-example.json
│       └── config/
│
├── cicd-pipelines/               # CI/CD pipeline examples (Azure DevOps + GitHub Actions)
│   ├── README.md                # Pipeline overview and comparison
│   ├── github-actions/          # GitHub Actions workflow examples
│   │   ├── README.md           # Azure DevOps vs GitHub Actions comparison
│   │   └── windows-update-workflow.yml  # Converted Windows Update workflow
│   ├── server-maint-pipeline/
│   │   ├── README.md            # Server maintenance pipeline guide
│   │   ├── Server-Maintenance-Pipeline.ps1
│   │   └── server-maintenance-pipeline.yml
│   ├── sql-permissions-pipeline/
│   │   ├── README.md            # SQL permissions automation guide
│   │   ├── SQL-Permissions-Orchestrator.ps1
│   │   └── sql-permissions-pipeline.yml
│   └── windows-updates-pipeline/
│       ├── README.md            # Windows patching pipeline guide
│       ├── DynatraceSDT.ps1    # Shared by both Azure DevOps & GitHub Actions
│       ├── PreSteps.ps1        # Shared by both Azure DevOps & GitHub Actions
│       ├── PostSteps.ps1       # Shared by both Azure DevOps & GitHub Actions
│       ├── WinUpdateLibrary.ps1  # Shared by both Azure DevOps & GitHub Actions
│       ├── pipelines/
│       │   └── windows-update-pipeline.yml  # Azure DevOps version
│       └── servers/
│           ├── DevServers.ps1
│           ├── ProductionServers.ps1
│           └── UATServers.ps1
│
├── observability/                # Monitoring and observability
│   ├── README.md
│   ├── kql/                     # Azure Monitor KQL queries
│   │   ├── README.md           # KQL query documentation
│   │   ├── disk-space-monitoring.kql
│   │   ├── backup-failures.kql
│   │   ├── sql-agent-failures.kql
│   │   └── cert-expiry.kql
│   └── dynatrace/
│       ├── README.md            # 400+ line comprehensive guide
│       ├── deployment/
│       │   └── Install-OneAgent-Regional.ps1
│       ├── api-examples/
│       │   ├── Create-NetworkZones.ps1
│       │   ├── Create-MetricEvents.ps1
│       │   └── config-examples/
│       ├── azure-runbooks/
│       └── docker/
│           └── Dynatrace-OneAgent-Docker-Integration.md
│
├── runbooks/                     # Operational runbooks
│   ├── azure/
│   │   ├── README.md           # Azure runbooks overview
│   │   └── backup-verification.md
│   └── sql/
│       ├── README.md           # SQL runbooks overview
│       ├── tempdb-growth.md
│       └── job-failure-triage.md
│
├── security-compliance/          # Security and audit automation
│   ├── README.md               # Security compliance overview
│   ├── AD-Group-Audit.ps1
│   ├── ADO-AppRegistration-Audit.ps1
│   ├── Certificate-Expiry-Monitor.ps1
│   └── SOC1-WindowsUpdate-Audit.ps1
│
├── terraform/                    # Infrastructure as Code
│   ├── README.md                # Comprehensive Terraform guide
│   ├── envs/
│   │   ├── dev/                 # DEV environment (complete)
│   │   │   ├── main.tf         # SQL Server VM with AHUB, multiple disks
│   │   │   ├── variables.tf    # Variable definitions
│   │   │   ├── outputs.tf      # Output values
│   │   │   ├── versions.tf     # Provider versions
│   │   │   └── terraform.tfvars.example
│   │   ├── uat/                 # UAT environment
│   │   │   └── README.md       # UAT deployment guide
│   │   └── stage/               # Staging (placeholder)
│   └── modules/                 # Reusable Terraform modules
│       ├── README.md           # Module documentation
│       ├── network/            # VNet, subnets, NSG
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── compute-windows-vm/ # Windows VM with SQL Server support
│       │   ├── main.tf        # VM, disks, extensions, locks
│       │   ├── variables.tf   # 30+ configurable variables
│       │   └── outputs.tf     # VM details, disk IDs
│       ├── monitoring/         # Azure Monitor, Log Analytics
│       │   ├── main.tf        # Alerts, action groups, diagnostics
│       │   ├── variables.tf   # Alert thresholds, receivers
│       │   └── outputs.tf     # Workspace IDs, alert IDs
│       ├── backup/             # Azure Backup & Recovery Services
│       │   ├── main.tf        # Vault, policies, VM protection
│       │   ├── variables.tf   # Retention policies
│       │   └── outputs.tf     # Vault IDs, policy IDs
│       └── nsg-rules/          # Network Security Group rules
│           ├── main.tf        # Custom + predefined rules
│           ├── variables.tf   # Rule configurations
│           └── outputs.tf     # Rule IDs
│
└── docs/                         # Architecture and best practices
    ├── ARCHITECTURE.md          # System architecture overview
    ├── AUTH-MODES.md            # Authentication patterns guide
    ├── BEST-PRACTICES.md        # Coding and operational best practices
    ├── CICD-EXPLAINED.md        # CI/CD pipeline patterns
    ├── IDEMPOTENCY-RERUNS.md    # Idempotent design patterns
    ├── LESSONS-LEARNED.md       # Production incident learnings
    ├── PORTFOLIO-ASSESSMENT.md  # Portfolio quality assessment
    ├── SECURITY-NOTES.md        # Security implementation notes
    └── SECURITY-SCRUB-CHECKLIST.md  # Pre-publication security checklist
```

## 🚀 Featured Automation Scripts

### 1. Azure VM Tag Management (`Set-AzureVmTagsFromPolicy.ps1`)
Automatically applies tags to Azure VMs based on naming conventions. Supports multi-subscription environments with WhatIf mode for safe testing.

**Key Features:**
- Pattern-based tagging (PROD-*, DEV-*, UAT-*, *-WEB-*, *-SQL-*, etc.)
- Multi-subscription support
- Interactive or automated modes
- CSV export for reporting

### 2. Azure SQL Firewall Management (`Set-AzureSqlFirewallRules.ps1`)
Manages Azure SQL Database firewall rules across multiple servers with configuration-driven automation.

**Key Features:**
- Add/remove IP addresses in bulk
- Configuration file support for repeatability
- Export current rules for audit
- WhatIf support for safe changes

### 3. Server Admin Audit (`Get-ServerAdminAudit.ps1`)
Audits local administrator and Remote Desktop Users group membership across Windows servers for compliance reporting.

**Key Features:**
- Multi-server parallel execution
- Credential management
- CSV export for compliance
- Built-in account filtering

### 4. Log Cleanup Automation (`Invoke-LogCleanup.ps1`)
Automated cleanup of SQL Server, IIS, and SSH server logs with configurable retention policies.

**Key Features:**
- Multi-service support (SQL, IIS, SSH)
- Configurable retention periods
- Dry-run mode
- Space savings reporting

### 5. SQL Server Health Check (`Get-SqlHealth.ps1`)
Comprehensive SQL Server health monitoring including databases, backups, jobs, and disk space.

**Key Features:**
- Database status and sizing
- Backup verification
- SQL Agent job monitoring
- Disk space analysis
- TempDB configuration checks

## 🔧 PowerShell Module

The `PlatformOps.Automation` module provides reusable functions for common operational tasks:

- **Invoke-Retry:** Retry logic with exponential backoff
- **Write-StructuredLog:** Structured logging with severity levels
- **Test-TcpPort:** Network connectivity testing

## 📚 Documentation Highlights

### Comprehensive Guides
- **USAGE-GUIDE.md:** Detailed usage instructions for all automation scripts
- **Dynatrace README:** 400+ line guide covering deployment, API automation, and best practices
- **Runbooks:** Step-by-step operational procedures for common incidents

### Architecture Documentation
- System design patterns
- Multi-region deployment strategies
- Security and compliance considerations
- Lessons learned from production incidents

## 🎓 CI/CD Pipeline Examples

### Windows Update Pipeline
Multi-stage pipeline for safe Windows Server patching:
1. Pre-flight checks (disk space, services, backups)
2. Dynatrace maintenance window creation
3. Windows Update installation
4. Post-update validation
5. Monitoring re-enablement

### SQL Permissions Pipeline
Automated SQL Server permission management:
- Configuration-driven role assignments
- Multi-server orchestration
- Audit logging
- Rollback capabilities

## 🔐 Security & Compliance

### Audit Automation
- Active Directory group membership auditing
- Azure AD app registration monitoring
- Certificate expiration tracking
- Windows Update compliance reporting (SOC1)

### Security Best Practices
- Credential management with PSCredential
- Least privilege access patterns
- Audit logging for all changes
- WhatIf/dry-run support for safety

## 🌐 Observability & Monitoring

### Dynatrace Automation
- OneAgent deployment across multiple regions
- Network zone configuration
- Metric event creation via API
- Maintenance window automation
- Multi-environment support (Prod/Non-Prod)

### Health Monitoring
- Python-based HTTP health probes
- SQL Server health checks
- Service availability monitoring
- Certificate expiration alerts

## 💡 Key Highlights

### Production-Ready Code
- ✅ Comprehensive error handling
- ✅ Structured logging
- ✅ Idempotent operations
- ✅ WhatIf/dry-run support
- ✅ Parameter validation
- ✅ PSScriptAnalyzer compliant

### Real-World Solutions
- ✅ Multi-environment support (Dev/UAT/Prod)
- ✅ Multi-region Azure deployments
- ✅ Configuration-driven automation
- ✅ Audit and compliance reporting
- ✅ Incident response runbooks

### Professional Documentation
- ✅ Detailed help documentation
- ✅ Usage examples
- ✅ Architecture diagrams
- ✅ Best practices guides
- ✅ Lessons learned

## 🛠️ Technologies Used

**Languages & Frameworks:**
- PowerShell 5.1+ (advanced scripting, modules, remoting)
- Python 3.x (health probes, API integration)
- HCL (Terraform - Infrastructure as Code)
- YAML (Azure DevOps pipelines)
- KQL (Azure Monitor queries)
- JSON (configuration management)

**Platforms & Services:**
- Microsoft Azure (VMs, SQL Database, Resource Groups, Recovery Services Vaults)
- Windows Server 2012 R2 - 2022
- SQL Server 2014 - 2022
- Dynatrace (monitoring and observability)
- Azure DevOps (CI/CD pipelines)

**Tools & Modules:**
- Terraform (Infrastructure as Code)
- Az PowerShell Module (Azure automation)
- SqlServer PowerShell Module
- Git (version control)
- Docker (container monitoring integration)

## 📖 Getting Started

### Prerequisites
- PowerShell 5.1 or later
- Appropriate Azure/Windows/SQL permissions
- Required PowerShell modules (scripts auto-install if missing)

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/platform-sre-portfolio.git
   cd platform-sre-portfolio
   ```

2. **Review the documentation:**
   ```powershell
   # Read the automation usage guide
   Get-Content automation/powershell/scripts/examples/USAGE-GUIDE.md
   
   # View script help
   Get-Help automation/powershell/scripts/examples/Set-AzureVmTagsFromPolicy.ps1 -Full
   ```

3. **Test a script in WhatIf mode:**
   ```powershell
   # Preview Azure VM tagging
   .\automation\powershell\scripts\examples\Set-AzureVmTagsFromPolicy.ps1 -WhatIf
   
   # Preview log cleanup
   .\automation\powershell\scripts\examples\Invoke-LogCleanup.ps1
   ```

4. **Import the PowerShell module:**
   ```powershell
   Import-Module .\automation\powershell\Module\PlatformOps.Automation.psm1
   
   # Test module functions
   Test-TcpPort -ComputerName "server01" -Port 443
   ```

## 📝 Usage Examples

### Azure VM Tagging
```powershell
# Preview tags that would be applied
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "abc-123" -WhatIf

# Apply tags to all VMs in subscription
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "abc-123"
```

### SQL Firewall Management
```powershell
# Export current firewall rules for audit
.\Set-AzureSqlFirewallRules.ps1 -SubscriptionId "abc-123" -ResourceGroupName "sql-rg" -ExportOnly

# Apply changes from configuration file
.\Set-AzureSqlFirewallRules.ps1 -ConfigPath ".\config\azure-sql-firewall-config.json"
```

### Server Admin Audit
```powershell
# Audit production servers
.\Get-ServerAdminAudit.ps1 -ComputerName "PROD-WEB-01","PROD-APP-01","PROD-SQL-01"

# Audit from server list file
.\Get-ServerAdminAudit.ps1 -ComputerListPath "C:\servers.txt"
```

## 🎯 Use Cases

This portfolio demonstrates solutions for:

- **Cloud Infrastructure Management:** Azure VM lifecycle, tagging, resource organization
- **Database Operations:** SQL Server health monitoring, permissions, maintenance
- **Backup & Disaster Recovery:** Azure Backup monitoring, restore testing, compliance
- **Security & Compliance:** Access auditing, certificate monitoring, compliance reporting
- **Observability:** Monitoring deployment, metric automation, health checks, Docker integration
- **CI/CD Automation:** Pipeline orchestration, deployment automation
- **Operational Excellence:** Runbooks, incident response, maintenance automation
- **Container Orchestration:** Docker monitoring integration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 About

This portfolio represents 2+ years of Platform/SRE work, showcasing production-ready automation and infrastructure management across Azure cloud environments, Windows Server infrastructure, and SQL Server databases. All code has been sanitized to remove company-specific information while maintaining the technical integrity and real-world applicability of the solutions.

**Skills Demonstrated:**
- Platform/Site Reliability Engineering
- Azure Cloud Infrastructure
- Infrastructure as Code (Terraform)
- PowerShell Automation & Module Development
- CI/CD Pipeline Development
- SQL Server Administration
- Windows Server Management
- Observability & Monitoring (Dynatrace)
- Security & Compliance Automation
- Backup & Disaster Recovery
- Technical Documentation

---

**Note:** All company-specific information, credentials, and sensitive data have been removed or replaced with generic examples. This repository is safe for public sharing and demonstrates technical capabilities without exposing proprietary information.