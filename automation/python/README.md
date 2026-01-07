# Python Automation Scripts

Production-ready Python scripts for platform automation, health monitoring, and SQL Server management.

## 📁 Contents

### Scripts

1. **health_probe.py** - HTTP health check probe
   - Monitors web application availability
   - Configurable timeout and retry logic
   - JSON response validation
   - Exit codes for monitoring integration

2. **sql_permissions_manager.py** - SQL Server permissions automation
   - Configuration-driven permission management
   - Multi-server and multi-database support
   - Role-based access control (RBAC)
   - Audit logging with timestamps
   - Dry-run mode for safe testing

### Configuration

- **config/sql-permissions-config.json** - Sample SQL permissions configuration

## 🚀 Getting Started

### Prerequisites

```bash
# Python 3.7 or later
python --version

# Install dependencies
pip install -r requirements.txt
```

### Dependencies

- **requests** - HTTP library for health probes
- **pyodbc** - SQL Server connectivity
- **urllib3** - URL handling
- Standard library: json, logging, argparse, datetime, typing

## 📖 Usage Examples

### Health Probe

```bash
# Basic health check
python health_probe.py --url https://api.example.com/health

# With custom timeout and retries
python health_probe.py --url https://api.example.com/health --timeout 10 --retries 3

# Check specific endpoint with expected status
python health_probe.py --url https://api.example.com/status --expected-status 200
```

**Exit Codes:**
- `0` - Health check passed
- `1` - Health check failed
- `2` - Configuration error

### SQL Permissions Manager

```bash
# Preview changes (dry-run mode - default)
python sql_permissions_manager.py -c config/sql-permissions-config.json

# Apply permissions
python sql_permissions_manager.py -c config/sql-permissions-config.json --apply

# Apply with debug logging
python sql_permissions_manager.py -c config/sql-permissions-config.json --apply --log-level DEBUG
```

**Features:**
- ✅ Dry-run mode by default (safe testing)
- ✅ Comprehensive audit logging
- ✅ Multi-server support
- ✅ Role and permission grants
- ✅ Windows and SQL authentication
- ✅ Idempotent operations

## 🔧 SQL Permissions Configuration

### Configuration File Format

```json
{
  "servers": [
    {
      "name": "SQL-SERVER-01",
      "auth_type": "windows",
      "databases": [
        {
          "name": "AppDatabase",
          "permissions": [
            {
              "login": "DOMAIN\\AppServiceAccount",
              "user": "AppServiceAccount",
              "login_type": "windows",
              "roles": ["db_datareader", "db_datawriter"],
              "grants": [
                {
                  "permission": "EXECUTE",
                  "object": "dbo.uspGetCustomerData"
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

### Supported Roles

- `db_owner` - Full database permissions
- `db_datareader` - Read all data
- `db_datawriter` - Write all data
- `db_ddladmin` - DDL operations
- `db_securityadmin` - Security management
- `db_accessadmin` - User management
- `db_backupoperator` - Backup operations
- `db_denydatareader` - Deny read access
- `db_denydatawriter` - Deny write access

### Supported Permissions

- `SELECT` - Read data
- `INSERT` - Insert data
- `UPDATE` - Update data
- `DELETE` - Delete data
- `EXECUTE` - Execute stored procedures/functions
- `VIEW DEFINITION` - View object definitions
- `ALTER` - Modify objects
- `CONTROL` - Full control

## 📊 Output and Logging

### SQL Permissions Manager Output

**Console Output:**
```
================================================================================
SQL Server Permissions Manager
================================================================================
Mode: DRY-RUN (Preview Only)

--- Processing Server: SQL-SERVER-01 ---
✓ Connected to SQL-SERVER-01

  Database: AppDatabase
✓ Create user 'AppServiceAccount' in database 'AppDatabase'
✓ Add 'AppServiceAccount' to role 'db_datareader' in database 'AppDatabase'
✓ Add 'AppServiceAccount' to role 'db_datawriter' in database 'AppDatabase'
✓ Grant EXECUTE on dbo.uspGetCustomerData to 'AppServiceAccount' in 'AppDatabase'

================================================================================
SUMMARY
================================================================================
Successful operations: 4
Failed operations: 0

⚠ DRY-RUN MODE: No changes were applied
Run with --apply flag to apply changes
```

**Log Files:**
- `sql_permissions_YYYYMMDD_HHMMSS.log` - Detailed execution log
- `sql_permissions_audit_YYYYMMDD_HHMMSS.json` - Audit trail in JSON format

### Audit Log Format

```json
[
  {
    "timestamp": "2024-01-15T10:30:45.123456",
    "action": "Add 'AppUser' to role 'db_datareader' in database 'AppDB'",
    "sql": "USE [AppDB]; ALTER ROLE [db_datareader] ADD MEMBER [AppUser]",
    "status": "success"
  }
]
```

## 🔐 Security Best Practices

### Authentication

**Windows Authentication (Recommended):**
```json
{
  "name": "SQL-SERVER-01",
  "auth_type": "windows"
}
```

**SQL Authentication:**
```json
{
  "name": "SQL-SERVER-01",
  "auth_type": "sql",
  "username": "sa",
  "password": "SecurePassword123!"
}
```

⚠️ **Note:** Store credentials securely. Consider using:
- Environment variables
- Azure Key Vault
- Encrypted configuration files
- Windows Credential Manager

### Least Privilege

- Grant minimum required permissions
- Use roles instead of direct grants when possible
- Regularly audit permissions
- Remove unused accounts

### Audit Trail

- All operations are logged with timestamps
- Audit logs include SQL statements executed
- Success/failure status tracked
- Export audit logs for compliance

## 🧪 Testing

### Dry-Run Mode

Always test in dry-run mode first:

```bash
# Preview all changes
python sql_permissions_manager.py -c config.json

# Review the log file
cat sql_permissions_*.log

# Review what would be executed
grep "Would execute" sql_permissions_*.log
```

### Validation

```bash
# Validate configuration file
python -m json.tool config/sql-permissions-config.json

# Test with debug logging
python sql_permissions_manager.py -c config.json --log-level DEBUG
```

## 🔄 CI/CD Integration

### Azure DevOps Pipeline

```yaml
- task: UsePythonVersion@0
  inputs:
    versionSpec: '3.9'

- script: |
    pip install -r requirements.txt
  displayName: 'Install dependencies'

- script: |
    python sql_permissions_manager.py -c $(ConfigPath) --apply
  displayName: 'Apply SQL Permissions'
  env:
    SQL_PASSWORD: $(SqlPassword)
```

### GitHub Actions

```yaml
- name: Setup Python
  uses: actions/setup-python@v4
  with:
    python-version: '3.9'

- name: Install dependencies
  run: pip install -r requirements.txt

- name: Apply SQL Permissions
  run: python sql_permissions_manager.py -c config.json --apply
```

## 📝 Development

### Code Style

- Follow PEP 8 style guide
- Type hints for function signatures
- Comprehensive docstrings
- Error handling with try/except
- Logging instead of print statements

### Adding New Features

1. Update the `SQLPermissionsManager` class
2. Add corresponding configuration options
3. Update documentation
4. Add examples
5. Test in dry-run mode

## 🐛 Troubleshooting

### ODBC Driver Not Found

```bash
# Install ODBC Driver 17 for SQL Server
# Windows: Download from Microsoft
# Linux: 
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
apt-get update
apt-get install -y msodbcsql17
```

### Connection Failures

```bash
# Test connectivity
python -c "import pyodbc; print(pyodbc.drivers())"

# Check SQL Server is accessible
ping SQL-SERVER-01
telnet SQL-SERVER-01 1433
```

### Permission Denied

Ensure the account running the script has:
- `ALTER ANY LOGIN` permission (for creating logins)
- `ALTER ANY USER` permission (for creating users)
- `db_owner` role in target databases (for granting permissions)

## 📚 Additional Resources

- [pyodbc Documentation](https://github.com/mkleehammer/pyodbc/wiki)
- [SQL Server Permissions](https://docs.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)
- [Python Logging](https://docs.python.org/3/library/logging.html)
- [JSON Configuration](https://docs.python.org/3/library/json.html)

## 🤝 Contributing

When adding new scripts:
1. Follow existing code structure
2. Include comprehensive help text
3. Add configuration examples
4. Update this README
5. Test thoroughly in dry-run mode

## 📄 License

See main repository LICENSE file.
