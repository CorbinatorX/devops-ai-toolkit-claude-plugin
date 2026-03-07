# Agentic Toolkit - Claude Code Plugin

AI-powered DevOps workflows for Claude Code: work item management, incident response, structured development workflows, and automated quality validation.

## Installation

### User Scope (Recommended)

Install at user scope to make the plugin available across all your projects:

```bash
# Add the marketplace (one-time)
/plugin marketplace add CorbinatorX/agentic-toolkit

# Install the plugin at user scope
/plugin install agentic-toolkit@agentic-toolkit --scope user
```

### Project Scope (Team Sharing)

Add to your project's `.claude/settings.json` to share with team members:

```json
{
  "extraKnownMarketplaces": {
    "agentic-toolkit": {
      "source": {
        "source": "github",
        "repo": "CorbinatorX/agentic-toolkit"
      }
    }
  },
  "enabledPlugins": {
    "agentic-toolkit@agentic-toolkit": true
  }
}
```

## Per-Repository Configuration

The plugin reads configuration from each project's `.claude/` directory, allowing different settings per repo while using the same globally-installed plugin.

**Configuration files:**
- `.claude/config.json` - Project architecture, conventions, patterns
- `.claude/techops-config.json` - Work item provider settings, Teams integration

Run `/configure` in any project to set up the configuration interactively.

## Configuration

The plugin works best when you define your project architecture in `.claude/config.json`. This enables:
- Architecture-aware blueprint generation
- Code placement aligned with your patterns
- Convention-following implementations
- Standards-based code reviews

```bash
# Copy the example config
cp .claude/config.example.json .claude/config.json

# Customize for your project
# Edit .claude/config.json with your:
# - Project structure (components, layers)
# - Tech stack (frameworks, versions)
# - Conventions (naming, indentation)
# - Patterns (API, application, UI)
# - Testing setup (commands, coverage)
```

See [`.claude/README.md`](.claude/README.md) for detailed configuration guide.

## Features

### Work Item Commands
- `/create-bug` - Create Bug work items in Azure DevOps
- `/create-incident` - Create incident work items with Teams notification
- `/create-tech-debt` - Parse status files and create tech debt items
- `/create-feature-request` - Create feature request work items

### Workflow Skills
- **orchestrate** - Autonomous multi-phase feature delivery using Claude Code Agent Teams with Tech Lead orchestrator
- **blueprint** - Architecture blueprint creation for new services/features
- **pickup-bug** - Bug pickup workflow with Azure DevOps integration
- **pickup-feature** - Feature pickup workflow for User Stories
- **implement-task** - Builder mode for executing phase-based tasks
- **review-task** - Foreman mode for quality validation and scoring

### Documentation Commands
- `/create-post-mortem` - Create incident post-mortems in Confluence
- `/update-code-summary` - Update code statistics and coverage reports
- `/update-coverage` - Run coverage analysis and update reports

### Operational Commands
- `/triage-504` - Azure Front Door 504 gateway timeout troubleshooting
- `/yarp-timeout-playbook` - YARP reverse proxy timeout analysis
- `/afd-waf-troubleshoot` - WAF and Azure edge debugging

### Workflow Commands
- `/blueprint-tasks` - Convert blueprints to task files
- `/commit` - Smart commit with conventional commit messages
- `/create-pr` - Create pull requests with auto-generated descriptions
- `/resume-orchestration` - Resume interrupted Tech Lead orchestration from checkpoint

## Skills Auto-Discovery

Skills automatically trigger based on natural language:

```bash
# Orchestrate (full autonomous delivery)
"Orchestrate the full build of the payment service"
"Deliver the notification system end to end"

# Blueprint
"I want to design a new payment service"

# Pickup Bug
"Pick up bug 25123"

# Pickup Feature
"Pick up user story 25200"

# Implement Task
"Implement task phase1#2.1"

# Review Task
"Review task phase1#2.1"
```

## Configuration

### Prerequisites

- **Claude Code**: v2.0.12+ (plugin marketplace support required)
- **MCP Servers**:
  - Azure DevOps MCP server (for work item operations)
  - Atlassian MCP server (for Confluence integration)

### Azure DevOps Configuration

Ensure your Azure DevOps MCP server is configured with:
- **Organization**: `{organization}`
- **Project**: `ERM`
- **Area Path**: `ERM\\Devops`
- **Iteration Path**: `ERM\\dops-backlog`

### Confluence Configuration (Optional)

For post-mortem creation:
- **Space**: `Tech`
- **Post Mortems Parent ID**: `287244316`

### Teams Notifications (Optional)

Add Teams webhook URL to your repo's `.claude/config.json` or team configuration.

## Shared Modules

The plugin includes comprehensive documentation for common patterns:

- **Azure DevOps** (`shared/azure-devops/`) - Work item CRUD, identity resolution, field validation
- **Git** (`shared/git/`) - Branch slug generation, conventional commits
- **Teams** (`shared/teams/`) - MessageCard templates, notification patterns
- **Confluence** (`shared/confluence/`) - Post-mortem templates, SLA calculation
- **Orchestration** (`shared/orchestration/`) - State management, hooks, and resume patterns for Agent Teams
- **Work Items** (`shared/work-items/`) - Provider-agnostic work item interface (ADO, Notion, Jira)
- **Worktree** (`shared/worktree/`) - Git worktree patterns for isolated development

See individual module READMEs in `shared/` for detailed usage patterns.

## Agent Teams Integration

The plugin supports **Claude Code Agent Teams** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) for autonomous multi-phase feature delivery:

```bash
# Enable Agent Teams
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Orchestrate a feature
"Orchestrate the full build of the payment service"
```

**How it works:**
1. A **Tech Lead** agent acts as team lead, spawning specialist teammates
2. **Architect** teammate designs the blueprint (with plan approval)
3. **Builder** teammates implement tasks in parallel (with file ownership)
4. **Reviewer** teammate validates quality (6-category scoring)
5. Failed reviews trigger rework loops (max 2 attempts)
6. Each phase produces a commit and PR
7. State is persisted for crash recovery (`/resume-orchestration`)

**Without Agent Teams**, the `orchestrate` skill falls back to guiding you through the sequential workflow manually.

See `agents/workflow/tech-lead.md` and `skills/orchestrate/SKILL.md` for details.

## Agents

The plugin includes specialized agents for auto-discovery:

**Workflow Agents:**
- **tech-lead** - Team lead orchestrator using Claude Code Agent Teams for autonomous multi-phase delivery
- **software-architect** - Architecture blueprint creation and domain modeling
- **builder** - Focused task implementation with strict scope discipline
- **manager** - Quality assurance with automated checks and scoring

**Operations Agents:**
- **ops-triager** - Incident triage and log analysis
- **azure-edge-specialist** - Azure Front Door, WAF, and edge networking issues
- **dotnet-performance-analyst** - .NET application performance and YARP debugging

## Benefits

✅ **Clean Repos** - No `.claude/` clutter in every project
✅ **Team Reuse** - One plugin, installed everywhere
✅ **Centralized Updates** - Update plugin once, all repos benefit
✅ **Natural Language** - Skills auto-discover from conversation
✅ **Consistent Workflows** - Same patterns across all team repos

## Documentation

- **Skills Reference**: See `skills/*/SKILL.md` for detailed Skill documentation
- **Shared Patterns**: See `shared/*/README.md` for reusable patterns
- **Adoption Guide**: See `ADOPTION.md` for team installation instructions

## Support

- **Issues**: https://github.com/CorbinatorX/devops-ai-toolkit-claude-plugin/issues
- **Documentation**: See README files in each directory

## License

MIT License - see LICENSE file for details
