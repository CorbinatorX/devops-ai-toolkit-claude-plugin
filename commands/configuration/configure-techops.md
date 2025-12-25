# /configure-techops

**Role:** TechOps Plugin Configuration Wizard

Interactive wizard to configure repo-specific TechOps context for use with Skills and commands.

## Usage

```bash
/configure-techops
```

**No arguments required** - The command will guide you through interactive prompts.

## Overview

This command configures repo-specific context that Skills and commands will use to customize their behavior. It prompts for project details, Azure DevOps configuration, and integration settings.

## Configuration File

**Output**: `.claude/techops-config.json` in the repository root

This file contains all repo-specific configuration and is referenced by:
- All Skills (blueprint, pickup-bug, pickup-feature, implement-task, review-task)
- Work item commands (create-techops-bug, create-incident, etc.)
- Documentation commands (create-post-mortem)

## Interactive Prompts

### Step 1: Project Information

```markdown
## Project Information

**Project/Product Name**: [e.g., "EthicsRM", "CRIS", "{Product} Portal"]
>

**Description**: [Brief description of what this project does]
>

**Contributor Name**: [Your full name for work item assignments]
>

**Owning Team**: [e.g., "TechOps", "Platform Team", "Product Development"]
>
```

### Step 2: Azure DevOps Configuration

```markdown
## Azure DevOps Configuration

**ADO Organization**: [e.g., "{organization}"]
>

**ADO Project**: [e.g., "{Organization} Platform", "ERM"]
>

**Area Path**: [e.g., "Platform\\TechOps", "ERM\\Devops"]
>

**Iteration Path**: [e.g., "Platform\\2026 Q1", "ERM\\dops-backlog"]
>
```

**Note**: Use double backslashes (`\\`) in paths - this is required by Azure DevOps MCP tools.

### Step 3: Confluence Configuration (Optional)

```markdown
## Confluence Configuration (Optional)

**Cloud ID**: [Atlassian Cloud ID, e.g., UUID or site URL]
>

**Space Key**: [e.g., "Tech", "DOCS", "ENG"]
>

**Post-Mortem Parent Page ID**: [Optional, page ID for incident post-mortems]
>
```

Press Enter to skip if not using Confluence.

### Step 4: Teams Integration (Optional)

```markdown
## Microsoft Teams Integration (Optional)

**Webhook URL**: [Teams incoming webhook URL]
>
```

Press Enter to skip if not using Teams notifications.

**Security Note**: Webhook URL is sensitive. Consider using environment variables or Azure Key Vault references instead of storing directly in config file.

### Step 5: Tech Stack (Optional)

```markdown
## Tech Stack (Optional)

**Frontend**: [e.g., "React 18 + TypeScript + Vite"]
>

**Backend**: [e.g., "FastAPI + Python 3.12"]
>

**Infrastructure**: [e.g., "Azure App Services + SQL Server + Redis"]
>

**CI/CD**: [e.g., "GitHub Actions"]
>
```

This information is used by the **blueprint** Skill for architecture design.

## Generated Configuration

After prompts complete, generates `.claude/techops-config.json`:

```json
{
  "version": "1.0",
  "project": {
    "name": "{Product} Portal",
    "description": "Multi-service application for ethics case management",
    "contributor": "Corbin Taylor",
    "owning_team": "TechOps"
  },
  "azure_devops": {
    "organization": "{organization}",
    "project": "{Organization} Platform",
    "area_path": "Platform\\\\TechOps",
    "iteration_path": "Platform\\\\2026 Q1"
  },
  "confluence": {
    "cloud_id": "12345678-1234-1234-1234-123456789abc",
    "space_key": "Tech",
    "postmortem_parent_page_id": "287244316"
  },
  "teams": {
    "webhook_url": "https://{organization}.webhook.office.com/webhookb2/..."
  },
  "tech_stack": {
    "frontend": "React 18 + TypeScript + Vite",
    "backend": "FastAPI + Python 3.12",
    "infrastructure": "Azure App Services + SQL Server + Redis",
    "cicd": "GitHub Actions"
  },
  "created_at": "2025-12-19T10:30:00Z",
  "created_by": "claude-code",
  "plugin_version": "0.1.0"
}
```

## Workflow

1. **Prompt user** for each configuration section
2. **Validate inputs**:
   - Area Path and Iteration Path contain double backslashes
   - Webhook URL is valid HTTPS URL (if provided)
   - Cloud ID is valid UUID or URL (if provided)
3. **Create `.claude/` directory** if it doesn't exist
4. **Write configuration file** to `.claude/techops-config.json`
5. **Display summary** of what was configured

## Usage by Skills and Commands

Skills and commands read this configuration to customize behavior:

### Example: pickup-bug Skill

```markdown
## Reading Configuration in pickup-bug

1. **Read config**:
   ```bash
   config=$(cat .claude/techops-config.json)
   ```

2. **Extract values**:
   ```bash
   PROJECT=$(echo "$config" | jq -r '.azure_devops.project')
   AREA_PATH=$(echo "$config" | jq -r '.azure_devops.area_path')
   CONTRIBUTOR=$(echo "$config" | jq -r '.project.contributor')
   ```

3. **Use in MCP tool calls**:
   - Project: `$PROJECT`
   - Area Path: `$AREA_PATH`
   - Assigned To: `$CONTRIBUTOR`

**Fallback**: If `.claude/techops-config.json` doesn't exist, Skills should prompt user to run `/configure-techops` first.
```

### Example: create-post-mortem Command

```markdown
## Reading Configuration in create-post-mortem

1. **Read Confluence config**:
   ```bash
   CLOUD_ID=$(jq -r '.confluence.cloud_id' .claude/techops-config.json)
   SPACE_KEY=$(jq -r '.confluence.space_key' .claude/techops-config.json)
   PARENT_PAGE_ID=$(jq -r '.confluence.postmortem_parent_page_id' .claude/techops-config.json)
   ```

2. **Use in Confluence page creation**:
   - Cloud ID: `$CLOUD_ID`
   - Space: `$SPACE_KEY`
   - Parent page: `$PARENT_PAGE_ID`
```

### Example: blueprint Skill

```markdown
## Reading Configuration in blueprint

1. **Read tech stack**:
   ```bash
   FRONTEND=$(jq -r '.tech_stack.frontend' .claude/techops-config.json)
   BACKEND=$(jq -r '.tech_stack.backend' .claude/techops-config.json)
   ```

2. **Use in blueprint generation**:
   - Pre-populate tech stack section with configured values
   - Customize architecture patterns based on stack
```

## Validation Rules

**Area Path / Iteration Path**:
- Must contain double backslashes (`\\`) for Azure DevOps compatibility
- Example: `Platform\\TechOps` (correct), `Platform\TechOps` (incorrect)

**Webhook URL**:
- Must start with `https://`
- Should match pattern: `https://*.webhook.office.com/webhookb2/...`

**Cloud ID**:
- Either a UUID format: `12345678-1234-1234-1234-123456789abc`
- Or a site URL: `https://yoursite.atlassian.net`

## Error Handling

### Missing Configuration File

```markdown
❌ Configuration file not found

**Error**: `.claude/techops-config.json` does not exist.

**Solution**: Run `/configure-techops` to create configuration:
```bash
/configure-techops
```

This will guide you through setting up project details, Azure DevOps, and integrations.
```

### Invalid Path Format

```markdown
❌ Invalid Area Path Format

**Error**: Area Path must use double backslashes (`\\`), not single backslashes.

**Current**: `Platform\TechOps`
**Correct**: `Platform\\TechOps`

Azure DevOps MCP tools require escaped backslashes in JSON.
```

### Missing Required Fields

```markdown
❌ Missing Required Configuration

**Error**: Azure DevOps configuration is incomplete.

**Missing fields**:
- `azure_devops.project`
- `azure_devops.area_path`

**Solution**: Re-run `/configure-techops` to complete configuration.
```

## Updating Configuration

To update existing configuration:

```bash
/configure-techops
```

**Behavior**:
1. Reads existing `.claude/techops-config.json`
2. Pre-fills prompts with current values
3. User can press Enter to keep current value or type new value
4. Overwrites config file with updated values

## Security Considerations

**Sensitive Data**:
- Teams webhook URL is sensitive and provides write access to Teams channel
- Consider using environment variables or Azure Key Vault references

**Example - Environment Variable Reference**:
```json
{
  "teams": {
    "webhook_url": "${TEAMS_WEBHOOK_URL}"
  }
}
```

**Example - Azure Key Vault Reference**:
```json
{
  "teams": {
    "webhook_url": "@Microsoft.KeyVault(VaultName=myvault;SecretName=TeamsWebhookUrl)"
  }
}
```

Skills should support environment variable expansion and Key Vault references.

## .gitignore Recommendations

Add to `.gitignore` to prevent committing sensitive config:

```gitignore
# TechOps Plugin Configuration (contains sensitive webhook URLs)
.claude/techops-config.json
```

**Alternative**: Commit config but use environment variables for sensitive values.

## Validation Output

After configuration completes:

```markdown
## ✅ Configuration Complete!

**Configuration saved to**: `.claude/techops-config.json`

### Summary

**Project**: {Product} Portal
**Team**: TechOps
**Contributor**: Corbin Taylor

**Azure DevOps**:
- Organization: {organization}
- Project: {Organization} Platform
- Area Path: Platform\\TechOps
- Iteration Path: Platform\\2026 Q1

**Confluence**:
- Space: Tech
- Post-Mortem Parent: 287244316

**Teams**: ✅ Configured

**Tech Stack**:
- Frontend: React 18 + TypeScript + Vite
- Backend: FastAPI + Python 3.12
- Infrastructure: Azure App Services + SQL Server + Redis

### Next Steps

1. **Test configuration** with a Skill:
   ```bash
   "Pick up bug 25123"
   ```

2. **Add to .gitignore** (recommended):
   ```bash
   echo ".claude/techops-config.json" >> .gitignore
   ```

3. **Use Skills and commands** - they will automatically use this configuration!

### Skills Available
- **blueprint** - "I want to design a new payment service"
- **pickup-bug** - "Pick up bug 25123"
- **pickup-feature** - "Pick up user story 25200"
- **implement-task** - "Implement task phase1#2.1"
- **review-task** - "Review task phase1#2.1"
```

## Integration with Plugin

All Skills and commands in the TechOps Claude Code Pack will automatically check for `.claude/techops-config.json` and use it to customize behavior.

**If config doesn't exist**, Skills will display:
```markdown
⚠️ TechOps configuration not found

To use this Skill, first configure your repo context:

```bash
/configure-techops
```

This will prompt you for project details, Azure DevOps settings, and integrations.
```

## Example Session

```markdown
User: /configure-techops