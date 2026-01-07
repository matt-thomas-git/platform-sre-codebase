# KQL (Kusto Query Language) Queries for Azure Monitor

Production-ready KQL queries for monitoring Azure infrastructure, SQL Server operations, backups, and security compliance using Azure Monitor Log Analytics.

## 📊 Overview

This collection contains **4 comprehensive KQL query files** with **30+ individual queries** covering critical operational monitoring scenarios. All queries are production-tested and designed for real-world SRE/Platform engineering use cases.

## 📁 Query Files

### 1. **disk-space-monitoring.kql** - Disk Space Monitoring
Monitor disk space usage across Windows VMs with proactive alerting and capacity planning.

**Queries Included:**
- Current disk space status (last 5 minutes)
- Disk space trend analysis (24 hours)
- Critical disk space alerts (< 10% free)
- Disk space growth rate prediction
- Environment-based disk space summary

**Use Cases:**
- Prevent disk full incidents
- Capacity planning
- Proactive alerting
- Environment-based reporting

**Key Features:**
- ✅ Real-time monitoring
- ✅ Predictive analytics (days until full)
- ✅ Environment tagging (PROD/UAT/DEV)
- ✅ Multi-threshold alerting

---

### 2. **backup-failures.kql** - Azure Backup Monitoring
Monitor Azure Backup jobs across Recovery Services Vaults with SLA compliance tracking.

**Queries Included:**
- Recent backup failures (24 hours)
- Backup success rate by resource (7 days)
- Long-running backup jobs
- Missing backups detection
- Storage consumption trends
- Failure analysis by error code
- SLA compliance reporting

**Use Cases:**
- Ensure backup SLAs are met
- Identify backup failures quickly
- Track storage consumption
- Compliance reporting

**Key Features:**
- ✅ SLA compliance tracking
- ✅ Error code analysis
- ✅ Storage trend monitoring
- ✅ Missing backup detection

---

### 3. **sql-agent-failures.kql** - SQL Server Agent Job Monitoring
Monitor SQL Server Agent jobs, failures, and performance issues via Windows Event Logs.

**Queries Included:**
- SQL Agent job failures (24 hours)
- Failed jobs summary (7 days)
- Long-running jobs detection
- Step-level failure analysis
- SQL Agent service restarts
- Success/failure rate analysis
- Overdue jobs detection
- SQL Agent alerts

**Use Cases:**
- Monitor ETL processes
- Detect job failures
- Performance monitoring
- Service availability tracking

**Key Features:**
- ✅ Job-level and step-level monitoring
- ✅ Success rate tracking
- ✅ Duration analysis
- ✅ Service health monitoring

---

### 4. **cert-expiry.kql** - Certificate Expiry Monitoring
Monitor SSL/TLS certificate expiration across web servers and applications.

**Queries Included:**
- Certificates expiring soon (30 days)
- Expired certificates
- Certificate summary by server
- Certificates by issuer
- Self-signed certificate detection
- Certificate renewal tracking
- Monthly expiry forecast
- Wildcard certificate inventory
- Monitoring gap detection
- Certificate chain issues

**Use Cases:**
- Prevent service outages
- Security compliance
- Certificate lifecycle management
- Capacity planning

**Key Features:**
- ✅ Multi-threshold alerting (7/14/30 days)
- ✅ Self-signed certificate detection
- ✅ Renewal tracking
- ✅ Wildcard certificate management

---

## 🚀 Quick Start

### Prerequisites
- Azure Monitor Log Analytics workspace
- Windows VMs with Log Analytics agent installed
- Appropriate data sources configured:
  - Performance counters (for disk monitoring)
  - Windows Event Logs (for SQL Agent monitoring)
  - Azure Diagnostics (for backup monitoring)
  - Custom logs (for certificate monitoring)

### Using the Queries

1. **Open Azure Portal:**
   - Navigate to Log Analytics workspace
   - Click "Logs" in the left menu

2. **Copy and paste a query:**
   - Open one of the .kql files
   - Copy the desired query
   - Paste into the query editor

3. **Adjust time ranges as needed:**
   ```kql
   | where TimeGenerated > ago(24h)  // Change to ago(7d), ago(1h), etc.
   ```

4. **Run the query:**
   - Click "Run" or press Shift+Enter
   - View results in table or chart format

### Creating Alerts

Convert any query into an alert:

1. Run the query in Log Analytics
2. Click "New alert rule"
3. Configure:
   - **Condition:** Result count > 0
   - **Evaluation frequency:** Every 5 minutes
   - **Action group:** Email, SMS, webhook, etc.

**Example Alert Scenarios:**
- Disk space < 10% free
- Backup failures in last 24 hours
- SQL Agent job failures
- Certificates expiring in < 7 days

---

## 📈 Query Patterns Demonstrated

### 1. Time-Based Filtering
```kql
| where TimeGenerated > ago(24h)
```

### 2. Aggregation and Summarization
```kql
| summarize FailureCount = count(), LastFailure = max(TimeGenerated) by JobName
```

### 3. Conditional Logic
```kql
| extend Status = case(
    AvgFreeSpace < 10, "Critical",
    AvgFreeSpace < 20, "Warning",
    "Healthy"
)
```

### 4. Joins (Left Anti-Join for Missing Data)
```kql
ExpectedBackups
| join kind=leftanti RecentBackups on BackupItemUniqueId_s
```

### 5. Regular Expression Extraction
```kql
| extend JobName = extract(@"Job '([^']+)'", 1, RenderedDescription)
```

### 6. Predictive Analytics
```kql
| extend DaysUntilFull = CurrentFreeSpace / abs(AvgDailyChange)
```

### 7. Time Binning
```kql
| summarize AvgFreeSpace = avg(CounterValue) by bin(TimeGenerated, 1h)
```

---

## 🎯 Real-World Use Cases

### Scenario 1: Proactive Disk Space Management
**Problem:** Servers running out of disk space causing service outages.

**Solution:** Use `disk-space-monitoring.kql` Query 4 (Growth Rate Prediction)
- Predicts when disks will be full
- Alerts 30 days in advance
- Enables proactive capacity planning

### Scenario 2: Backup SLA Compliance
**Problem:** Need to ensure all VMs are backed up daily for compliance.

**Solution:** Use `backup-failures.kql` Query 7 (SLA Compliance)
- Identifies resources without recent backups
- Tracks compliance status
- Generates compliance reports

### Scenario 3: ETL Job Monitoring
**Problem:** Critical ETL jobs failing overnight without notification.

**Solution:** Use `sql-agent-failures.kql` Query 2 (Failed Jobs Summary)
- Identifies frequently failing jobs
- Tracks failure patterns
- Enables proactive remediation

### Scenario 4: Certificate Lifecycle Management
**Problem:** SSL certificates expiring causing website outages.

**Solution:** Use `cert-expiry.kql` Query 1 (Expiring Soon)
- 30-day advance warning
- Multi-threshold alerting (7/14/30 days)
- Prevents service disruptions

---

## 📊 Sample Dashboards

### Dashboard 1: Infrastructure Health
Combine queries for a comprehensive view:
- Disk space status (all servers)
- Backup success rate (last 7 days)
- Certificate expiry summary
- SQL Agent job health

### Dashboard 2: Capacity Planning
Focus on trends and predictions:
- Disk space growth rate
- Backup storage consumption
- Certificate expiry forecast
- Long-running job trends

### Dashboard 3: Compliance Reporting
Track SLA and compliance metrics:
- Backup SLA compliance
- Expired certificates
- Self-signed certificates
- Missing backups

---

## 🔧 Customization Tips

### Adjust Thresholds
```kql
// Change disk space warning threshold from 20% to 15%
| where AvgFreeSpace < 15  // Was 20
```

### Filter by Environment
```kql
// Only show production servers
| where Computer startswith "PROD"
```

### Change Time Windows
```kql
// Extend from 24h to 7 days
| where TimeGenerated > ago(7d)  // Was ago(24h)
```

### Add Custom Tags
```kql
// Add application tags
| extend Application = case(
    Computer contains "SQL", "Database",
    Computer contains "WEB", "Web Server",
    Computer contains "APP", "Application",
    "Other"
)
```

---

## 📚 KQL Learning Resources

### Key Concepts Demonstrated
1. **Filtering:** `where`, `in`, `contains`, `startswith`
2. **Aggregation:** `summarize`, `count`, `avg`, `max`, `min`
3. **Transformation:** `extend`, `project`, `distinct`
4. **Joins:** `join kind=leftouter`, `join kind=leftanti`
5. **Time Functions:** `ago()`, `bin()`, `datetime_diff()`
6. **String Functions:** `extract()`, `split()`, `strcat()`
7. **Conditional Logic:** `case()`, `iff()`, `coalesce()`
8. **Advanced:** `serialize`, `prev()`, `make_set()`

### Official Documentation
- [KQL Quick Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kql-quick-reference)
- [Azure Monitor Query Language](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-query-overview)
- [KQL Best Practices](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/best-practices)

---

## 🎓 Skills Demonstrated

These KQL queries showcase:
- ✅ **Production Monitoring:** Real-world operational scenarios
- ✅ **Proactive Alerting:** Predictive analytics and early warning
- ✅ **Data Analysis:** Aggregation, trending, and pattern detection
- ✅ **SLA Management:** Compliance tracking and reporting
- ✅ **Security Monitoring:** Certificate and compliance tracking
- ✅ **Performance Optimization:** Efficient query design
- ✅ **Documentation:** Clear comments and use case descriptions

---

## 🔐 Security Considerations

### Data Access
- Queries require Log Analytics Reader role minimum
- Sensitive data should be masked or excluded
- Use Azure RBAC for access control

### Query Performance
- Use time filters to limit data scanned
- Avoid `search *` - use specific tables
- Test queries on small time windows first

### Alert Fatigue
- Set appropriate thresholds
- Use action groups wisely
- Implement alert suppression for known issues

---

## 📝 Contributing

When adding new queries:
1. Include clear comments explaining the use case
2. Add example output or expected results
3. Document any prerequisites (custom tables, etc.)
4. Test queries on production-like data
5. Include threshold recommendations

---

## 🎯 Next Steps

1. **Import queries** into your Log Analytics workspace
2. **Create alerts** for critical scenarios
3. **Build dashboards** combining multiple queries
4. **Customize thresholds** for your environment
5. **Schedule reports** for compliance tracking

---

**Note:** These queries assume standard Azure Monitor table schemas. Custom log tables (like `CertificateInventory_CL`) require custom data collection scripts. See the `automation/` folder for PowerShell scripts that populate these custom tables.
