# GitHub Actions CI/CD Examples

This folder contains GitHub Actions workflow examples converted from Azure DevOps Pipelines to demonstrate cross-platform CI/CD knowledge and adaptability.

---

## 📁 Contents

- **windows-update-workflow.yml** - Windows Server patching automation with Dynatrace integration

---

## 🔄 Azure DevOps vs GitHub Actions

### Key Differences

| Aspect | Azure DevOps | GitHub Actions |
|--------|--------------|----------------|
| **File Location** | Any path, referenced in pipeline | `.github/workflows/` directory |
| **Syntax** | `stages` → `jobs` → `steps` | `jobs` → `steps` |
| **Triggers** | `trigger:`, `schedules:`, `pr:` | `on:`, `workflow_dispatch:`, `schedule:` |
| **Parameters** | `parameters:` with types | `workflow_dispatch.inputs:` |
| **Variables** | `variables:` section | `env:` section |
| **Secrets** | `$(SecretName)` | `${{ secrets.SECRET_NAME }}` |
| **Expressions** | `${{ }}` | `${{ }}` (same syntax!) |
| **Runners** | `pool: vmImage` | `runs-on:` |
| **Dependencies** | `dependsOn:` | `needs:` |
| **Artifacts** | `PublishBuildArtifacts` task | `actions/upload-artifact` |
| **Conditions** | `condition:` | `if:` |

---

## 🎯 Why Both Platforms?

**Demonstrates:**
- ✅ Platform-agnostic CI/CD knowledge
- ✅ Ability to adapt to different tooling
- ✅ Understanding of CI/CD concepts, not just syntax
- ✅ Flexibility for organizations using either platform

**Real-World Value:**
- Many organizations use Azure DevOps for enterprise projects
- GitHub Actions is popular for open-source and modern cloud-native projects
- Knowing both makes you more versatile as a Platform/SRE engineer

---

## 📊 Syntax Comparison Examples

### Triggers

**Azure DevOps:**
```yaml
trigger: none

schedules:
- cron: "0 2 * * 2"
  displayName: Monthly Patch Tuesday
  branches:
    include:
    - main
```

**GitHub Actions:**
```yaml
on:
  workflow_dispatch:
  
  schedule:
    - cron: '0 2 * * 2'
```

---

### Parameters/Inputs

**Azure DevOps:**
```yaml
parameters:
- name: environment
  displayName: Environment
  type: string
  default: 'Dev'
  values:
  - Dev
  - UAT
  - Production
```

**GitHub Actions:**
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to update'
        required: true
        type: choice
        options:
          - Dev
          - UAT
          - Production
        default: 'Dev'
```

---

### Jobs and Dependencies

**Azure DevOps:**
```yaml
stages:
- stage: PreChecks
  jobs:
  - job: ValidateServers
    steps:
    - task: PowerShell@2

- stage: MaintenanceWindow
  dependsOn: PreChecks
  jobs:
  - job: CreateSDT
```

**GitHub Actions:**
```yaml
jobs:
  pre-checks:
    runs-on: windows-latest
    steps:
      - name: Validate Servers
        shell: pwsh
  
  create-maintenance-window:
    runs-on: windows-latest
    needs: pre-checks
```

---

### Secrets and Variables

**Azure DevOps:**
```yaml
variables:
  - name: dynatraceUrl
    value: 'https://YOUR-TENANT.live.dynatrace.com'

steps:
- task: PowerShell@2
  env:
    DYNATRACE_TOKEN: $(DynatraceApiToken)
```

**GitHub Actions:**
```yaml
env:
  DYNATRACE_URL: 'https://YOUR-TENANT.live.dynatrace.com'

steps:
  - name: Create Maintenance Window
    env:
      DYNATRACE_TOKEN: ${{ secrets.DYNATRACE_API_TOKEN }}
```

---

### Artifacts

**Azure DevOps:**
```yaml
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)'
    ArtifactName: 'drop'
```

**GitHub Actions:**
```yaml
- name: Upload Artifacts
  uses: actions/upload-artifact@v4
  with:
    name: update-logs
    path: |
      *.log
      **/WindowsUpdate*.log
    retention-days: 30
```

---

### Conditional Execution

**Azure DevOps:**
```yaml
- task: PowerShell@2
  displayName: 'Cleanup'
  condition: always()
```

**GitHub Actions:**
```yaml
- name: Cleanup
  if: always()
  shell: pwsh
```

---

## 🚀 GitHub Actions Advantages

### 1. **Marketplace Actions**
Reusable actions from the community:
```yaml
- uses: actions/checkout@v4
- uses: actions/upload-artifact@v4
- uses: azure/login@v1
```

### 2. **Job Outputs**
Easy data passing between jobs:
```yaml
jobs:
  job1:
    outputs:
      server-count: ${{ steps.load-servers.outputs.count }}
  
  job2:
    needs: job1
    steps:
      - run: echo "Count: ${{ needs.job1.outputs.server-count }}"
```

### 3. **Matrix Builds**
Test across multiple configurations:
```yaml
strategy:
  matrix:
    os: [windows-latest, ubuntu-latest]
    environment: [Dev, UAT, Prod]
```

### 4. **GitHub Step Summary**
Built-in markdown summaries:
```yaml
- run: |
    echo "# Report" >> $GITHUB_STEP_SUMMARY
    echo "- Status: Success" >> $GITHUB_STEP_SUMMARY
```

---

## 🔧 Azure DevOps Advantages

### 1. **Stages**
Better visualization of deployment stages:
```yaml
stages:
- stage: Build
- stage: Test
- stage: Deploy
```

### 2. **Environments**
Built-in approval gates:
```yaml
- deployment: DeployProduction
  environment: Production
```

### 3. **Service Connections**
Managed Azure/AWS credentials

### 4. **Release Pipelines**
Separate build and release workflows with approvals

---

## 📝 Conversion Checklist

When converting Azure DevOps → GitHub Actions:

- [ ] Move file to `.github/workflows/` directory
- [ ] Change `trigger:` to `on:`
- [ ] Convert `parameters:` to `workflow_dispatch.inputs:`
- [ ] Change `variables:` to `env:`
- [ ] Replace `stages:` with `jobs:` (flatten structure)
- [ ] Change `dependsOn:` to `needs:`
- [ ] Update `pool: vmImage` to `runs-on:`
- [ ] Convert `task:` to `uses:` or `run:`
- [ ] Update secret syntax: `$(Secret)` → `${{ secrets.SECRET }}`
- [ ] Change `condition:` to `if:`
- [ ] Update artifact tasks to use `actions/upload-artifact`
- [ ] Test with `workflow_dispatch` before enabling schedules

---

## 🎓 Learning Resources

### GitHub Actions
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)

### Azure DevOps
- [Azure Pipelines Documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/)
- [YAML Schema Reference](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)

### Migration Guides
- [Migrating from Azure Pipelines to GitHub Actions](https://docs.github.com/en/actions/migrating-to-github-actions/migrating-from-azure-pipelines-to-github-actions)

---

## 💡 Best Practices (Both Platforms)

### 1. **Use Secrets for Credentials**
Never hard-code credentials in workflows

### 2. **Pin Action/Task Versions**
```yaml
# Good
uses: actions/checkout@v4

# Better (for security)
uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
```

### 3. **Implement Approval Gates**
For production deployments

### 4. **Use Artifacts for Logs**
Retain important logs and reports

### 5. **Set Timeouts**
Prevent runaway jobs:
```yaml
timeout-minutes: 120
```

### 6. **Use Conditions Wisely**
```yaml
if: always()  # Run even if previous steps failed
if: success() # Only run if previous steps succeeded
if: failure() # Only run if previous steps failed
```

---

## 🔍 Interview Talking Points

**When discussing this conversion:**

1. **Platform Agnostic:** "I understand CI/CD concepts, not just specific tools"
2. **Adaptability:** "I can work with Azure DevOps, GitHub Actions, GitLab CI, or Jenkins"
3. **Best Practices:** "I apply the same principles regardless of platform - idempotency, error handling, logging"
4. **Real Experience:** "I've worked with Azure DevOps in production and converted pipelines to GitHub Actions"

---

## 📂 File Structure

```
cicd-pipelines/
├── README.md
├── github-actions/              ← GitHub Actions examples
│   ├── README.md               ← This file
│   └── windows-update-workflow.yml
├── server-maint-pipeline/       ← Azure DevOps examples
├── sql-permissions-pipeline/
└── windows-updates-pipeline/
```

---

## 🎯 Next Steps

**To use these workflows:**

1. **For GitHub Actions:**
   - Copy workflow to `.github/workflows/` in your repository
   - Configure secrets in repository settings
   - Trigger via Actions tab or schedule

2. **For Azure DevOps:**
   - Use existing pipelines in their current locations
   - Configure variable groups for secrets
   - Trigger via Pipelines UI or schedule

---

**Note:** Both platforms are production-ready. The choice depends on your organization's tooling, licensing, and integration requirements. This portfolio demonstrates proficiency in both.