# Repository Sanity Check - Issues Found

Comprehensive audit of the platform-sre-codebase repository.

**Date:** 2026-01-07  
**Status:** 🔴 Issues Found - Needs Cleanup

---

## 🔴 CRITICAL ISSUES

### 1. **Duplicate Files with Same Name** ✅ RESOLVED
**Files:** `Monitor-AzureADSecretExpirations.ps1` (2 copies)

**Problem:**
- Two different files with the same name in different locations
- Caused confusion about which version to use

**Resolution:**
Files were compared and found to be COMPLETELY DIFFERENT scripts:
- **File 1:** Microsoft Graph SDK version (general purpose)
  - **Old:** `automation/powershell/scripts/examples/Monitor-AzureADSecretExpirations.ps1`
  - **New:** `automation/powershell/scripts/examples/Monitor-AzureADSecretExpirations-GraphSDK.ps1`
  
- **File 2:** Azure Automation Runbook with Dynatrace integration
  - **Old:** `observability/dynatrace/azure-runbooks/Monitor-AzureADSecretExpirations.ps1`
  - **New:** `observability/dynatrace/azure-runbooks/Monitor-AzureADSecretExpirations-DynatraceRunbook.ps1`

**Fix Applied:**
- [x] Renamed both files with descriptive suffixes
- [x] Updated README.md references
- [x] Updated AUTH-MODES.md references
- [x] Updated CHANGELOG.md references
- [x] Updated observability/dynatrace/README.md
- [x] Both versions kept - they serve different purposes

---

## 🟡 STRUCTURAL INCONSISTENCIES

### 2. **Terraform Modules - Backup Module** ✅ VERIFIED COMPLETE
**Location:** `terraform/modules/backup/`

**Status:** Module is complete with all required files:
- [x] main.tf exists
- [x] variables.tf exists
- [x] outputs.tf exists

**No action needed** - This was a false alarm from initial scan

---

### 3. **Empty/Stub Environment Folders**
**Locations:**
- `terraform/envs/stage/` - Empty folder
- `terraform/envs/uat/` - Only has README.md

**Problem:**
- Inconsistent with `dev/` which has full terraform files
- Creates confusion about what's implemented

**Fix Needed:**
- [ ] Either populate stage/ and uat/ with terraform files
- [ ] OR add README.md explaining they're placeholders
- [ ] OR remove if not needed for portfolio

---

### 4. **Missing PowerShell Module Manifest**
**Location:** `automation/powershell/Module/`

**Problem:**
- Has `PlatformOps.Automation.psm1` (module file)
- Missing `PlatformOps.Automation.psd1` (manifest file)
- Manifest is standard practice for PowerShell modules

**Fix Needed:**
- [ ] Create PlatformOps.Automation.psd1 manifest file
- [ ] Include version, author, description, exported functions

---

### 5. **Empty Folders Referenced in Structure**
**Locations:**
- `automation/powershell/scripts/migration/` - Empty
- `automation/python/config/` - Empty
- `observability/dynatrace/api-examples/config-examples/` - Empty
- `terraform/modules/network/` - May be incomplete

**Fix Needed:**
- [ ] Add placeholder README.md files explaining purpose
- [ ] OR add example files
- [ ] OR remove if not needed

---

## 🟢 DOCUMENTATION INCONSISTENCIES

### 6. **README.md File Structure Mismatch**
**Location:** `platform-sre-codebase/README.md`

**Problem:**
- Shows file structure that doesn't match actual repository
- References files in wrong locations
- May confuse users trying to navigate

**Fix Needed:**
- [ ] Update README.md file tree to match actual structure
- [ ] Verify all file paths are correct
- [ ] Remove references to non-existent files

---

### 7. **Missing README Files**
**Locations Missing README:**
- `automation/azure-runbooks/` - No README
- `cicd-pipelines/server-maint-pipeline/` - No README
- `cicd-pipelines/sql-permissions-pipeline/` - No README
- `runbooks/azure/` - No README
- `runbooks/sql/` - No README
- `security-compliance/` - No README
- `terraform/envs/stage/` - No README

**Fix Needed:**
- [ ] Add README.md to each major folder
- [ ] Explain purpose and contents
- [ ] Provide usage examples

---

### 8. **Dynatrace Folder Structure Confusion**
**Location:** `observability/dynatrace/`

**Problem:**
- Has `azure-runbooks/` subfolder (empty?)
- Has `deployment/` subfolder
- Has `api-examples/` subfolder
- Unclear organization - some overlap with `automation/azure-runbooks/`

**Fix Needed:**
- [ ] Clarify folder purpose in README
- [ ] Consolidate if there's duplication
- [ ] Ensure files are in logical locations

---

## 🔵 MINOR ISSUES

### 9. **Inconsistent Naming Conventions**
**Examples:**
- `Server-Maintenance-Pipeline.ps1` (PascalCase with hyphens)
- `sql-permissions-pipeline.yml` (lowercase with hyphens)
- `DynatraceSDT.ps1` (PascalCase no hyphens)
- `health_probe.py` (snake_case)

**Fix Needed:**
- [ ] Document naming conventions in CONTRIBUTING.md
- [ ] Standardize where possible (PowerShell = PascalCase, Python = snake_case, YAML = kebab-case)

---

### 10. **Missing .gitignore Entries**
**Location:** `.gitignore`

**Potential Missing Entries:**
- Terraform state files (*.tfstate, *.tfstate.backup)
- Terraform lock files (.terraform.lock.hcl)
- Python cache (__pycache__, *.pyc)
- PowerShell test results
- VS Code settings (.vscode/)

**Fix Needed:**
- [ ] Review and update .gitignore
- [ ] Add common exclusions for Terraform, Python, PowerShell

---

### 11. **Terraform Modules - Missing README**
**Location:** `terraform/modules/backup/`

**Problem:**
- Module exists but no README explaining:
  - What it does
  - Required variables
  - Example usage

**Fix Needed:**
- [ ] Add README.md to backup module
- [ ] Document inputs, outputs, usage

---

### 12. **Python Scripts Missing Requirements**
**Location:** `automation/python/`

**Problem:**
- Has `requirements.txt` but may be incomplete
- `sql_permissions_manager.py` may have dependencies not listed

**Fix Needed:**
- [ ] Verify all Python dependencies are in requirements.txt
- [ ] Add version pinning for reproducibility

---

## 📊 SUMMARY

### Issues by Priority

| Priority | Count | Category |
|----------|-------|----------|
| 🔴 Critical | 1 | Missing/misplaced files |
| 🟡 High | 4 | Structural inconsistencies |
| 🟢 Medium | 4 | Documentation gaps |
| 🔵 Low | 4 | Minor improvements |
| **TOTAL** | **13** | **Issues Found** |

---

## 🎯 RECOMMENDED FIX ORDER

### Phase 1: Critical (Do First)
1. Fix Monitor-AzureADSecretExpirations.ps1 location/references
2. Complete or remove incomplete terraform modules

### Phase 2: High Priority
3. Add README files to major folders
4. Populate or remove empty environment folders
5. Create PowerShell module manifest

### Phase 3: Medium Priority
6. Update main README.md file structure
7. Clarify Dynatrace folder organization
8. Add placeholder files to empty folders

### Phase 4: Low Priority (Polish)
9. Standardize naming conventions
10. Update .gitignore
11. Verify Python requirements.txt
12. Add module-specific READMEs

---

## 🔧 QUICK WINS (Easy Fixes)

These can be done quickly:
- [ ] Add README.md files to empty folders
- [ ] Update .gitignore
- [ ] Fix file path references in main README
- [ ] Remove empty folders that aren't needed

---

## ✅ WHAT'S WORKING WELL

**Good Structure:**
- ✅ Clear separation of automation, terraform, observability
- ✅ Good documentation in docs/ folder
- ✅ Comprehensive CHANGELOG.md
- ✅ Security scrub checklist is thorough
- ✅ PowerShell module structure is solid
- ✅ CI/CD pipelines are well organized

**Good Documentation:**
- ✅ CONTRIBUTING.md exists
- ✅ LICENSE file present
- ✅ Multiple detailed docs in docs/ folder
- ✅ KQL queries are documented

---

## 📝 NOTES

- This is a portfolio repository, so some "incomplete" items may be intentional examples
- Focus on fixing references and documentation first
- Structural issues can be addressed based on what you want to showcase
- Consider what a hiring manager would notice first

---

**Next Steps:** Review this list and decide which issues to tackle first. I can help fix them one at a time!
