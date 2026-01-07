# Terraform - Azure SQL Server VM Deployments

Production-ready Terraform configurations for deploying Windows VMs with SQL Server 2019 Standard Edition on Azure.

## 🎯 What This Demonstrates

### Infrastructure as Code Skills
- **Azure Resource Management:** VMs, disks, networking, NSGs
- **Azure Hybrid Benefit (AHUB):** Cost optimization for Windows Server and SQL Server licenses
- **Multi-Disk Configuration:** Separate OS, Data, and Log disks with appropriate caching
- **Network Security:** NSG rules for SQL Server, Azure DevOps, and monitoring systems
- **Resource Protection:** Deletion locks to prevent accidental removal
- **Multi-Environment:** DEV and UAT configurations with environment-specific variables

### Production-Ready Features
- ✅ **Azure Hybrid Benefit** for Windows Server and SQL Server
- ✅ **Multiple Managed Disks** (OS, Data 1TB, Log 512GB)
- ✅ **Optimized Disk Caching** (ReadWrite for data, None for logs)
- ✅ **Static IP Addresses** (public and private)
- ✅ **Network Security Groups** with environment-specific rules
- ✅ **Deletion Locks** to prevent accidental resource removal
- ✅ **Lifecycle Management** with ignore_changes for tags
- ✅ **Comprehensive Outputs** for integration with other systems

## 📁 Repository Structure

```
terraform/
├── README.md                    # This file
├── envs/
│   ├── dev/                     # Development environment
│   │   ├── main.tf             # Main configuration
│   │   ├── variables.tf        # Variable definitions
│   │   ├── outputs.tf          # Output values
│   │   ├── versions.tf         # Provider versions
│   │   └── terraform.tfvars.example  # Example variables
│   ├── uat/                     # UAT environment
│   │   └── README.md           # UAT-specific instructions
│   └── stage/                   # Staging environment (placeholder)
└── modules/                     # Reusable Terraform modules
    ├── README.md               # Module documentation
    ├── network/                # VNet, subnets, NSG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute-windows-vm/     # Windows VM with SQL Server support
    │   ├── main.tf            # VM, disks, extensions, locks
    │   ├── variables.tf       # 30+ configurable variables
    │   └── outputs.tf         # VM details, disk IDs
    ├── monitoring/             # Azure Monitor, Log Analytics
    │   ├── main.tf            # Alerts, action groups, diagnostics
    │   ├── variables.tf       # Alert thresholds, receivers
    │   └── outputs.tf         # Workspace IDs, alert IDs
    ├── backup/                 # Azure Backup & Recovery Services
    │   ├── main.tf            # Vault, policies, VM protection
    │   ├── variables.tf       # Retention policies
    │   └── outputs.tf         # Vault IDs, policy IDs
    └── nsg-rules/              # Network Security Group rules
        ├── main.tf            # Custom + predefined rules
        ├── variables.tf       # Rule configurations
        └── outputs.tf         # Rule IDs
```

## 🚀 Quick Start

### Prerequisites
- Terraform >= 1.0
- Azure CLI installed and authenticated
- Appropriate Azure permissions (Contributor or Owner)
- Existing Azure resources:
  - Resource Group
  - Virtual Network
  - Subnet

### Deploy DEV Environment

1. **Navigate to the DEV environment:**
   ```bash
   cd envs/dev
   ```

2. **Create terraform.tfvars from example:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars with your values:**
   ```bash
   # Update subscription_id, resource_group_name, vnet details, etc.
   vim terraform.tfvars
   ```

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Review the plan:**
   ```bash
   terraform plan
   ```

6. **Apply the configuration:**
   ```bash
   terraform apply
   ```

### Deploy UAT Environment

See `envs/uat/README.md` for UAT-specific instructions.

## 🔧 Configuration Details

### VM Specifications (DEV Example)

| Component | Specification |
|-----------|--------------|
| **VM Size** | Standard_E4ds_v5 (4 vCPUs, 32 GB RAM) |
| **OS Disk** | 128 GB StandardSSD_LRS |
| **Data Disk** | 1024 GB Premium_LRS (LUN 0, ReadWrite caching) |
| **Log Disk** | 512 GB Premium_LRS (LUN 1, No caching) |
| **OS** | Windows Server 2019 |
| **SQL Server** | SQL Server 2019 Standard Edition |
| **License** | Azure Hybrid Benefit (AHUB) |

### Azure Hybrid Benefit (AHUB)

This configuration uses AHUB for both Windows Server and SQL Server, providing significant cost savings:

```hcl
# Windows Server AHUB
license_type = "Windows_Server"

# SQL Server AHUB
sql_license_type = "AHUB"
```

**Cost Savings:** Up to 40% on Windows Server and up to 55% on SQL Server licensing costs.

### Network Security

The configuration includes NSG rules for:
- **SQL Server (1433):** Restricted to specific IP ranges
- **Azure DevOps:** For CI/CD pipeline access
- **Monitoring Systems:** For health checks and metrics collection

### Disk Configuration

**Why separate disks?**
- **OS Disk:** System files and applications
- **Data Disk:** SQL Server data files (.mdf) - ReadWrite caching for performance
- **Log Disk:** SQL Server log files (.ldf) - No caching for write integrity

**Caching Strategy:**
- **Data Disk:** `ReadWrite` - Improves read performance for data files
- **Log Disk:** `None` - Ensures write integrity for transaction logs

## 📊 Outputs

After deployment, Terraform provides useful outputs:

```bash
terraform output
```

Example outputs:
- `vm_id` - Azure resource ID of the VM
- `vm_private_ip` - Private IP address
- `vm_public_ip` - Public IP address
- `vm_fqdn` - Fully qualified domain name
- `data_disk_id` - Data disk resource ID
- `log_disk_id` - Log disk resource ID

## 🔐 Security Best Practices

### Credentials Management
- **Never commit terraform.tfvars** to version control
- Use Azure Key Vault for production passwords
- Consider using managed identities where possible

### Network Security
- Restrict NSG rules to specific IP ranges
- Use Azure Bastion for secure RDP access
- Implement Just-In-Time (JIT) VM access

### Resource Protection
- Deletion locks are enabled by default
- Use Azure Policy for governance
- Implement Azure Backup for data protection

## 🎓 Learning Resources

### Terraform Concepts Demonstrated
1. **Data Sources:** Referencing existing Azure resources
2. **Resource Dependencies:** Implicit and explicit dependencies
3. **Lifecycle Management:** Using `ignore_changes` for tag management
4. **Output Values:** Exposing resource attributes
5. **Variables:** Parameterizing configurations
6. **Provider Configuration:** Azure provider setup

### Azure Concepts Demonstrated
1. **Azure Hybrid Benefit:** License cost optimization
2. **Managed Disks:** Premium and Standard SSD tiers
3. **Network Security Groups:** Inbound/outbound rules
4. **Static IP Allocation:** Public and private IPs
5. **Resource Locks:** Preventing accidental deletion
6. **SQL VM Extension:** SQL Server-specific configuration

## 📝 Common Operations

### View Current State
```bash
terraform show
```

### List Resources
```bash
terraform state list
```

### Destroy Environment (with caution!)
```bash
# Note: Deletion lock must be removed first
terraform destroy
```

### Format Code
```bash
terraform fmt -recursive
```

### Validate Configuration
```bash
terraform validate
```

## 🔄 Multi-Environment Strategy

This repository demonstrates a multi-environment approach:

- **DEV:** Full Terraform configuration with all files
- **UAT:** Reuses DEV configuration with different tfvars
- **STAGE:** Placeholder for staging environment

**Benefits:**
- DRY (Don't Repeat Yourself) principle
- Consistent configuration across environments
- Easy to promote changes from DEV → UAT → STAGE → PROD

## 🚨 Important Notes

1. **Deletion Locks:** VMs are protected with `CanNotDelete` locks. Remove the lock before destroying resources.
2. **Costs:** Premium SSD disks and E-series VMs incur ongoing costs. Deallocate VMs when not in use.
3. **AHUB Licensing:** Ensure you have valid Windows Server and SQL Server licenses for AHUB.
4. **Backup:** This configuration does not include Azure Backup. Implement separately for production.

## 🎯 Real-World Use Cases

This Terraform configuration was used for:
- **SQL Server Development Environments:** Rapid provisioning of dev/test SQL servers
- **UAT Testing:** Pre-production testing with production-like configurations
- **Disaster Recovery:** Quick rebuild of SQL Server infrastructure
- **Cost Optimization:** AHUB implementation saving 40-55% on licensing

## 📚 Additional Documentation

- [Azure Hybrid Benefit](https://azure.microsoft.com/en-us/pricing/hybrid-benefit/)
- [SQL Server on Azure VMs](https://docs.microsoft.com/en-us/azure/azure-sql/virtual-machines/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Managed Disks](https://docs.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview)

---

**Note:** All sensitive information (subscription IDs, IP addresses, passwords) has been removed or replaced with examples. This configuration is safe for public sharing and demonstrates Infrastructure as Code best practices.
