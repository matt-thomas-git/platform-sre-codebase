v# Terraform Modules

Reusable, production-ready Terraform modules for Azure infrastructure deployment. These modules demonstrate modular Infrastructure as Code design with comprehensive variable configuration and output values.

## 📦 Available Modules

### 1. **network** - Virtual Network Infrastructure
Creates Azure Virtual Network with subnets and Network Security Groups.

**Resources Created:**
- Virtual Network (VNet)
- Subnets
- Network Security Group (NSG)
- NSG association with subnet

**Key Features:**
- Configurable address spaces
- Multiple subnet support
- Default NSG rules
- DNS server configuration

**Usage Example:**
```hcl
module "network" {
  source = "../../modules/network"
  
  resource_group_name = "rg-prod-network"
  location            = "eastus2"
  vnet_name          = "vnet-prod-001"
  address_space      = ["10.0.0.0/16"]
  
  subnets = {
    web = {
      address_prefix = "10.0.1.0/24"
    }
    app = {
      address_prefix = "10.0.2.0/24"
    }
    data = {
      address_prefix = "10.0.3.0/24"
    }
  }
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

---

### 2. **compute-windows-vm** - Windows Virtual Machine
Deploys Windows Server VMs with optional SQL Server, multiple disks, and advanced configuration.

**Resources Created:**
- Windows Virtual Machine
- Network Interface
- Public IP (optional)
- Multiple Managed Disks (data/log)
- SQL Server VM Extension (optional)
- Resource Deletion Lock (optional)

**Key Features:**
- 30+ configurable variables
- Azure Hybrid Benefit (AHUB) support
- Multiple data disk support
- SQL Server integration
- Custom script extensions
- Boot diagnostics
- Deletion protection

**Usage Example:**
```hcl
module "sql_server_vm" {
  source = "../../modules/compute-windows-vm"
  
  resource_group_name = "rg-prod-sql"
  location            = "eastus2"
  vm_name            = "vm-sql-prod-001"
  vm_size            = "Standard_E4ds_v5"
  
  # Networking
  subnet_id          = module.network.subnet_ids["data"]
  enable_public_ip   = false
  
  # OS Configuration
  admin_username     = "sqladmin"
  admin_password     = var.admin_password
  os_disk_size_gb    = 128
  license_type       = "Windows_Server"  # AHUB
  
  # Data Disks
  data_disks = [
    {
      name         = "data-disk-001"
      size_gb      = 1024
      lun          = 0
      caching      = "ReadWrite"
      storage_type = "Premium_LRS"
    },
    {
      name         = "log-disk-001"
      size_gb      = 512
      lun          = 1
      caching      = "None"
      storage_type = "Premium_LRS"
    }
  ]
  
  # SQL Server
  enable_sql_vm_extension = true
  sql_license_type        = "AHUB"
  sql_connectivity_type   = "PRIVATE"
  
  # Protection
  enable_deletion_lock = true
  
  tags = {
    Environment = "Production"
    Application = "SQL Server"
    ManagedBy   = "Terraform"
  }
}
```

---

### 3. **monitoring** - Azure Monitor & Alerts
Creates Log Analytics workspace, action groups, and metric alerts for comprehensive monitoring.

**Resources Created:**
- Log Analytics Workspace
- Action Group (email/SMS notifications)
- Metric Alerts (CPU, Memory, Disk)
- Windows Event Log collection rules
- Diagnostic Settings

**Key Features:**
- Configurable alert thresholds
- Multiple notification channels
- Custom KQL queries
- Windows Event Log monitoring
- Auto-remediation support

**Usage Example:**
```hcl
module "monitoring" {
  source = "../../modules/monitoring"
  
  resource_group_name = "rg-prod-monitoring"
  location            = "eastus2"
  
  # Log Analytics
  workspace_name      = "law-prod-001"
  retention_days      = 90
  
  # Alerts
  enable_cpu_alert    = true
  cpu_threshold       = 85
  
  enable_memory_alert = true
  memory_threshold    = 90
  
  enable_disk_alert   = true
  disk_threshold      = 85
  
  # Notifications
  action_group_name   = "ag-prod-ops"
  email_receivers = [
    {
      name          = "ops-team"
      email_address = "ops@company.com"
    }
  ]
  
  # Target Resources
  vm_ids = [
    module.sql_server_vm.vm_id
  ]
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

---

### 4. **backup** - Azure Backup & Recovery Services
Implements Azure Backup with Recovery Services Vault and configurable backup policies.

**Resources Created:**
- Recovery Services Vault
- Backup Policies (daily/weekly/monthly/yearly retention)
- VM Backup Protection
- File Share Backup (optional)

**Key Features:**
- Flexible retention policies
- Multiple backup frequencies
- Geo-redundant storage options
- VM and file share support
- Instant restore capability

**Usage Example:**
```hcl
module "backup" {
  source = "../../modules/backup"
  
  resource_group_name = "rg-prod-backup"
  location            = "eastus2"
  
  # Recovery Vault
  vault_name          = "rsv-prod-001"
  vault_sku           = "Standard"
  storage_mode        = "GeoRedundant"
  
  # Daily Backup Policy
  create_daily_backup_policy = true
  daily_backup_time          = "23:00"
  daily_retention_days       = 30
  
  # Weekly Backup
  weekly_retention_weeks     = 12
  weekly_backup_weekdays     = ["Sunday"]
  
  # Monthly Backup
  monthly_retention_months   = 12
  monthly_backup_weeks       = ["First"]
  monthly_backup_weekdays    = ["Sunday"]
  
  # Yearly Backup
  yearly_retention_years     = 7
  yearly_backup_months       = ["January"]
  yearly_backup_weeks        = ["First"]
  yearly_backup_weekdays     = ["Sunday"]
  
  # VM Protection
  protected_vms = {
    sql-vm = {
      vm_id             = module.sql_server_vm.vm_id
      backup_policy_id  = "daily"
    }
  }
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

---

### 5. **nsg-rules** - Network Security Group Rules
Manages NSG rules with both custom and predefined common rules.

**Resources Created:**
- Custom NSG Rules
- Predefined Common Rules (RDP, WinRM, SQL, HTTP/HTTPS)

**Key Features:**
- Custom rule definitions
- Predefined rule templates
- Source IP restrictions
- Port range support
- Priority management

**Usage Example:**
```hcl
module "nsg_rules" {
  source = "../../modules/nsg-rules"
  
  resource_group_name         = "rg-prod-network"
  network_security_group_name = "nsg-prod-sql"
  
  # Use predefined common rules
  use_common_rules = true
  
  # Enable specific common rules
  enable_rdp_rule    = true
  rdp_source_addresses = ["10.0.0.0/24", "10.1.0.0/24"]
  
  enable_sql_rule    = true
  sql_source_addresses = ["10.0.1.0/24", "10.0.2.0/24"]
  
  enable_https_rule  = true
  
  # Custom rules
  security_rules = {
    allow_azure_devops = {
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "AzureDevOps"
      destination_address_prefix = "*"
      description                = "Allow Azure DevOps"
    }
    allow_monitoring = {
      priority                   = 210
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["443", "8443"]
      source_address_prefixes    = ["10.0.100.0/24"]
      destination_address_prefix = "*"
      description                = "Allow monitoring systems"
    }
  }
}
```

---

## 🎯 Module Design Principles

### 1. **Reusability**
- Modules are environment-agnostic
- Configurable through variables
- No hardcoded values

### 2. **Composability**
- Modules can be combined
- Output values enable module chaining
- Minimal dependencies

### 3. **Production-Ready**
- Comprehensive variable validation
- Sensible defaults
- Complete output values
- Proper resource naming

### 4. **Documentation**
- Inline comments
- Variable descriptions
- Output descriptions
- Usage examples

## 📊 Module Outputs

Each module provides comprehensive outputs for integration:

### Network Module
- `vnet_id` - Virtual Network ID
- `vnet_name` - Virtual Network name
- `subnet_ids` - Map of subnet names to IDs
- `nsg_id` - Network Security Group ID

### Compute Module
- `vm_id` - Virtual Machine ID
- `vm_name` - Virtual Machine name
- `private_ip` - Private IP address
- `public_ip` - Public IP address (if enabled)
- `data_disk_ids` - List of data disk IDs
- `nic_id` - Network Interface ID

### Monitoring Module
- `workspace_id` - Log Analytics Workspace ID
- `workspace_key` - Workspace primary key (sensitive)
- `action_group_id` - Action Group ID
- `alert_ids` - Map of alert names to IDs

### Backup Module
- `vault_id` - Recovery Services Vault ID
- `vault_name` - Vault name
- `daily_policy_id` - Daily backup policy ID
- `weekly_policy_id` - Weekly backup policy ID
- `protected_vm_ids` - Map of protected VM IDs

### NSG Rules Module
- `custom_rule_ids` - Map of custom rule IDs
- `common_rule_ids` - Map of common rule IDs
- `all_rule_names` - List of all rule names

## 🔧 Best Practices

### Variable Naming
- Use descriptive names
- Follow Azure naming conventions
- Include units in names (e.g., `retention_days`, `size_gb`)

### Tagging Strategy
- Always include `tags` variable
- Merge module tags with resource-specific tags
- Use consistent tag keys

### Resource Naming
- Use `name` or `<resource>_name` pattern
- Support name prefixes/suffixes
- Follow organizational naming standards

### Outputs
- Export all useful resource attributes
- Mark sensitive outputs appropriately
- Provide descriptions for all outputs

## 🚀 Getting Started with Modules

### 1. Reference a Module
```hcl
module "my_module" {
  source = "../../modules/module-name"
  
  # Required variables
  resource_group_name = "my-rg"
  location            = "eastus2"
  
  # Optional variables with defaults
  # ...
}
```

### 2. Access Module Outputs
```hcl
output "vm_ip" {
  value = module.my_module.private_ip
}
```

### 3. Chain Modules
```hcl
# Create network first
module "network" {
  source = "../../modules/network"
  # ...
}

# Use network output in VM module
module "vm" {
  source = "../../modules/compute-windows-vm"
  
  subnet_id = module.network.subnet_ids["app"]
  # ...
}
```

## 📚 Additional Resources

- [Terraform Module Documentation](https://www.terraform.io/docs/language/modules/index.html)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

**Note:** All modules are designed to be production-ready with comprehensive error handling, validation, and documentation. Customize variables to match your specific requirements.
