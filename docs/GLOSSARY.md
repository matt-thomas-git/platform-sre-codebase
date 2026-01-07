# Glossary of Terms

A comprehensive guide to technical terms, acronyms, and concepts used throughout this Platform/SRE portfolio.

---

## Table of Contents

- [General IT & Cloud](#general-it--cloud)
- [Azure Services](#azure-services)
- [Automation & DevOps](#automation--devops)
- [Database & SQL](#database--sql)
- [Networking](#networking)
- [Security & Compliance](#security--compliance)
- [Monitoring & Observability](#monitoring--observability)
- [Platform/SRE Concepts](#platformsre-concepts)

---

## General IT & Cloud

### API (Application Programming Interface)
A set of rules and protocols that allows different software applications to communicate with each other. Used extensively for automation and integration.

### CLI (Command Line Interface)
A text-based interface for interacting with software and operating systems. Examples: PowerShell, Azure CLI, Bash.

### IaaS (Infrastructure as a Service)
Cloud computing model where infrastructure (VMs, storage, networks) is provided as a service. Example: Azure Virtual Machines.

### PaaS (Platform as a Service)
Cloud computing model where a platform for developing and running applications is provided. Example: Azure App Services.

### SaaS (Software as a Service)
Cloud computing model where software is delivered over the internet. Example: Microsoft 365, Salesforce.

### SLA (Service Level Agreement)
A commitment between a service provider and customer defining the expected level of service, typically including uptime guarantees.

### VM (Virtual Machine)
A software-based emulation of a physical computer, running an operating system and applications.

---

## Azure Services

### AHUB (Azure Hybrid Use Benefit)
A licensing benefit that allows you to use existing on-premises Windows Server licenses in Azure, reducing costs.

### ARM (Azure Resource Manager)
Azure's deployment and management service. ARM templates are JSON files that define infrastructure as code.

### Azure AD / Entra ID
Microsoft's cloud-based identity and access management service (recently rebranded to Microsoft Entra ID).

### Azure DevOps
Microsoft's suite of development tools including version control (Git), CI/CD pipelines, and project management.

### NSG (Network Security Group)
Azure firewall rules that control inbound and outbound network traffic to Azure resources.

### RBAC (Role-Based Access Control)
Security model that restricts system access based on user roles. In Azure, controls who can do what with Azure resources.

### RSV (Recovery Services Vault)
Azure service for backup and disaster recovery, storing backup data and managing recovery points.

### VNet (Virtual Network)
Azure's isolated network environment where you can deploy and connect Azure resources securely.

---

## Automation & DevOps

### CI/CD (Continuous Integration / Continuous Deployment)
Practice of automating code integration, testing, and deployment. CI merges code frequently; CD automatically deploys to production.

### Dry-Run
Executing a script or command in simulation mode to preview what would happen without making actual changes. Also called "WhatIf" mode.

### Idempotency
The property where an operation produces the same result whether executed once or multiple times. Critical for reliable automation - running a script twice won't cause errors or duplicate resources.

**Example:** Creating a folder is idempotent if the script checks "does folder exist? If no, create it." Running it twice is safe.

### IaC (Infrastructure as Code)
Managing and provisioning infrastructure through code rather than manual processes. Examples: Terraform, ARM templates.

### Pipeline
An automated workflow that builds, tests, and deploys code. Consists of stages (build, test, deploy) that run sequentially or in parallel.

### Terraform
An open-source infrastructure-as-code tool for building, changing, and versioning infrastructure safely and efficiently.

### YAML (YAML Ain't Markup Language)
Human-readable data serialization format commonly used for configuration files and CI/CD pipelines.

---

## Database & SQL

### Backup Verification
Process of testing that database backups can be successfully restored, ensuring disaster recovery readiness.

### Maintenance Plan
Scheduled tasks for database maintenance including backups, index rebuilds, and statistics updates.

### SSMS (SQL Server Management Studio)
Microsoft's integrated environment for managing SQL Server infrastructure and databases.

### Stored Procedure
Pre-compiled SQL code stored in the database that can be executed repeatedly, improving performance and security.

### TempDB
SQL Server's temporary workspace database used for temporary tables, sorting, and other intermediate operations.

---

## Networking

### DHCP (Dynamic Host Configuration Protocol)
Network protocol that automatically assigns IP addresses to devices on a network.

### DNS (Domain Name System)
System that translates human-readable domain names (like google.com) into IP addresses.

### ExpressRoute
Azure service providing private, dedicated connections between on-premises infrastructure and Azure datacenters.

### Load Balancer
Distributes incoming network traffic across multiple servers to ensure no single server is overwhelmed.

### Peering
Connecting two virtual networks so resources can communicate as if they're on the same network.

### TCP/IP (Transmission Control Protocol / Internet Protocol)
Fundamental communication protocols of the internet, defining how data is transmitted between devices.

### VPN (Virtual Private Network)
Secure, encrypted connection between networks over the internet, commonly used for remote access.

---

## Security & Compliance

### CAB (Change Advisory Board)
Group that reviews and approves changes to IT infrastructure to minimize risk and ensure proper planning.

### Conditional Access
Security policies that enforce requirements (like MFA) based on conditions like user location or device state.

### MFA (Multi-Factor Authentication)
Security method requiring two or more verification factors (password + phone code, for example).

### PIM (Privileged Identity Management)
Azure AD feature providing just-in-time privileged access, reducing the risk of excessive permissions.

### SAS (Shared Access Signature)
Azure security token that provides delegated access to resources without sharing account keys.

### Service Principal
Azure AD identity used by applications and services to access Azure resources programmatically.

### SOC1 (Service Organization Control 1)
Audit report focusing on controls relevant to financial reporting, often required for compliance.

---

## Monitoring & Observability

### Alert
Automated notification triggered when a monitored metric exceeds a threshold or meets specific conditions.

### Dynatrace
Enterprise monitoring platform providing application performance monitoring, infrastructure monitoring, and AI-powered analytics.

### KQL (Kusto Query Language)
Query language used in Azure Monitor, Log Analytics, and Application Insights for analyzing log data.

### Log Analytics
Azure service for collecting, analyzing, and acting on log data from cloud and on-premises environments.

### Metric Event
Custom monitoring event created to track specific conditions or thresholds in your infrastructure.

### Network Zone
Dynatrace concept for grouping monitored entities based on network location or environment (Prod, Dev, etc.).

### OneAgent
Dynatrace's monitoring agent that automatically discovers and monitors applications and infrastructure.

### Synthetic Monitoring
Automated testing that simulates user interactions to proactively detect issues before real users are affected.

---

## Platform/SRE Concepts

### Automation Framework
Reusable code library providing common functions (logging, retry logic, error handling) for building automation scripts.

### Backoff (Exponential Backoff)
Retry strategy where wait time between retries increases exponentially (1s, 2s, 4s, 8s...), preventing system overload.

### Error Handling
Code that anticipates and manages errors gracefully, preventing script failures and providing useful error messages.

### Orchestration
Coordinating multiple automated tasks or systems to work together as a unified workflow.

### Parallel Execution
Running multiple tasks simultaneously rather than sequentially, improving performance for operations like multi-server updates.

### Platform Engineering
Building and maintaining internal platforms and tools that enable development teams to work more efficiently.

### Retry Logic
Automatically attempting a failed operation multiple times before giving up, improving reliability for transient failures.

### Runbook
Step-by-step documentation for handling operational tasks or incidents, ensuring consistent execution.

### SRE (Site Reliability Engineering)
Engineering discipline focused on creating scalable, reliable software systems through automation and operational excellence.

### Structured Logging
Logging format that outputs consistent, parseable data (JSON, key-value pairs) rather than free-form text, enabling better analysis.

### WhatIf Mode
PowerShell parameter that shows what would happen if a command runs without actually executing it. Essential for safe testing.

---

## Acronyms Quick Reference

| Acronym | Full Term | Category |
|---------|-----------|----------|
| AD | Active Directory | Security |
| AHUB | Azure Hybrid Use Benefit | Azure |
| API | Application Programming Interface | General |
| ARM | Azure Resource Manager | Azure |
| CAB | Change Advisory Board | Operations |
| CI/CD | Continuous Integration/Continuous Deployment | DevOps |
| CLI | Command Line Interface | General |
| DHCP | Dynamic Host Configuration Protocol | Networking |
| DNS | Domain Name System | Networking |
| DR | Disaster Recovery | Operations |
| ESXI | VMware ESXi Hypervisor | Virtualization |
| FSMO | Flexible Single Master Operations | Active Directory |
| GRS | Geo-Redundant Storage | Azure |
| IaaS | Infrastructure as a Service | Cloud |
| IaC | Infrastructure as Code | DevOps |
| IIS | Internet Information Services | Web Server |
| JSON | JavaScript Object Notation | Data Format |
| KQL | Kusto Query Language | Monitoring |
| LRS | Locally Redundant Storage | Azure |
| MFA | Multi-Factor Authentication | Security |
| NAS | Network Attached Storage | Storage |
| NSG | Network Security Group | Azure |
| PaaS | Platform as a Service | Cloud |
| PIM | Privileged Identity Management | Security |
| RAID | Redundant Array of Independent Disks | Storage |
| RBAC | Role-Based Access Control | Security |
| RDS | Remote Desktop Services | Windows |
| RSV | Recovery Services Vault | Azure |
| SaaS | Software as a Service | Cloud |
| SAN | Storage Area Network | Storage |
| SAS | Shared Access Signature | Azure |
| SDT | Scheduled Downtime | Monitoring |
| SLA | Service Level Agreement | Operations |
| SOC1 | Service Organization Control 1 | Compliance |
| SRE | Site Reliability Engineering | Operations |
| SSH | Secure Shell | Networking |
| SSMS | SQL Server Management Studio | Database |
| SSRS | SQL Server Reporting Services | Database |
| TCP/IP | Transmission Control Protocol/Internet Protocol | Networking |
| VM | Virtual Machine | Virtualization |
| VNet | Virtual Network | Azure |
| VPN | Virtual Private Network | Networking |
| VSS | Volume Shadow Copy Service | Backup |
| YAML | YAML Ain't Markup Language | Data Format |
| ZRS | Zone-Redundant Storage | Azure |

---

## Common PowerShell Terms

### Parameter
Input value passed to a script or function. Example: `-ComputerName "Server01"`

### Pipeline
PowerShell feature allowing output from one command to be input for another. Example: `Get-Process | Where-Object {$_.CPU -gt 100}`

### PSCredential
PowerShell object for securely storing and passing credentials (username/password).

### Remoting
PowerShell feature for running commands on remote computers.

### Splatting
PowerShell technique for passing multiple parameters to a command using a hashtable, improving readability.

### WhatIf
PowerShell common parameter that shows what would happen without executing the command.

---

## Terraform Terms

### Module
Reusable Terraform configuration that can be called multiple times with different inputs.

### Provider
Plugin that enables Terraform to interact with cloud platforms (Azure, AWS, etc.).

### State File
Terraform's record of managed infrastructure, tracking what exists and what needs to change.

### Variable
Input parameter for Terraform configurations, allowing customization without changing code.

---

## Best Practices Terminology

### Configuration-Driven
Approach where behavior is controlled by configuration files rather than hard-coded values, improving flexibility.

### Least Privilege
Security principle of granting only the minimum permissions necessary to perform a task.

### Multi-Environment
Supporting multiple deployment environments (Dev, UAT, Prod) with the same codebase.

### Production-Grade
Code quality suitable for production use: error handling, logging, testing, documentation.

### Sanitization
Removing sensitive information (credentials, company names, IPs) from code before public sharing.

---

## Need More Information?

If you encounter a term not listed here:
1. Check the specific README in the relevant folder
2. Review the code comments in related scripts
3. Consult Microsoft Azure documentation
4. See the [BEST-PRACTICES.md](BEST-PRACTICES.md) guide

---

*This glossary is maintained as part of the platform-sre-codebase portfolio to ensure accessibility and understanding for all skill levels.*
