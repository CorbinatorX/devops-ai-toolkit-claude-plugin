---
name: orchestrate
description: Orchestrate autonomous multi-phase feature delivery using Claude Code Agent Teams with a Tech Lead coordinator that spawns architect, builder, and reviewer teammates
allowed-tools: Read, Write, Bash, Grep, Glob, Edit
auto-discover:
  - "orchestrate"
  - "run full workflow"
  - "deliver feature"
  - "tech lead"
  - "build the whole thing"
  - "end to end"
---

# Orchestrate Skill

## Purpose

Orchestrates fully autonomous multi-phase feature delivery using **Claude Code Agent Teams**. A Tech Lead agent acts as the team lead, spawning specialist teammates (Architect, Builder, Reviewer) to design, implement, review, and deliver features as PRs — one phase at a time.

This Skill delegates orchestration to the **tech-lead** agent, which coordinates the full lifecycle using Agent Teams.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "Orchestrate the full build of {feature}"
- "Deliver {feature} end to end"
- "Run the full workflow for {description}"
- "Tech lead: build {service/feature}"
- "Build the whole thing"
- "End to end delivery of {feature}"

## Example Invocations

```
"Orchestrate the full build of the payment service"
"Deliver the notification system end to end"
"Tech lead: implement the user profile feature"
"Run the full workflow for work item #25186"
"Build the whole thing from the payment-service blueprint"
```

## Input Formats

The Skill accepts three input types:

**1. Free-text feature description:**
```
"Orchestrate a payment processing service with Stripe integration"
```

**2. Work item reference:**
```
"Orchestrate work item #25186"
"Deliver Notion page https://notion.so/abc123"
```

**3. Existing blueprint path:**
```
"Orchestrate from .claude/blueprints/payment-service-blueprint.md"
```

## Shared Modules

This Skill uses shared helper modules:

**Orchestration** (`.claude/shared/orchestration/`):
- State file schema and persistence
- State transition rules
- Continuation prompt generation
- Resume algorithm

**Git** (`.claude/shared/git/`):
- Branch slug generation
- Branch creation

**Work Items** (`.claude/shared/work-items/`) — Optional:
- Work item retrieval and status updates
- Provider abstraction (ADO, Notion, Jira)

**Teams** (`.claude/shared/teams/`) — Optional:
- Phase completion notifications
- Error alerts during unattended runs

See shared module READMEs for detailed patterns and examples.

## Workflow

### Step 1: Check Agent Teams Availability

```bash
# Check if Agent Teams is enabled
if [ -z "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" ]; then
    echo "Agent Teams not enabled"
fi
```

**If Agent Teams is enabled:** Proceed with full orchestration (Steps 2-10).

**If Agent Teams is NOT enabled:**
```
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not enabled.

To enable Agent Teams for autonomous orchestration:
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

Without Agent Teams, you can run the workflow manually:
  1. /blueprint — Create architecture
  2. /blueprint-tasks — Convert to phase tasks
  3. /implement-task — Implement each task
  4. /review-task — Review each task
  5. /commit — Commit changes
  6. /create-pr — Create pull request

Would you like to proceed with the sequential workflow instead?
```

If user agrees to sequential workflow, guide them through each step interactively. Otherwise, stop and let them enable the flag.

### Step 2: Read Project Configuration

**Required:** Read `.claude/config.json` to understand:
- Project type (backend, frontend, fullstack, mobile)
- Tech stack (dotnet, nodejs, python, react, etc.)
- Architecture pattern (clean-architecture, hexagonal, mvc, etc.)
- Testing framework and coverage goals
- Build commands

**If `.claude/config.json` doesn't exist:**
```
Project configuration not found.

.claude/config.json is required for orchestration.
Run /configure to set up project configuration first.
```

**Optional:** Read `.claude/techops-config.json` for:
- Work item provider configuration
- Teams notification settings
- Worktree configuration

### Step 3: Parse Input and Resolve Feature Context

**If work item reference provided:**
1. Determine provider from `.claude/techops-config.json`
2. Fetch work item details using provider-specific MCP tools
3. Extract: title, description, acceptance criteria, repository
4. Use title for service name derivation

**If blueprint path provided:**
1. Verify blueprint file exists
2. Extract service name from filename (e.g., `payment-service-blueprint.md` -> `payment-service`)
3. Skip architecture phase (Phase 1 of Tech Lead)

**If free-text description provided:**
1. Derive service name from description
2. Use description as feature requirements

### Step 4: Set Up Git Branch

Generate branch name using shared git patterns:
- **With work item:** `feature/{work-item-id}-{slug}`
- **Without work item:** `feature/{slug}`

**Check for worktree mode** in `.claude/techops-config.json`:
- If `worktree.enabled` is `true` and a repository field is available from the work item, create an isolated worktree using patterns from `.claude/shared/worktree/README.md`
- Otherwise, create branch in current working directory

**Reference:** See `.claude/shared/git/README.md` for branch slug generation and `.claude/shared/worktree/README.md` for worktree patterns.

### Step 5: Initialize Orchestration State

Create the orchestration state file:

```bash
mkdir -p .claude/tasks/{service-name}
```

Write initial state to `.claude/tasks/{service-name}/orchestration-state.json`:

```json
{
  "version": "1.0",
  "feature": "{service-name}",
  "input_source": {
    "type": "{work-item|blueprint|free-text}",
    "reference": "{work-item-id|blueprint-path|description}",
    "provider": "{azure-devops|notion|jira|null}",
    "url": "{source-url|null}"
  },
  "blueprint_path": null,
  "branch_name": "{branch-name}",
  "total_phases": 0,
  "current_phase": 0,
  "status": "initializing",
  "phase_status": {},
  "review_history": [],
  "continuation_prompt": null,
  "created_at": "{ISO-8601-now}",
  "updated_at": "{ISO-8601-now}"
}
```

**Reference:** See `.claude/shared/orchestration/README.md` for full schema.

### Step 6: Display Orchestration Summary

Present the orchestration plan to the user before starting:

```markdown
## Orchestration Plan: {service-name}

**Input:** {input type and reference}
**Branch:** {branch-name}
**Tech Stack:** {from config}
**Architecture:** {from config}

### Workflow
1. Architect teammate designs blueprint (with plan approval)
2. Blueprint converted to phase tasks
3. For each phase:
   a. Builder teammate(s) implement tasks
   b. Reviewer teammate validates quality
   c. Rework if score < 75 (max 2 attempts)
   d. Commit and create PR on pass
4. Repeat until all phases delivered

### Agent Teams Configuration
- Team lead: Tech Lead agent
- Teammates: Architect, Builder(s), Reviewer
- Strategy: Fresh team per phase
- Quality threshold: 75/100 (Grade B)

Proceed with orchestration?
```

Wait for user confirmation before starting.

### Step 7: Delegate to Tech Lead Agent

Invoke the **tech-lead** agent as the Agent Teams team lead:

```markdown
You are the Tech Lead orchestrator. Manage autonomous multi-phase delivery.

Feature: {service-name}
Input: {input source details}
Config: .claude/config.json
State file: .claude/tasks/{service-name}/orchestration-state.json
Branch: {branch-name}

{If blueprint exists: "Blueprint already exists at {path}. Skip architecture phase."}
{If work item: "Work item details: {title}, {description}, {acceptance criteria}"}
{If free-text: "Feature description: {description}"}

Follow the tech-lead agent definition for the full orchestration workflow.
Persist state after every significant event.
```

The Tech Lead agent takes over from here and manages:
- Architect teammate spawning with plan approval
- Blueprint-to-tasks conversion
- Builder teammate spawning per phase with file ownership
- Reviewer teammate spawning for quality gates
- Rework loops (max 2 attempts)
- Commit and PR creation per phase
- Team cleanup between phases

### Step 8: Monitor Progress (User-Facing)

While the Tech Lead orchestrates, provide progress updates at milestones:

```markdown
## Orchestration Progress: {service-name}

### Architecture
- [x] Architect plan approved
- [x] Blueprint created: .claude/blueprints/{name}-blueprint.md
- [x] Phase tasks generated: {N} phases

### Phase 1: {title}
- [x] Builder(s) spawned: {count} teammates
- [x] Tasks completed: {X}/{Y}
- [x] Review score: {score}/100 (Grade {grade})
- [x] PR created: #{pr-number}

### Phase 2: {title}
- [ ] In progress...
```

### Step 9: Handle Completion

When all phases are delivered:

```markdown
## Orchestration Complete: {service-name}

### Summary
**Phases delivered:** {N}
**Total tasks:** {count}
**Duration:** {elapsed}

### Pull Requests
| Phase | Title | Score | Grade | PR |
|-------|-------|-------|-------|----|
| 1 | {title} | {score} | {grade} | #{number} |
| 2 | {title} | {score} | {grade} | #{number} |

### State File
.claude/tasks/{service-name}/orchestration-state.json (status: completed)
```

**If work item provider configured:**
- Update work item state to "Resolved" / "Done"
- Add completion comment with PR links

**If Teams configured:**
- Send completion notification with PR summary

### Step 10: Handle Interruption

If the orchestration is interrupted (session loss, context limit):

The Tech Lead writes a continuation prompt to the state file before exiting. To resume:

```
Orchestration interrupted. State has been saved.

To resume: /resume-orchestration {service-name}
```

**Reference:** See `commands/workflow/resume-orchestration.md` for the resume command.

## Error Handling

### Missing Configuration
```
Project configuration not found.

.claude/config.json is required for orchestration.

Please run /configure to set up:
- Project type and tech stack
- Architecture pattern
- Testing framework
- Build commands
```

### Work Item Not Found
```
Work item {reference} not found.

Provider: {provider}
Error: {error details}

Check:
- Work item ID/URL is correct
- You have access to the work item
- Provider is configured in .claude/techops-config.json
```

### Blueprint Generation Failed
```
Architect teammate failed to generate blueprint.

State file: .claude/tasks/{service-name}/orchestration-state.json
Status: architecture (incomplete)

Options:
1. Resume: /resume-orchestration {service-name}
2. Create blueprint manually: /blueprint {description}
3. Start fresh: delete state file and re-run
```

### Phase Review Blocked
```
Phase {N} is blocked after 2 rework attempts.

Latest score: {score}/100 (Grade {grade})
Status report: .claude/tasks/{service-name}/phase{N}_status.md

The following issues could not be automatically resolved:
- {issue 1}
- {issue 2}

Please review the status report and:
1. Fix issues manually, then: /resume-orchestration {service-name}
2. Accept current state and skip to next phase
3. Abandon this orchestration
```

### Teammate Spawn Failure
```
Failed to spawn {role} teammate.

This may be caused by:
- Agent Teams feature not properly enabled
- System resource limits
- Permission issues

Retry: /resume-orchestration {service-name}
Fallback: Run the {role} step manually using /{corresponding-command}
```

## Sequential Fallback Workflow

When Agent Teams is not available, this Skill guides users through the equivalent manual workflow:

```
Sequential Workflow Mode (Agent Teams not enabled)

Step 1: /blueprint {feature-description}
  -> Creates architecture blueprint

Step 2: /blueprint-tasks {blueprint-path}
  -> Converts to phase task files

Step 3: /implement-task {service}/phase1#1.1
  -> Implement first task
  [Repeat for each task in phase]

Step 4: /review-task {service}/phase1
  -> Review phase implementation

Step 5: /commit
  -> Commit phase changes

Step 6: /create-pr
  -> Create phase PR

[Repeat Steps 3-6 for each phase]
```

The Skill tracks which step the user is on and suggests the next command after each completion.

## Integration with Workflow

**Delegates to agents:**
- **tech-lead** agent — Full orchestration as team lead
- **software-architect** agent — Blueprint creation (via Tech Lead)
- **builder** agent — Task implementation (via Tech Lead)
- **manager** agent — Quality validation (via Tech Lead)

**Uses commands:**
- `/blueprint-tasks` — Convert blueprint to phase tasks
- `/commit` — Create conventional commit per phase
- `/create-pr` — Create pull request per phase
- `/resume-orchestration` — Resume interrupted orchestration

**Uses skills (via teammates):**
- `blueprint` — Architecture design
- `implement-task` — Task implementation
- `review-task` — Quality validation

**Related skills:**
- `pickup-feature` — For work-item-driven feature pickup (single-task, not multi-phase)
- `pickup-bug` — For bug work items
- `pickup-tech-debt` — For tech debt work items

## Development Cycle Position

```
1. /orchestrate              — Full autonomous delivery  <-- YOU ARE HERE
   (or manually):
   1a. /blueprint            — Architect creates architecture
   1b. /blueprint-tasks      — Convert to phase-based tasks
   1c. /implement-task X.X   — Builder implements tasks
   1d. /review-task X.X      — Manager validates
   1e. /commit               — Create smart commit
   1f. /create-pr            — Create pull request
2. [Review, approve, merge]
3. /resume-orchestration     — Resume if interrupted
```

## Notes

- This Skill is the top-level entry point for autonomous multi-phase delivery
- The Tech Lead agent handles all coordination — this Skill is the launcher
- Agent Teams provides independent context windows per teammate, solving context limit issues
- Team-per-phase strategy ensures fresh context and avoids bloat
- State persistence enables crash recovery via `/resume-orchestration`
- Sequential fallback makes the Skill usable even without Agent Teams
- File ownership in Builder spawn prompts prevents concurrent edit conflicts
- Max 3 Builder teammates per phase keeps token costs manageable
- Review threshold of 75 (Grade B) balances quality with progress
- Max 2 rework attempts prevents infinite loops — escalates to human
- Works with all work item providers (ADO, Notion, Jira) via shared interfaces
