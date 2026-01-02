# Changelog

All notable changes to the Agentic Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-XX

### Added

#### Skills
- **blueprint** - Create comprehensive architecture blueprints with 11+ section structure
- **pickup-bug** - 11-step Bug workflow (retrieve, assign, branch, investigate, plan, implement, test)
- **pickup-feature** - User Story implementation workflow with acceptance criteria validation
- **implement-task** - Builder-mode task execution from phase files with checkbox tracking
- **review-task** - Quality validation with 6-category scoring and S/A/B/C/D/F letter grades

#### Agents

**Workflow Agents:**
- **software-architect** - Architecture blueprint creation and domain modeling expertise
- **builder** - Focused task implementation with strict scope discipline
- **manager** - Quality assurance with automated checks and scoring

**Operations Agents:**
- **ops-triager** - Incident triage, log analysis, P0-P3 severity assessment
- **azure-edge-specialist** - Azure Front Door, WAF, 504 timeout debugging
- **dotnet-performance-analyst** - YARP reverse proxy, .NET performance analysis

#### Commands

**Work Items:**
- `/create-bug` - Create Bug work items in Azure DevOps
- `/create-feature-request` - Create feature request work items
- `/create-incident` - Create incident work items with Teams notification
- `/create-tech-debt` - Parse status files and create tech debt items

**Documentation:**
- `/create-post-mortem` - Create incident post-mortems in Confluence with SLA calculation
- `/update-code-summary` - Update code statistics and coverage reports
- `/update-coverage` - Run coverage analysis and update reports

**Workflow:**
- `/blueprint-tasks` - Convert architecture blueprints to phase task files
- `/commit` - Smart commit with conventional commit message format
- `/create-pr` - Create pull requests with auto-generated descriptions

**Operations:**
- `/triage-504` - Azure Front Door 504 gateway timeout troubleshooting
- `/yarp-timeout-playbook` - YARP reverse proxy timeout analysis
- `/afd-waf-troubleshoot` - WAF and Azure edge debugging

#### Shared Modules

**Documentation libraries for common patterns:**
- **azure-devops** - Work item CRUD, identity resolution, field validation (Project: ERM)
- **git** - Branch slug generation (7-step algorithm), conventional commits
- **teams** - MessageCard templates for notifications (bug, feature, incident)
- **confluence** - Post-mortem templates, business hours SLA calculation (9am-5pm)

### Features

- **Auto-discovery**: Skills and agents trigger automatically based on natural language
- **Azure DevOps Integration**: Full MCP tool integration for work item management
- **Git Branch Automation**: Automatic branch naming with `bug/` and `feature/` prefixes
- **Quality Scoring**: 6-category assessment with 100-point scale
- **Teams Notifications**: Optional webhook notifications for work items
- **Confluence Post-Mortems**: Automated incident documentation with SLA tracking
- **Shared Patterns**: Reusable documentation modules eliminate duplication

### Configuration

**Azure DevOps:**
- Organization: `{organization}`
- Project: `ERM`
- Area Path: `ERM\\Devops`
- Iteration Path: `ERM\\dops-backlog`

**Confluence:**
- Space: `Tech`
- Post Mortems Parent ID: `287244316`

**Branch Naming:**
- Bugs: `bug/{id}-{slug}`
- Features: `feature/{id}-{slug}`
- Max slug length: 50 characters (word boundary truncation)

**Scoring Thresholds:**
- Production Ready: ≥85 points (A grade)
- Pass: ≥75 points (B grade)
- Rework Required: <65 points (C grade or below)

### Notes

This is the initial release of the Agentic Toolkit. The plugin consolidates TechOps workflows, skills, and agents into a single reusable package for team-wide adoption.

**Benefits:**
- Clean repos (no `.claude/` clutter in every project)
- Team reuse (one plugin, installed everywhere)
- Centralized updates (update plugin once, all repos benefit)
- Natural language discovery (Skills auto-trigger from conversation)
- Consistent workflows (same patterns across all team repos)

**Installation:**
```bash
claude-code plugin install CorbinatorX/devops-ai-toolkit-claude-plugin
```

**Prerequisites:**
- Claude Code v1.0+
- Azure DevOps MCP server configured
- Atlassian MCP server configured (optional, for Confluence)

---

## [Unreleased]

### Planned Features
- Additional operational playbooks (database timeouts, Redis issues)
- Enhanced telemetry and monitoring integration
- Automated tech debt tracking and reporting
- Multi-team support with configurable projects
- Custom scoring profiles for different project types
