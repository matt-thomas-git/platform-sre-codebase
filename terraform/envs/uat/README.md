# UAT Environment - SQL Server VM Deployment

This UAT environment uses the same Terraform configuration as DEV with different variable values.

## Quick Start

1. **Copy the DEV Terraform files to this directory:**
   ```bash
   cp ../dev/*.tf .
   ```

2. **Create your terraform.tfvars file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Update the values for UAT environment:**
   - Change `vm_name` to UAT naming convention (e.g., `vm-sql-uat-01`)
   - Update `private_ip_address` for UAT subnet
   - Update `resource_group_name` to UAT resource group
   - Update `subnet_name` to UAT subnet
   - Adjust `vm_size` if UAT requires different sizing

4. **Initialize and apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Key Differences from DEV

- **VM Size:** UAT may use larger VMs to match production sizing
- **Network:** Different subnet and IP address
- **Resource Group:** Separate UAT resource group
- **Tags:** Environment tag set to "uat"

## Example terraform.tfvars for UAT

```hcl
# Azure Configuration
subscription_id = "00000000-0000-0000-0000-000000000000"
location        = "North Europe"

# Resource Group
resource_group_name = "rg-sql-uat"

# Virtual Network Configuration
vnet_resource_group_name = "rg-network-shared"
vnet_name                = "vnet-shared-northeurope"
subnet_name              = "snet-database-uat"

# Virtual Machine Configuration
vm_name            = "vm-sql-uat-01"
vm_size            = "Standard_E8ds_v5"  # Larger than DEV
nic_name           = "nic-sql-uat-01"
public_ip_name     = "pip-sql-uat-01"
domain_name_label  = "sql-uat-01"
private_ip_address = "10.100.7.25"  # Different subnet

# SQL Server Configuration (same as DEV)
sql_publisher    = "MicrosoftSQLServer"
sql_offer        = "SQL2019-WS2019"
sql_sku          = "Standard"
sql_version      = "latest"
sql_license_type = "AHUB"

# Admin Credentials
admin_username = "azureuser"
admin_password = "CHANGE-ME-SuperSecureP@ssw0rd!"
```

## Notes

- UAT environment should mirror production as closely as possible
- Consider using the same VM size as production for accurate testing
- Ensure network security rules match production requirements
- Test backup and restore procedures in UAT before production deployment
