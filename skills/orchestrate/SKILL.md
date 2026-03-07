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

### Step 4: Create Feature Branch (MANDATORY)

**CRITICAL: This step MUST complete before ANY other work begins. Never work on main.**

1. **Derive service name** from the feature title or work item
   - e.g., "AI Concierge: Event Discovery" → `ai-concierge`

2. **Generate branch name** using shared git patterns (`.claude/shared/git/README.md`):
   - **With work item:** `feature/{work-item-id}-{slug}`
   - **Without work item:** `feature/{slug}`

3. **Check for worktree mode** in `.claude/techops-config.json`:

   **If `worktree.enabled` is `true`:**
   ```bash
   # Each orchestration gets its own isolated worktree
   # This is ESSENTIAL for running parallel orchestrations
   worktree_enabled=$(jq -r '.worktree.enabled // false' .claude/techops-config.json)

   if [ "$worktree_enabled" = "true" ]; then
       # Follow .claude/shared/worktree/README.md patterns
       # Creates: {base_path}/{repo}-{work_item_id}/
       # Each agent-deck session works in its own directory
       # Prevents branch conflicts between parallel orchestrations
   fi
   ```

   **If worktree mode disabled:**
   ```bash
   # Create branch in current directory
   git checkout -b feature/{work-item-id}-{slug}
   ```

4. **Verify branch** — STOP if still on main:
   ```bash
   current_branch=$(git branch --show-current)
   if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
       echo "FATAL: Still on $current_branch. Branch creation failed. Do not proceed."
       exit 1
   fi
   echo "Working on branch: $current_branch"
   ```

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
- Team lead: THIS session (you — the main Claude Code session)
- Teammates: Architect, Builder(s), Reviewer (spawned by you)
- Strategy: Fresh team per phase
- Quality threshold: 75/100 (Grade B)

Proceed with orchestration?
```

Wait for user confirmation before starting.

### Step 7: Act as Team Lead (CRITICAL — do NOT delegate)

**CRITICAL: YOU (the main session) are the team lead. Do NOT delegate to a subagent or invoke the tech-lead agent via the Agent tool. Subagents CANNOT create teams or spawn teammates — only the top-level session can.**

You must directly:
1. Create an agent team
2. Spawn teammates
3. Coordinate via the shared task list and messaging
4. Clean up the team between phases

Follow the workflow from `agents/workflow/tech-lead.md` as YOUR instructions — do not spawn it as a separate agent.

#### 7a. Architecture Phase — Spawn Architect Teammate

Create a team and spawn an Architect teammate:

```
Create an agent team for {service-name} development.

Spawn an architect teammate with this prompt:
"You are a Software Architect. Design architecture for: {feature_description}

Create a comprehensive blueprint at .claude/blueprints/{service-name}-blueprint.md.
Follow project conventions from .claude/config.json.
Reference the software-architect agent definition for blueprint structure requirements.

Include:
- Domain model with entities and relationships
- Technical architecture following {configured_pattern}
- API design with endpoints and data models
- 4-6 implementation phases with 5-10 tasks each
- Security, performance, and testing considerations"

Require plan approval before the architect makes changes.
Only approve plans that include test strategy and security considerations.
```

Wait for the Architect to complete. Validate the blueprint exists and has all required sections.

**If blueprint already exists:** Skip this step — go directly to 7b.

#### 7b. Task Generation

Run `/blueprint-tasks` with the blueprint path to generate phase task files.
Parse the generated files to determine total phases and task structure.
Update orchestration state.

#### 7c. Implementation Phases — For Each Phase

**Clean up any previous team, then create a fresh team for this phase:**

```
Clean up the team.
Create a new agent team for {service-name} phase {N}.
```

**Analyze task independence and assign file ownership:**
- Read the phase file tasks and their file locations
- Group tasks by file ownership — no two teammates edit the same files
- Determine teammate count (1-3 builders based on independent task groups)

**Spawn Builder teammate(s):**

```
Spawn a builder teammate with this prompt:
"You are a Builder. Implement tasks from the shared task list.

Blueprint: .claude/blueprints/{service-name}-blueprint.md
Phase file: .claude/tasks/{service-name}/phase{N}.md
Your file ownership: {list of files this teammate may edit}

Follow the builder agent definition for implementation workflow.
Self-claim tasks from the shared list as you complete work.
Only edit files in your ownership set.
Run build and tests after each task."
```

**Create tasks in the shared task list** from the phase file with dependencies.

**Wait for all builders to finish** — you'll receive idle notifications.

**Spawn Reviewer teammate:**

```
Spawn a reviewer teammate with this prompt:
"You are a Reviewer running the Manager agent's scoring workflow.

Phase file: .claude/tasks/{service-name}/phase{N}.md
Blueprint: .claude/blueprints/{service-name}-blueprint.md

Run the full Manager review process:
1. Execute automated checks (build, tests, linting, type checking)
2. Validate acceptance criteria from the phase file
3. Score across 6 categories (Completeness, Code Quality, Architecture, Security, Testing, Documentation)
4. Generate status report at .claude/tasks/{service-name}/phase{N}_status.md
5. Report your total score and letter grade"
```

**Evaluate review results:**
- Score >= 75 (Grade B+): Phase passes — proceed to commit and PR
- Score < 75: Trigger rework — message Builder teammates with specific fixes
- Max 2 rework attempts — then escalate to human

**On pass:** Run `/commit` and `/create-pr` for the phase.

**Clean up the team** before starting the next phase.

**Repeat for each phase until all phases are delivered.**

### Step 8: Monitor Progress

Track and report progress at each milestone:

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

**Main session acts as team lead using:**
- **tech-lead** agent definition — Instructions for how to orchestrate (followed directly, NOT spawned as subagent)
- **software-architect** agent — Blueprint creation (spawned as Agent Teams teammate)
- **builder** agent — Task implementation (spawned as Agent Teams teammate)
- **manager** agent — Quality validation (spawned as Agent Teams teammate)

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
