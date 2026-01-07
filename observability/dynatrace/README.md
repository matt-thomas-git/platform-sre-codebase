# Dynatrace Observability Automation

Automation scripts and examples for Dynatrace deployment, configuration, and management across multi-region environments.

## Overview

This collection demonstrates enterprise-scale Dynatrace implementation including:

- **OneAgent Deployment**: Automated agent installation across multiple Azure regions
- **Network Zone Management**: API-driven network zone configuration for optimal routing
- **Metric Events**: Custom alerting thresholds via Settings API
- **Multi-Region Architecture**: Regional ActiveGates with network zone segmentation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Dynatrace Tenant                         │
│                 (SaaS or Managed)                           │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
│  ActiveGate    │  │  ActiveGate    │  │  ActiveGate    │
│  East US 2     │  │  West Europe   │  │  Southeast Asia│
│  Network Zone  │  │  Network Zone  │  │  Network Zone  │
└───────┬────────┘  └───────┬────────┘  └──────┬─────────┘
        │                   │                   │
    ┌───┴───┐           ┌───┴───┐           ┌───┴───┐
    │OneAgent│          │OneAgent│          │OneAgent│
    │Servers │          │Servers │          │Servers │
    └────────┘          └────────┘          └────────┘
```

**Key Concepts:**

- **Network Zones**: Logical groupings that route OneAgent traffic to regional ActiveGates
- **ActiveGates**: Regional proxies that reduce latency and provide local data processing
- **OneAgents**: Lightweight agents installed on monitored hosts
- **Metric Events**: Custom alerting rules based on metric thresholds

## Structure

```
dynatrace/
├── README.md (this file)
├── deployment/
│   └── Install-OneAgent-Regional.ps1    # Multi-region OneAgent deployment
├── api-examples/
│   ├── Create-NetworkZones.ps1          # Network zone automation
│   ├── Create-MetricEvents.ps1          # Custom metric alerting
│   └── config-examples/
│       ├── network-zones.json           # Network zone definitions
│       └── deployment-config.json       # Deployment configuration
├── docker/
│   └── Dynatrace-OneAgent-Docker-Integration.md  # Docker container integration
├── azure-runbooks/                      # Placeholder for future runbooks
└── docs/
    └── network-zones-guide.md           # Network zone planning guide
```

## Quick Start

### Prerequisites

- PowerShell 5.1 or later
- Dynatrace tenant (SaaS or Managed)
- API tokens with appropriate permissions
- PowerShell Remoting enabled (for OneAgent deployment)

### 1. Create Network Zones

Network zones organize your monitoring by region or network segment:

```powershell
# Create network zones for multi-region setup
.\api-examples\Create-NetworkZones.ps1 `
    -ApiToken "dt0c01.YOUR_TOKEN" `
    -TenantUrl "https://abc12345.live.dynatrace.com"
```

**Required API Token Permissions:**
- `networkZones.write`
- `networkZones.read`

### 2. Deploy OneAgent

Deploy OneAgent to servers across multiple regions:

```powershell
# Deploy with default configuration
.\deployment\Install-OneAgent-Regional.ps1 `
    -MsiPath "\\fileserver\software\Dynatrace-OneAgent.msi"

# Deploy with custom config file
.\deployment\Install-OneAgent-Regional.ps1 `
    -MsiPath "\\fileserver\software\Dynatrace-OneAgent.msi" `
    -ConfigFile ".\config\deployment-config.json"
```

**Configuration Example:**

```json
[
  {
    "NetworkZone": "azure.eastus2.prod",
    "ActiveGate": "https://activegate-eus2.company.local:9999/communication",
    "Servers": ["app-01.company.local", "app-02.company.local"]
  },
  {
    "NetworkZone": "azure.westeurope.prod",
    "ActiveGate": "https://activegate-weu.company.local:9999/communication",
    "Servers": ["app-03.company.local", "app-04.company.local"]
  }
]
```

### 3. Create Metric Events

Set up custom alerting thresholds:

```powershell
# Create disk space alerts for production
.\api-examples\Create-MetricEvents.ps1 `
    -ApiToken "dt0c01.YOUR_TOKEN" `
    -TenantUrl "https://abc12345.live.dynatrace.com" `
    -Environment "Production"
```

**Required API Token Permissions:**
- `settings.write`
- `settings.read`

## Deployment Scripts

### Install-OneAgent-Regional.ps1

Automated OneAgent deployment across multiple network zones.

**Features:**
- Multi-region support with network zone configuration
- Connectivity pre-checks before installation
- Detailed logging (CSV + text log)
- Error handling and retry logic
- Remote execution via PowerShell Remoting

**Parameters:**
- `-MsiPath`: Path to OneAgent MSI installer
- `-ConfigFile`: Optional JSON configuration file

**Example Output:**
```
========================================
Dynatrace OneAgent Regional Deployment
========================================

Processing Network Zone: azure.eastus2.prod
Installing on: app-server-01.company.local
  ✓ Successfully installed on app-server-01.company.local

========================================
Deployment Summary
========================================
Total Servers:  5
Successful:     5
Failed:         0
```

## API Examples

### Create-NetworkZones.ps1

Creates network zones via Dynatrace API for regional segmentation.

**Use Cases:**
- Initial setup of multi-region monitoring
- Adding new Azure regions
- Organizing on-premises vs. cloud environments

**Example:**
```powershell
.\Create-NetworkZones.ps1 `
    -ApiToken "dt0c01.ABC123..." `
    -TenantUrl "https://abc12345.live.dynatrace.com" `
    -ConfigFile ".\config\network-zones.json"
```

### Create-MetricEvents.ps1

Creates custom metric events for infrastructure alerting.

**Use Cases:**
- Disk space monitoring with multiple thresholds
- Custom performance baselines
- Environment-specific alerting rules

**Features:**
- Multi-threshold alerting (Warning, Error, Critical)
- Entity filtering with tags
- Environment-based metric selectors
- Automatic validation and error handling

**Example:**
```powershell
# Create alerts for all environments
.\Create-MetricEvents.ps1 `
    -ApiToken "dt0c01.ABC123..." `
    -TenantUrl "https://abc12345.live.dynatrace.com" `
    -Environment "All"
```

## Configuration Examples

### Network Zones Configuration

**File:** `config-examples/network-zones.json`

```json
[
  {
    "name": "azure.eastus2.prod",
    "description": "Production Network Zone - Azure East US 2"
  },
  {
    "name": "azure.westeurope.prod",
    "description": "Production Network Zone - Azure West Europe"
  },
  {
    "name": "azure.southeastasia.prod",
    "description": "Production Network Zone - Azure Southeast Asia"
  },
  {
    "name": "onprem.datacenter1",
    "description": "On-Premises Datacenter 1"
  }
]
```

### Deployment Configuration

**File:** `config-examples/deployment-config.json`

```json
[
  {
    "NetworkZone": "azure.eastus2.prod",
    "ActiveGate": "https://activegate-eus2.company.local:9999/communication",
    "Servers": [
      "web-server-01.company.local",
      "web-server-02.company.local",
      "app-server-01.company.local"
    ]
  },
  {
    "NetworkZone": "azure.westeurope.prod",
    "ActiveGate": "https://activegate-weu.company.local:9999/communication",
    "Servers": [
      "web-server-03.company.local",
      "app-server-02.company.local"
    ]
  }
]
```

## Best Practices

### Network Zone Design

1. **Regional Segmentation**: Create network zones per Azure region for optimal routing
2. **Naming Convention**: Use consistent naming (e.g., `cloud.region.environment`)
3. **ActiveGate Placement**: Deploy ActiveGates in each network zone
4. **Fallback Configuration**: Configure fallback zones for high availability

### OneAgent Deployment

1. **Staged Rollout**: Deploy to test servers first, then production
2. **Connectivity Testing**: Verify ActiveGate connectivity before mass deployment
3. **Version Management**: Use latest stable OneAgent version
4. **Monitoring**: Track deployment success rates and agent health

### Metric Events

1. **Threshold Tuning**: Start conservative, adjust based on actual data
2. **Multi-Level Alerts**: Use Warning → Error → Critical progression
3. **Entity Filtering**: Use tags to scope alerts appropriately
4. **Alert Fatigue**: Avoid over-alerting with proper thresholds

### API Token Management

1. **Least Privilege**: Grant only required permissions
2. **Rotation**: Rotate tokens regularly
3. **Secure Storage**: Use Azure Key Vault or similar for token storage
4. **Audit**: Log all API operations for compliance

## Troubleshooting

### OneAgent Installation Fails

**Symptoms:** Installation returns non-zero exit code

**Solutions:**
1. Verify MSI path is accessible from target server
2. Check PowerShell Remoting is enabled
3. Ensure local admin rights on target server
4. Verify ActiveGate URL is reachable from target server

```powershell
# Test connectivity to ActiveGate
Test-NetConnection -ComputerName "activegate-eus2.company.local" -Port 9999
```

### Network Zone Not Appearing

**Symptoms:** Network zone created but not visible in UI

**Solutions:**
1. Verify API token has `networkZones.write` permission
2. Check for API error messages in script output
3. Confirm zone name follows naming conventions (no spaces, special chars)
4. Wait 1-2 minutes for UI refresh

### Metric Events Not Triggering

**Symptoms:** Metric event created but no alerts generated

**Solutions:**
1. Verify metric selector syntax is correct
2. Check entity tags match filter criteria
3. Ensure threshold is appropriate for metric values
4. Confirm `violatingSamples` and `samples` configuration

```powershell
# Test metric selector in Dynatrace UI
# Data Explorer → Metrics → Enter metric selector
builtin:host.disk.usedPct:filter(in("dt.entity.host",entitySelector("type(HOST),tag(~\"[Azure]Environment:Production~\")")))
```

## Integration with CI/CD

### Azure DevOps Pipeline Example

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - infrastructure/*

variables:
  dynatraceToken: $(DYNATRACE_API_TOKEN)
  dynatraceTenant: 'https://abc12345.live.dynatrace.com'

stages:
  - stage: DeployMonitoring
    jobs:
      - job: CreateNetworkZones
        steps:
          - task: PowerShell@2
            inputs:
              filePath: 'observability/dynatrace/api-examples/Create-NetworkZones.ps1'
              arguments: '-ApiToken $(dynatraceToken) -TenantUrl $(dynatraceTenant)'
            displayName: 'Create Network Zones'
      
      - job: DeployOneAgent
        dependsOn: CreateNetworkZones
        steps:
          - task: PowerShell@2
            inputs:
              filePath: 'observability/dynatrace/deployment/Install-OneAgent-Regional.ps1'
              arguments: '-MsiPath "$(Build.SourcesDirectory)/installers/Dynatrace-OneAgent.msi"'
            displayName: 'Deploy OneAgent'
```

## API Reference

### Network Zones API

**Endpoint:** `GET/PUT/DELETE /api/v2/networkZones/{id}`

**Create Network Zone:**
```powershell
$headers = @{
    "Authorization" = "Api-Token $token"
    "Content-Type" = "application/json"
}

$body = @{
    description = "Production Zone - East US 2"
    enabled = $true
} | ConvertTo-Json

Invoke-RestMethod -Uri "$tenant/api/v2/networkZones/azure.eastus2.prod" `
    -Method Put -Headers $headers -Body $body
```

### Settings API (Metric Events)

**Endpoint:** `POST /api/v2/settings/objects`

**Create Metric Event:**
```powershell
$payload = @{
    schemaId = "builtin:anomaly-detection.metric-events"
    scope = "environment"
    value = @{
        enabled = $true
        summary = "Disk Space Warning 85%"
        queryDefinition = @{
            type = "METRIC_SELECTOR"
            metricSelector = "builtin:host.disk.usedPct"
        }
        modelProperties = @{
            type = "STATIC_THRESHOLD"
            threshold = 85.0
            alertCondition = "ABOVE"
        }
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "$tenant/api/v2/settings/objects" `
    -Method Post -Headers $headers -Body $payload
```

## Docker Integration

For containerized applications, see the comprehensive Docker integration guide:

📄 **[Dynatrace OneAgent Docker Integration Guide](./docker/Dynatrace-OneAgent-Docker-Integration.md)**

This guide covers:
- Direct API-based OneAgent installation in containers
- Troubleshooting common Docker integration issues
- Best practices for container monitoring
- Complete Dockerfile examples with validation steps

## Additional Resources

- [Dynatrace API Documentation](https://www.dynatrace.com/support/help/dynatrace-api)
- [Network Zones Documentation](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-activegate/network-zones)
- [OneAgent Deployment Guide](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-oneagent)
- [Metric Events Documentation](https://www.dynatrace.com/support/help/how-to-use-dynatrace/problem-detection-and-analysis/problem-detection/metric-events-for-alerting)
- [Docker OneAgent Integration](./docker/Dynatrace-OneAgent-Docker-Integration.md) *(Local Guide)*

## License

See LICENSE file in repository root.
