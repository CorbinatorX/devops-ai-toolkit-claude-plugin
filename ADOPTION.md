# TechOps Claude Code Pack - Team Adoption Guide

Complete guide for installing and using the TechOps Claude Code Pack plugin across your team repositories.

## Overview

The TechOps Claude Code Pack is a reusable Claude Code plugin that provides:
- **5 Skills** with auto-discovery (blueprint, pickup-bug, pickup-feature, implement-task, review-task)
- **13 Slash Commands** for work items, documentation, and operations
- **6 Specialized Agents** for workflow and operations support
- **Shared Modules** for Azure DevOps, Git, Teams, and Confluence patterns

## Prerequisites

### Required
- **Claude Code**: v1.0+ (CLI or IDE integration)
- **Azure DevOps MCP Server**: Configured with organization and project access
- **Git**: Installed and configured
- **jq**: JSON processor (for config parsing)

### Optional
- **Atlassian MCP Server**: For Confluence post-mortems
- **Teams Webhook**: For work item notifications

## Installation

### Step 1: Install Plugin

The plugin will be installed from GitHub once published. For now, install locally:

```bash
# Clone or use existing plugin directory
cd /path/to/techops-claudecode-pack

# Claude Code will auto-discover the plugin
# No explicit installation command needed - just have it in accessible directory
```

**Future** (once published):
```bash
claude-code plugin install CorbinatorX/devops-ai-toolkit-claude-plugin
```

### Step 2: Configure Your Repository

Each repository needs a `.claude/techops-config.json` configuration file.

**Option A: Use `/configure-techops` command**

Run the interactive configuration wizard:

```bash
/configure-techops
```

This will prompt you for:
- Project information (name, description, contributor, team)
- Azure DevOps settings (organization, project, area path, iteration path)
- Optional: Confluence settings (cloud ID, space, parent page ID)
- Optional: Teams webhook URL
- Optional: Tech stack details

**Option B: Create config manually**

Create `.claude/techops-config.json`:

```json
{
  "version": "1.0",
  "project": {
    "name": "Your Project Name",
    "description": "Brief project description",
    "contributor": "Your Full Name",
    "owning_team": "Your Team Name"
  },
  "azure_devops": {
    "organization": "your-org",
    "project": "Your ADO Project",
    "area_path": "Project\\\\Team",
    "iteration_path": "Project\\\\Sprint"
  },
  "confluence": {
    "cloud_id": "your-cloud-id-or-url",
    "space_key": "SPACE",
    "postmortem_parent_page_id": "123456"
  },
  "teams": {
    "webhook_url": "${TEAMS_WEBHOOK_URL}"
  },
  "tech_stack": {
    "frontend": "Your frontend stack",
    "backend": "Your backend stack",
    "infrastructure": "Your infrastructure",
    "cicd": "Your CI/CD"
  }
}
```

**Important**: Use double backslashes (`\\\\`) in JSON for Azure DevOps paths!

### Step 3: Secure Configuration

Add to `.gitignore`:

```gitignore
# TechOps Plugin Configuration (contains sensitive webhook URLs)
.claude/techops-config.json
```

**Recommended**: Use environment variables for sensitive values:

```json
{
  "teams": {
    "webhook_url": "${TEAMS_WEBHOOK_URL}"
  }
}
```

Then set in your shell:
```bash
export TEAMS_WEBHOOK_URL="https://your-webhook-url"
```

### Step 4: Test Installation

Test Skills auto-discovery:

```bash
# Try a simple Skill
"I want to design a new payment service"

# Should trigger blueprint Skill
```

Test slash command:

```bash
/configure-techops

# Should show current configuration
```

## Using Skills

Skills automatically trigger from natural language. No slash commands needed!

### blueprint Skill

**Trigger phrases**: "design", "architecture", "blueprint", "new service"

**Example**:
```
"I want to design a new payment processing service"
```

**What it does**:
1. Delegates to **software-architect** agent
2. Creates 11+ section architecture blueprint
3. Saves to `.claude/blueprints/{name}-blueprint.md`
4. Includes domain modeling, API specs, tech stack, multi-phase plans

**Output**: `.claude/blueprints/payment-processing-blueprint.md`

### pickup-bug Skill

**Trigger phrases**: "pick up bug", "bug #", "fix bug"

**Example**:
```
"Pick up bug 25123"
```

**What it does**:
1. Retrieves TechOps Bug from Azure DevOps
2. Assigns to you (from config.contributor)
3. Creates branch: `bug/25123-{slug}`
4. Investigates: Reads repro steps, error logs, related code
5. Plans: Creates fix approach
6. Implements: Executes fix with builder agent
7. Tests: Validates fix works
8. Updates work item state to "In Progress"

**Required config**: `azure_devops.project`, `azure_devops.area_path`, `project.contributor`

### pickup-feature Skill

**Trigger phrases**: "pick up feature", "user story", "pick up story"

**Example**:
```
"Pick up user story 25200"
```

**What it does**:
1. Retrieves User Story from Azure DevOps
2. Assigns to you
3. Creates branch: `feature/25200-{slug}`
4. Reviews acceptance criteria
5. Plans implementation
6. Implements with builder agent
7. Validates against acceptance criteria

**Required config**: `azure_devops.project`, `azure_devops.area_path`, `project.contributor`

### implement-task Skill

**Trigger phrases**: "implement task", "build task", "phase#", "task #"

**Example**:
```
"Implement task payment-service/phase1#2.1"
```

**What it does**:
1. Reads task from `.claude/tasks/payment-service/phase1.md`
2. Delegates to **builder** agent
3. Implements ONLY files specified in task annotations
4. Updates checkbox: `- [ ] 2.1 Task` → `- [x] 2.1 Task`
5. Generates implementation report

**Required**: Phase file at `.claude/tasks/{service}/{phase}.md` with tasks

**Format**:
```markdown
## Phase 1: Core Implementation

- [ ] 1.1 Create payment models
  <!-- Files: application/features/payment/models.py -->

- [ ] 1.2 Implement payment service
  <!-- Files: application/features/payment/service.py -->
```

### review-task Skill

**Trigger phrases**: "review task", "validate task", "quality check"

**Example**:
```
"Review task payment-service/phase1#2.1"
```

**What it does**:
1. Delegates to **manager** agent
2. Runs automated checks: build, tests, lint, type checking, security scan
3. Scores 6 categories (0-20 points each):
   - Completeness (all checkboxes done?)
   - Code Quality (clean, readable?)
   - Architecture (follows blueprint?)
   - Security (validated inputs?)
   - Testing (coverage ≥80%?)
   - Documentation (updated?)
4. Assigns letter grade: S/A/B/C/D/F
5. Generates `.claude/tasks/{service}/{phase}_status.md` with findings

**Pass threshold**: 75/100 points (B grade)
**Production-ready**: 85/100 points (A grade)

## Using Slash Commands

Traditional commands remain available for specific operations.

### Configuration

```bash
/configure-techops
```
Configure or update repo-specific settings.

### Work Items

```bash
/create-techops-bug
```
Create TechOps Bug work item in Azure DevOps.

```bash
/create-incident
```
Create incident work item with Teams notification.

```bash
/create-feature-request
```
Create User Story for feature requests.

```bash
/create-tech-debt
```
Parse `_status.md` files and create tech debt work items.

### Documentation

```bash
/create-post-mortem
```
Create incident post-mortem in Confluence with SLA calculation.

```bash
/update-code-summary
```
Generate code statistics summary.

```bash
/update-coverage
```
Run test coverage analysis.

### Workflow

```bash
/blueprint-tasks
```
Convert architecture blueprint to task files.

```bash
/commit
```
Generate conventional commit message.

```bash
/create-pr
```
Create pull request with description.

### Operations

```bash
/triage-504
```
Troubleshoot Azure Front Door 504 timeouts.
Delegates to **azure-edge-specialist** agent.

```bash
/yarp-timeout-playbook
```
Analyze YARP reverse proxy timeouts.
Delegates to **dotnet-performance-analyst** agent.

```bash
/afd-waf-troubleshoot
```
Debug Azure Front Door routing and WAF blocks.
Delegates to **azure-edge-specialist** agent.

## Specialized Agents

Agents can be invoked by Skills or trigger automatically from conversation context.

### Workflow Agents

**software-architect**
- **Triggers**: "design", "architecture", "blueprint"
- **Expertise**: Clean Architecture, DDD, domain modeling, tech stack selection
- **Used by**: blueprint Skill

**builder**
- **Triggers**: "implement task", "build task"
- **Expertise**: Focused implementation with strict scope discipline
- **Used by**: pickup-bug, pickup-feature, implement-task Skills

**manager**
- **Triggers**: "review task", "validate task", "quality check"
- **Expertise**: Quality validation, automated checks, scoring, tech debt tracking
- **Used by**: review-task Skill

### Operations Agents

**techops-triager**
- **Triggers**: "incident", "triage", "production issue"
- **Expertise**: Incident analysis, log analysis, KQL queries, P0/P1/P2/P3 severity
- **Used by**: Standalone or manual invocation

**azure-edge-specialist**
- **Triggers**: "504", "gateway timeout", "Front Door", "WAF"
- **Expertise**: AFD routing, WAF rules, edge caching, SSL/TLS, origin timeouts
- **Used by**: /triage-504, /afd-waf-troubleshoot commands

**dotnet-performance-analyst**
- **Triggers**: "YARP", "timeout", ".NET performance"
- **Expertise**: YARP timeout analysis, connection pooling, middleware pipeline
- **Used by**: /yarp-timeout-playbook command

## Common Workflows

### Bug Fix Workflow

1. **Pick up bug**: "Pick up bug 25123"
   - Skill assigns bug, creates branch, investigates

2. **Implement fix**: Builder agent implements

3. **Test**: Skill validates fix works

4. **Commit**: `/commit` or let pre-commit hooks handle it

5. **Create PR**: `/create-pr` or manual

### Feature Development Workflow

1. **Blueprint**: "I want to design a new payment service"
   - Creates architecture blueprint

2. **Create tasks**: `/blueprint-tasks`
   - Converts blueprint to phase files

3. **Implement phase**: "Implement task payment/phase1#1.1"
   - Builder implements each task

4. **Review phase**: "Review task payment/phase1#1.1"
   - Manager validates quality

5. **Repeat** for all phases

### Incident Response Workflow

1. **Triage**: Mention "incident" or "production issue"
   - Techops-triager agent analyzes

2. **Create incident**: `/create-incident`
   - Creates ADO work item + Teams notification

3. **Troubleshoot**:
   - `/triage-504` for 504 timeouts
   - `/yarp-timeout-playbook` for YARP issues
   - `/afd-waf-troubleshoot` for WAF blocks

4. **Post-mortem**: `/create-post-mortem` after resolution

## Best Practices

### Configuration Management

1. **One config per repo**: Each repo has its own `.claude/techops-config.json`
2. **Don't commit sensitive data**: Use environment variables for webhook URLs
3. **Keep config updated**: Run `/configure-techops` when project details change

### Using Skills vs Commands

**Prefer Skills** (natural language):
- More intuitive, conversation-like
- Automatically triggered from context
- Delegates to appropriate agents

**Use Commands** (slash commands):
- When you want explicit control
- For configuration changes
- For operational playbooks

### Git Branch Management

Skills create branches automatically:
- Bug branches: `bug/{id}-{slug}`
- Feature branches: `feature/{id}-{slug}`

**Slug algorithm**:
1. Lowercase
2. Replace special chars
3. Replace spaces with hyphens
4. Remove non-alphanumeric
5. Collapse multiple hyphens
6. Trim edges
7. Truncate to 50 chars

**Example**: "Feature flags don't display" → `bug/25123-feature-flags-dont-display`

### Quality Standards

Review-task Skill enforces these standards:
- **Completeness**: All task checkboxes completed
- **Code Quality**: Clean, readable, no smells
- **Architecture**: Follows blueprint patterns
- **Security**: Input validation, no vulnerabilities
- **Testing**: Coverage ≥ 80%
- **Documentation**: Updated docs/comments

**Minimum score**: 75/100 (B grade)
**Production-ready**: 85/100 (A grade)

## Troubleshooting

### Plugin Not Detected

**Symptom**: Skills don't auto-discover, commands not available

**Solution**:
1. Verify plugin directory is accessible
2. Check `.claude-plugin/plugin.json` exists
3. Restart Claude Code

### Configuration Errors

**Symptom**: "Configuration not found" error

**Solution**:
```bash
/configure-techops
```

**Symptom**: "Invalid Area Path Format"

**Solution**: Use double backslashes in JSON: `"ERM\\\\Devops"`

### Azure DevOps Integration Fails

**Symptom**: "Unable to retrieve work item"

**Solution**:
1. Verify MCP server configured
2. Check project name matches exactly
3. Verify area path uses double backslashes
4. Test with: `mcp__azure-devops__wit_get_work_item`

### Skills Don't Trigger

**Symptom**: Saying "Pick up bug 25123" doesn't trigger pickup-bug Skill

**Solution**:
1. Check plugin installed correctly
2. Try more explicit trigger: "I want to pick up bug 25123"
3. Fall back to slash command if needed

## Team Collaboration

### Sharing Configuration Templates

Create a template config for your team:

```bash
# team-config-template.json
{
  "version": "1.0",
  "project": {
    "name": "YOUR_PROJECT",
    "description": "Update this",
    "contributor": "YOUR_NAME",
    "owning_team": "TechOps"
  },
  "azure_devops": {
    "organization": "your-org",
    "project": "YOUR_ADO_PROJECT",
    "area_path": "Project\\\\Team",
    "iteration_path": "Project\\\\Current Sprint"
  }
}
```

Share in team docs, each developer fills in their details.

### Standardizing Workflows

Document team-specific workflows:
- When to use blueprint vs implement-task
- Quality score thresholds for PR approval
- Incident response runbooks
- Post-mortem SLA targets

### Plugin Updates

When plugin updates:
1. Pull latest version
2. Check CHANGELOG for breaking changes
3. Update config if new fields required
4. Test in one repo before team rollout

## Support

### Documentation

- **Plugin README**: [techops-claudecode-pack/README.md](https://github.com/CorbinatorX/devops-ai-toolkit-claude-plugin)
- **Shared Modules**: See `shared/*/README.md` for patterns
- **Changelog**: Track updates in `CHANGELOG.md`

### Issues

Report issues at: https://github.com/CorbinatorX/devops-ai-toolkit-claude-plugin/issues

### Getting Help

1. Check this ADOPTION.md guide
2. Review plugin README and shared module docs
3. Ask in team chat
4. Open GitHub issue for bugs/feature requests

## Next Steps

After installation:

1. **Test basic flow**:
   ```
   "I want to design a new test service"
   ```

2. **Pick up a real bug**:
   ```
   "Pick up bug {your-bug-id}"
   ```

3. **Try operational playbook**:
   ```
   /triage-504
   ```

4. **Share feedback** with team

5. **Contribute improvements** to plugin

## Version

- **Plugin Version**: 0.1.0
- **Last Updated**: 2025-12-19
- **Maintained By**: TechOps Team
