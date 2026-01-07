# Observability & Monitoring

Comprehensive observability automation including monitoring deployment, configuration, and management across multi-region environments.

## Overview

This section contains production-ready automation for enterprise observability platforms, demonstrating:

- **Automated Deployment**: Multi-region agent deployment with network zone configuration
- **API-Driven Configuration**: Infrastructure-as-code approach to monitoring setup
- **Custom Alerting**: Metric events and threshold management
- **KQL Queries**: Azure Monitor and Log Analytics query examples
- **Multi-Region Architecture**: Regional monitoring infrastructure design

## Structure

```
observability/
├── README.md (this file)
├── dynatrace/
│   ├── README.md                        # Dynatrace-specific documentation
│   ├── deployment/
│   │   └── Install-OneAgent-Regional.ps1    # Multi-region OneAgent deployment
│   ├── api-examples/
│   │   ├── Create-NetworkZones.ps1          # Network zone automation
│   │   ├── Create-MetricEvents.ps1          # Custom metric alerting
│   │   └── config-examples/
│   │       ├── network-zones.json           # Network zone definitions
│   │       └── deployment-config.json       # Deployment configuration
│   └── docs/
│       └── network-zones-guide.md           # Network zone planning
└── kql/
    ├── disk-space.kql                   # Disk space monitoring queries
    ├── backup-failures.kql              # Backup failure detection
    ├── sql-agent-failures.kql           # SQL Agent job monitoring
    └── cert-expiry.kql                  # Certificate expiration tracking
```

## Components

### Dynatrace Automation

Enterprise-scale Dynatrace implementation with multi-region support.

**Key Features:**
- OneAgent deployment across Azure regions
- Network zone management via API
- Custom metric events for infrastructure alerting
- ActiveGate integration for regional routing

**Quick Start:**
```powershell
# Navigate to Dynatrace folder
cd observability/dynatrace

# Create network zones
.\api-examples\Create-NetworkZones.ps1 `
    -ApiToken "dt0c01.YOUR_TOKEN" `
    -TenantUrl "https://abc12345.live.dynatrace.com"

# Deploy OneAgent
.\deployment\Install-OneAgent-Regional.ps1 `
    -MsiPath "\\fileserver\software\Dynatrace-OneAgent.msi"
```

**See:** [dynatrace/README.md](dynatrace/README.md) for detailed documentation

### KQL Queries

Azure Monitor and Log Analytics queries for infrastructure monitoring.

**Available Queries:**

#### Disk Space Monitoring
```kql
// Alert on disk space > 85%
Perf
| where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
| where InstanceName != "_Total"
| where CounterValue < 15  // Less than 15% free
| summarize AvgFreeSpace = avg(CounterValue) by Computer, InstanceName
| where AvgFreeSpace < 15
| project Computer, Drive=InstanceName, FreeSpacePercent=AvgFreeSpace
| order by FreeSpacePercent asc
```

#### Backup Failures
```kql
// Detect failed backups in last 24 hours
Event
| where EventLog == "Application"
| where Source == "MSSQLSERVER" or Source == "SQLSERVERAGENT"
| where EventLevelName == "Error"
| where RenderedDescription contains "backup" or RenderedDescription contains "BACKUP"
| where TimeGenerated > ago(24h)
| project TimeGenerated, Computer, EventID, RenderedDescription
| order by TimeGenerated desc
```

#### SQL Agent Job Failures
```kql
// Failed SQL Agent jobs
Event
| where EventLog == "Application"
| where Source == "SQLSERVERAGENT"
| where EventID == 208  // Job failed
| where TimeGenerated > ago(24h)
| extend JobName = extract(@"Job '([^']+)'", 1, RenderedDescription)
| project TimeGenerated, Computer, JobName, RenderedDescription
| order by TimeGenerated desc
```

#### Certificate Expiration
```kql
// Certificates expiring in next 30 days
Event
| where EventLog == "System"
| where Source == "Schannel"
| where EventID == 36888  // Certificate near expiration
| where TimeGenerated > ago(7d)
| project TimeGenerated, Computer, RenderedDescription
| order by TimeGenerated desc
```

## Use Cases

### 1. Multi-Region Monitoring Deployment

Deploy monitoring agents across multiple Azure regions with regional routing:

```powershell
# Step 1: Create network zones for each region
.\dynatrace\api-examples\Create-NetworkZones.ps1 `
    -ApiToken $token `
    -TenantUrl $tenant `
    -ConfigFile ".\dynatrace\api-examples\config-examples\network-zones.json"

# Step 2: Deploy OneAgent with regional configuration
.\dynatrace\deployment\Install-OneAgent-Regional.ps1 `
    -MsiPath $msiPath `
    -ConfigFile ".\dynatrace\api-examples\config-examples\deployment-config.json"
```

### 2. Custom Infrastructure Alerting

Create multi-threshold alerts for infrastructure metrics:

```powershell
# Create disk space alerts at 85%, 90%, 95%
.\dynatrace\api-examples\Create-MetricEvents.ps1 `
    -ApiToken $token `
    -TenantUrl $tenant `
    -Environment "Production"
```

### 3. Azure Monitor Integration

Use KQL queries in Azure Monitor workbooks or alerts:

```powershell
# Deploy KQL queries to Log Analytics workspace
$queries = Get-ChildItem -Path ".\kql\*.kql"
foreach ($query in $queries) {
    $queryContent = Get-Content $query.FullName -Raw
    # Deploy to Azure Monitor alert rule or workbook
}
```

## Architecture Patterns

### Multi-Region Monitoring

```
┌─────────────────────────────────────────────────────────────┐
│                  Monitoring Platform (SaaS)                 │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
│  Regional      │  │  Regional      │  │  Regional      │
│  Gateway       │  │  Gateway       │  │  Gateway       │
│  (East US 2)   │  │  (West EU)     │  │  (SE Asia)     │
└───────┬────────┘  └───────┬────────┘  └──────┬─────────┘
        │                   │                   │
    ┌───┴───┐           ┌───┴───┐           ┌───┴───┐
    │Agents │           │Agents │           │Agents │
    └───────┘           └───────┘           └───────┘
```

**Benefits:**
- Reduced latency with regional routing
- Improved reliability with regional failover
- Better compliance with data residency requirements
- Optimized bandwidth usage

### Alerting Hierarchy

```
Critical (95%) ──► Page On-Call Engineer
    │
    ▼
Error (90%)    ──► Create Incident Ticket
    │
    ▼
Warning (85%)  ──► Send Email Notification
```

## Best Practices

### Deployment

1. **Staged Rollout**: Deploy to non-production first, validate, then production
2. **Regional Segmentation**: Use network zones for geographic organization
3. **Automated Testing**: Verify agent connectivity before mass deployment
4. **Version Control**: Track agent versions and configuration changes

### Alerting

1. **Threshold Tuning**: Start conservative, adjust based on historical data
2. **Alert Fatigue**: Avoid over-alerting with appropriate thresholds
3. **Actionable Alerts**: Every alert should have a clear remediation path
4. **Multi-Level Severity**: Use Warning → Error → Critical progression

### API Management

1. **Token Security**: Store API tokens in Azure Key Vault
2. **Least Privilege**: Grant minimum required permissions
3. **Token Rotation**: Rotate tokens on regular schedule
4. **Audit Logging**: Log all API operations for compliance

### Query Optimization

1. **Time Ranges**: Limit queries to necessary time windows
2. **Filtering**: Apply filters early in query pipeline
3. **Aggregation**: Use summarize for large datasets
4. **Indexing**: Leverage indexed columns for better performance

## Integration Examples

### Azure DevOps Pipeline

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - observability/*

variables:
  monitoringToken: $(DYNATRACE_API_TOKEN)
  tenantUrl: 'https://abc12345.live.dynatrace.com'

stages:
  - stage: DeployMonitoring
    jobs:
      - job: ConfigureMonitoring
        steps:
          - task: PowerShell@2
            inputs:
              filePath: 'observability/dynatrace/api-examples/Create-MetricEvents.ps1'
              arguments: '-ApiToken $(monitoringToken) -TenantUrl $(tenantUrl)'
            displayName: 'Create Metric Events'
```

### Terraform Integration

```hcl
# Deploy monitoring configuration as code
resource "dynatrace_network_zone" "azure_eastus2" {
  name        = "azure.eastus2.prod"
  description = "Production Network Zone - Azure East US 2"
  enabled     = true
}

resource "dynatrace_metric_event" "disk_space_warning" {
  summary     = "Disk Space Warning - 85%"
  enabled     = true
  metric_selector = "builtin:host.disk.usedPct"
  threshold   = 85.0
  alert_condition = "ABOVE"
}
```

## Troubleshooting

### Common Issues

#### Agent Not Reporting

**Symptoms:** Agent installed but not visible in monitoring platform

**Solutions:**
1. Verify network connectivity to ActiveGate/Gateway
2. Check firewall rules allow outbound HTTPS (443) and communication port (9999)
3. Validate network zone configuration
4. Review agent logs for connection errors

#### High Alert Volume

**Symptoms:** Too many alerts, alert fatigue

**Solutions:**
1. Review and adjust thresholds based on baseline
2. Implement alert suppression during maintenance windows
3. Use alert grouping/correlation
4. Add environment-specific filters

#### Query Performance Issues

**Symptoms:** KQL queries timing out or slow

**Solutions:**
1. Reduce time range to minimum necessary
2. Add filters early in query pipeline
3. Use summarize instead of raw data
4. Leverage indexed columns

## Additional Resources

- [Dynatrace Documentation](dynatrace/README.md)
- [KQL Query Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [Azure Monitor Best Practices](https://docs.microsoft.com/en-us/azure/azure-monitor/best-practices)
- [Observability Patterns](../docs/ARCHITECTURE.md)

## Contributing

When adding new monitoring automation:

1. Follow existing naming conventions
2. Include comprehensive documentation
3. Add example configurations
4. Test in non-production first
5. Update this README with new components

## License

See LICENSE file in repository root.
