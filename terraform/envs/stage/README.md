# Staging Environment

This directory is reserved for Staging environment Terraform configurations.

## Purpose

The Staging environment serves as a final pre-production validation environment that mirrors production as closely as possible.

## Typical Configuration

A complete staging environment would include:

```
stage/
├── main.tf              # Main infrastructure configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output values
├── versions.tf          # Provider version constraints
├── terraform.tfvars     # Environment-specific values (gitignored)
└── README.md           # This file
```

## Environment Characteristics

**Staging Environment Typically Includes:**
- Production-like infrastructure sizing
- Production-like network configuration
- Production-like security controls
- Integration with production monitoring
- Production deployment procedures
- Performance and load testing capabilities

## Deployment Workflow

```
Dev → UAT → **Staging** → Production
```

Staging is the final gate before production deployment.

## Status

This folder is currently a placeholder. 

**Reasons for placeholder status:**
1. Portfolio repository - full staging configs contain proprietary information
2. Staging environments are often company-specific
3. DEV environment (in `../dev/`) provides a complete working example

## Reference

For a complete Terraform environment example, see:
- **[../dev/](../dev/)** - Fully implemented DEV environment with SQL Server VM
- **[../uat/README.md](../uat/README.md)** - UAT environment deployment guide
- **[../../modules/](../../modules/)** - Reusable Terraform modules

## Next Steps

To implement a staging environment:

1. Copy the DEV environment as a starting point:
   ```bash
   cp -r ../dev/* ./
   ```

2. Update `terraform.tfvars` with staging-specific values:
   - Resource names (add `-stage` suffix)
   - VM sizes (match production sizing)
   - Network configuration
   - Tags (Environment: Staging)

3. Initialize and plan:
   ```bash
   terraform init
   terraform plan -out=stage.tfplan
   ```

4. Apply after review:
   ```bash
   terraform apply stage.tfplan
   ```

---

**Note:** This is a portfolio repository. Staging configurations have been excluded to protect proprietary infrastructure details.
