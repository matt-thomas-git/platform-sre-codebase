# Windows Updates Automation

Automated Windows Update orchestration with Dynatrace integration for scheduled maintenance windows.

## Structure

```
WindowsUpdates/
├── README.md (this file)
├── WinUpdateLibrary.ps1          # Core update installation logic
├── PreSteps.ps1                  # Pre-update validation
├── PostSteps.ps1                 # Post-update health checks
├── DynatraceSDT.ps1              # Dynatrace maintenance window management
├── Pipelines/
│   └── windows-update-pipeline.yml  # Azure DevOps pipeline
└── Servers/
    ├── DevServers.ps1            # Development server list
    ├── UATServers.ps1            # UAT server list
    └── ProductionServers.ps1     # Production server list
```

## Features

- **Multi-Environment Support**: Dev, UAT, Production
- **Dynatrace Integration**: Automatic maintenance window creation
- **Pre/Post Validation**: Health checks before and after updates
- **Flexible Scheduling**: Cron-based scheduling for Patch Tuesday
- **Reboot Management**: Configurable reboot behavior
- **Category Filtering**: Install specific update categories

## Usage

### Manual Execution

```powershell
# Run updates on Dev servers
.\WinUpdateLibrary.ps1 -Environment Dev -Categories "CriticalUpdates,SecurityUpdates" -Reboot

# Pre-checks only
.\PreSteps.ps1 -Environment UAT

# Post-validation
.\PostSteps.ps1 -Environment Production
```

### Pipeline Execution

The pipeline is configured to run:
- **Schedule**: Every Tuesday at 2 AM (Patch Tuesday)
- **Manual Trigger**: Available with environment selection
- **Parameters**:
  - Environment (Dev/UAT/Production)
  - Update Categories
  - Reboot if Required

## Pipeline Stages

1. **PreChecks**: Validate server connectivity and readiness
2. **MaintenanceWindow**: Create Dynatrace scheduled downtime
3. **WindowsUpdates**: Install updates on target servers
4. **PostChecks**: Validate server health and close maintenance window
5. **Reporting**: Generate update summary

## Server Lists

Server lists are PowerShell scripts that return arrays of server names:

```powershell
# Example: DevServers.ps1
@(
    "SERVER-DEV-01",
    "SERVER-DEV-02",
    "SERVER-DEV-03"
)
```

## Dynatrace Integration

The `DynatraceSDT.ps1` script manages maintenance windows:

```powershell
# Create maintenance window
.\DynatraceSDT.ps1 -Action Create -Environment Production -DurationMinutes 180

# Close maintenance window
.\DynatraceSDT.ps1 -Action Close -Environment Production
```

## Requirements

- **PowerShell Modules**: PSWindowsUpdate
- **Permissions**: Local admin on target servers
- **Dynatrace**: API token with maintenance window permissions
- **Azure DevOps**: Variable group with DynatraceApiToken

## Configuration

Set these variables in Azure DevOps:
- `DynatraceApiToken`: API token for Dynatrace
- `dynatraceUrl`: Your Dynatrace tenant URL

## Best Practices

1. **Test in Dev First**: Always run updates in Dev before UAT/Production
2. **Maintenance Windows**: Ensure Dynatrace maintenance windows are active
3. **Backup Verification**: Confirm backups are current before updates
4. **Monitoring**: Watch for alerts during and after updates
5. **Rollback Plan**: Have a rollback strategy for critical servers
