# DevOps AI Toolkit - Claude Code Plugin

AI-powered Azure DevOps workflows for Claude Code: incident response, work item management, structured development workflows, and automated quality validation.

## Installation

```bash
# Add the marketplace (one-time)
/plugin marketplace add CorbinatorX/devops-ai-toolkit-claude-plugin

# Install the plugin
/plugin install devops-ai-toolkit@devops-ai-toolkit-claude-plugin
```

### Auto-Install for Projects

Add to your project's `.claude/settings.json` to auto-prompt team members:

```json
{
  "extraKnownMarketplaces": {
    "devops-ai-toolkit": {
      "source": {
        "source": "github",
        "repo": "CorbinatorX/devops-ai-toolkit-claude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "devops-ai-toolkit@devops-ai-toolkit-claude-plugin": true
  }
}
```

## Features

### Work Item Commands
- `/create-techops-bug` - Create TechOps Bug work items in Azure DevOps
- `/create-incident` - Create incident work items with Teams notification
- `/create-tech-debt` - Parse status files and create tech debt items
- `/create-feature-request` - Create feature request work items

### Workflow Skills
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

## Skills Auto-Discovery

Skills automatically trigger based on natural language:

```bash
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

See individual module READMEs in `shared/` for detailed usage patterns.

## Agents

The plugin includes specialized agents for auto-discovery:

- **techops-triager** - Incident triage and log analysis
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
