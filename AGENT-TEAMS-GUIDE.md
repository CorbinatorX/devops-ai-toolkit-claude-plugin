# Agent Teams Mode Guide

Complete guide for using the agentic-toolkit's Agent Teams orchestration mode — autonomous multi-phase feature delivery with a Tech Lead coordinating specialist teammates.

## What is Agent Teams Mode?

Agent Teams is an experimental Claude Code feature (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) that allows multiple Claude Code instances to work together as a coordinated team. The agentic-toolkit leverages this to provide fully autonomous feature delivery:

- A **Tech Lead** agent acts as team lead, coordinating the full lifecycle
- An **Architect** teammate designs the architecture blueprint
- **Builder** teammates implement tasks in parallel (up to 3)
- A **Reviewer** teammate validates quality with scoring

Each teammate gets its own context window, solving the single-session context limit problem.

## Prerequisites

### Required

- **Claude Code** v2.0.12+ with plugin support
- **agentic-toolkit** plugin installed (v0.5.0+)
- **`.claude/config.json`** in your project (tech stack, conventions)
- **Git** repository with remote configured

### Optional

- **`.claude/techops-config.json`** with `agent_teams` section (see Configuration below)
- **agent-deck** for monitoring dashboard ([github.com/asheshgoplani/agent-deck](https://github.com/asheshgoplani/agent-deck))
- **Work item provider** configured (ADO, Notion, Jira) for status updates
- **Teams webhook** configured for notifications

## Quick Start

### 1. Enable Agent Teams

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Or add to your shell profile (`~/.bashrc`, `~/.zshrc`) for persistence.

### 2. Configure (Optional)

Add an `agent_teams` section to your `.claude/techops-config.json`:

```json
{
  "agent_teams": {
    "enabled": true,
    "review_pass_threshold": 75,
    "max_rework_attempts": 2,
    "max_builder_teammates": 3,
    "require_plan_approval": true,
    "human_approval_gates": [],
    "notifications": {
      "on_phase_complete": true,
      "on_blocked": true,
      "on_orchestration_complete": true
    }
  }
}
```

### 3. Run

```bash
# Natural language — auto-discovers the orchestrate skill
"Orchestrate the full build of a payment processing service"

# Or with a work item
"Deliver work item #25186 end to end"

# Or from an existing blueprint
"Orchestrate from .claude/blueprints/payment-service-blueprint.md"
```

## Configuration Reference

### `agent_teams` Section in `.claude/techops-config.json`

```json
{
  "agent_teams": {
    "enabled": true,
    "review_pass_threshold": 75,
    "review_production_threshold": 85,
    "max_rework_attempts": 2,
    "max_builder_teammates": 3,
    "require_plan_approval": true,
    "human_approval_gates": [],
    "notifications": {
      "on_phase_complete": true,
      "on_blocked": true,
      "on_orchestration_complete": true
    },
    "display_mode": "in-process"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable Agent Teams orchestration (still requires env var) |
| `review_pass_threshold` | integer | `75` | Minimum review score to pass (0-100). Grade B = 75 |
| `review_production_threshold` | integer | `85` | Score indicating production-ready quality. Grade A = 85 |
| `max_rework_attempts` | integer | `2` | Max rework loops before escalating to human |
| `max_builder_teammates` | integer | `3` | Max Builder teammates per phase (1-3 recommended) |
| `require_plan_approval` | boolean | `true` | Require plan approval from Architect before blueprint |
| `human_approval_gates` | array | `[]` | Phase numbers requiring human approval (e.g., `[1, 3]`) |
| `notifications.on_phase_complete` | boolean | `true` | Send Teams notification when a phase completes |
| `notifications.on_blocked` | boolean | `true` | Send Teams notification when blocked on rework |
| `notifications.on_orchestration_complete` | boolean | `true` | Send Teams notification when all phases complete |
| `display_mode` | string | `"in-process"` | `"in-process"` (Shift+Down to cycle) or `"split-pane"` (tmux/iTerm2) |

### Interaction with Other Config Sections

Agent Teams mode works alongside existing config sections:

```json
{
  "worktree": {
    "enabled": true
  },
  "agent_teams": {
    "enabled": true
  },
  "teams": {
    "flow_url": "https://...",
    "team_id": "...",
    "channel_id": "..."
  },
  "work_items": {
    "provider": "notion"
  }
}
```

- **`worktree`** — If enabled, the Tech Lead creates an isolated worktree before starting
- **`teams`** — Used for sending milestone notifications during orchestration
- **`work_items`** — Used for updating work item status at milestones

## How It Works

### Architecture

```
You (user)
  |
  v
Orchestrate Skill (auto-discovers from "orchestrate", "deliver", etc.)
  |
  v
Tech Lead Agent (team lead)
  |
  |-- spawns --> Architect Teammate (blueprint creation, plan approval)
  |-- runs ----> /blueprint-tasks (phase task generation)
  |
  |-- For each phase:
  |     |-- spawns --> Builder Teammate(s) (task implementation, file ownership)
  |     |-- spawns --> Reviewer Teammate (Manager scoring workflow)
  |     |-- runs ----> /commit + /create-pr
  |     '-- cleans up team, spawns fresh for next phase
  |
  v
All phases delivered, work item updated, notification sent
```

### Team-per-Phase Strategy

The Tech Lead creates a **fresh team for each phase**:

1. **Why?** Each teammate gets a clean context window — no bloat from previous phases
2. **How?** After a phase's PR is created, all teammates are shut down. A new team is spawned for the next phase
3. **State?** Progress is persisted to `.claude/tasks/{service}/orchestration-state.json` — survives team cleanup

### Shared Task List

Within a phase, Builder teammates use Agent Teams' shared task list:

1. Tech Lead creates tasks from the phase file (e.g., `phase2.md` tasks 1.1-5.1)
2. Tasks have dependencies — blocked tasks auto-unblock when prerequisites complete
3. Builders **self-claim** tasks as they finish their current work
4. No two builders edit the same files (file ownership assigned in spawn prompts)

### Quality Gates

```
Builder(s) complete tasks
        |
        v
Reviewer scores (6 categories, 100 points)
        |
   Score >= 75? ----YES----> Commit + PR
        |
        NO
        |
   Attempt <= 2? ----YES----> Rework (message builders with specific fixes)
        |
        NO
        |
   Escalate to human (blocked)
```

**Scoring categories** (20 points each):
1. Completeness — all checkboxes and acceptance criteria met
2. Code Quality — clean, readable, no code smells
3. Architecture — follows blueprint patterns
4. Security — input validation, no vulnerabilities
5. Testing — coverage meets target (default 80%)
6. Documentation — code comments, API docs updated

## Workflow Details

### Starting an Orchestration

Three ways to start:

**1. Free-text description:**
```
"Orchestrate a user notification service with email and push support"
```
The Architect designs from scratch.

**2. Work item reference:**
```
"Deliver work item #25186 end to end"
"Orchestrate Notion page https://notion.so/abc123"
```
Requirements pulled from the work item.

**3. Existing blueprint:**
```
"Orchestrate from .claude/blueprints/notification-service-blueprint.md"
```
Skips architecture phase — goes straight to task generation.

### Plan Approval

When `require_plan_approval` is `true` (default), the Architect must get their plan approved before writing the blueprint:

1. Architect proposes a design plan
2. Tech Lead reviews — checks for test strategy and security considerations
3. If plan is missing critical sections, Tech Lead rejects with feedback
4. Architect revises and resubmits
5. Max 2 revision attempts before escalating to human

### Human Approval Gates

Configure specific phases that require your sign-off:

```json
{
  "agent_teams": {
    "human_approval_gates": [1]
  }
}
```

After Phase 1's PR is created, the Tech Lead pauses:

```
Phase 1 complete — human approval required.

PR: https://github.com/org/repo/pull/42
Score: 88/100 (Grade A)

Review the PR and reply:
- "approved" — continue to Phase 2
- "changes needed: {details}" — re-enter rework loop
- "stop" — halt orchestration
```

### Parallel Builders

The Tech Lead decides how many builders to spawn based on task independence:

| Independent Tasks | Builders Spawned |
|-------------------|-----------------|
| 1-5 | 1 |
| 6-10 | 2 |
| 11+ | 3 (max) |

Each builder gets **explicit file ownership** in their spawn prompt:

```
Builder 1: owns src/domain/, src/infrastructure/
Builder 2: owns src/api/, src/middleware/
Builder 3: owns tests/
```

This prevents concurrent edit conflicts.

### Rework Loop

When a review scores below the pass threshold (default 75):

1. Tech Lead parses the Reviewer's findings for specific actionable items
2. Messages the Builder teammate(s) via the Agent Teams mailbox:
   ```
   The reviewer found issues:
   - Input validation missing on POST /payments endpoint (src/api/payments.py:45)
   - Test coverage at 55%, needs 80% (tests/test_payments.py)
   ```
3. Builder fixes the issues and marks rework tasks complete
4. Reviewer re-runs scoring
5. If still failing after 2 rework attempts, escalates to human

## Crash Recovery

### Orchestration State

All progress is persisted to:
```
.claude/tasks/{service-name}/orchestration-state.json
```

This file tracks:
- Which phases are complete (with PR URLs and review scores)
- Current phase progress (tasks completed vs remaining)
- Review attempt count
- A structured continuation prompt for seamless resumption

### Resuming

If your session is interrupted (context limit, network issue, terminal closed):

```bash
/resume-orchestration payment-service
```

This reads the state file and hands off to the Tech Lead, which picks up exactly where it left off — no repeated work.

If you don't remember the service name:
```bash
/resume-orchestration
```
Lists all available orchestrations to resume.

## Monitoring

### In-Terminal

**In-process mode** (default): Press `Shift+Down` to cycle through teammate views.

**Split-pane mode**: Requires tmux or iTerm2. Each teammate gets its own pane.

### With agent-deck

For the best monitoring experience, use [agent-deck](https://github.com/asheshgoplani/agent-deck):

- **Real-time TUI dashboard** showing all teammate status
- **Status filtering**: `!` running, `@` waiting, `#` idle, `$` error
- **Fuzzy search** across sessions with `/`
- **Conductor mode**: Tech Lead as a persistent orchestrator session
- **Remote notifications**: Slack/Telegram alerts for unattended runs

### Teams Notifications

When Teams is configured, you get notifications at:
- Phase completion (score, PR link)
- Orchestration blocked (needs human intervention)
- All phases complete (summary)

## Without Agent Teams

If you don't have Agent Teams enabled (or prefer manual control), the `orchestrate` skill falls back to guiding you through the sequential workflow:

```
Sequential Workflow (no Agent Teams):

1. /blueprint {description}         — Create architecture
2. /blueprint-tasks {blueprint}     — Generate phase tasks
3. /implement-task {service}/phase1#1.1  — Implement each task
4. /review-task {service}/phase1         — Review phase
5. /commit                              — Commit phase
6. /create-pr                           — Create phase PR
7. [Repeat 3-6 for each phase]
```

The skill tracks your progress and suggests the next command after each step.

## Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| No session resumption for teammates | If lead dies, teammates are lost | State file persists progress; resume creates fresh team |
| No nested teams | Teammates can't spawn sub-teams | Each teammate works independently |
| One team per session | Must clean up before next phase | Team-per-phase strategy aligns with this |
| Lead is fixed | Can't promote a teammate to lead | State file + resume command for new lead session |
| Permissions locked at spawn | All teammates inherit lead's mode | Set appropriate permissions before starting |
| File conflicts possible | Two teammates editing same file | File ownership assignments in spawn prompts |
| Token cost scales linearly | Each teammate = full Claude instance | Max 3 builders; 5-6 tasks per teammate |

## Cost Considerations

Each teammate is a full Claude Code instance. A typical orchestration for a 4-phase feature:

| Phase | Teammates | Sessions |
|-------|-----------|----------|
| Architecture | 1 Architect | 1 |
| Phase 1 | 2 Builders + 1 Reviewer | 3 |
| Phase 2 | 2 Builders + 1 Reviewer | 3 |
| Phase 3 | 1 Builder + 1 Reviewer | 2 |
| Phase 4 | 1 Builder + 1 Reviewer | 2 |
| **Total** | | **~12 sessions** (+ lead) |

Plus the Tech Lead session running throughout. Budget accordingly.

**Tips to reduce cost:**
- Use `max_builder_teammates: 1` for smaller phases
- Set `human_approval_gates: [1]` to review architecture before committing to full build
- Use an existing blueprint to skip the Architect session

## Examples

### Example 1: Full Autonomous Delivery

```
> Orchestrate a REST API for user notifications with email and SMS channels

Orchestration Plan: notification-service

Input: Free-text description
Branch: feature/notification-service
Tech Stack: Python / FastAPI (from config)

Workflow:
1. Architect designs blueprint (with plan approval)
2. Blueprint converted to phase tasks
3. For each phase: build -> review -> PR
4. Repeat until all phases delivered

Proceed with orchestration? yes

[Tech Lead spawns Architect...]
[Architect plan approved]
[Blueprint created: .claude/blueprints/notification-service-blueprint.md]
[4 phases generated]
[Phase 1: 2 builders spawned, 8 tasks...]
[Phase 1: Review score 91/100 (A), PR #43 created]
[Phase 2: 2 builders spawned, 10 tasks...]
...
```

### Example 2: From Work Item

```
> Deliver Notion page https://notion.so/31cc00e6855a812e9801c3a39219fac4 end to end
```

### Example 3: Resume After Interruption

```
> /resume-orchestration notification-service

Resuming Orchestration: notification-service

Blueprint: .claude/blueprints/notification-service-blueprint.md
Branch: feature/notification-service
Progress: Phase 3/4
Status: in_progress

Completed Phases:
| Phase | Score | Grade | PR  |
|-------|-------|-------|-----|
| 1     | 91    | A     | #43 |
| 2     | 82    | B     | #44 |

Current Phase: Phase 3
Status: in_progress
Tasks: 4/7 complete

Resume Action: Spawn builders for remaining tasks 4.1, 5.1, 5.2
```

## Troubleshooting

### "Agent Teams not enabled"
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Teammate spawn fails
- Check system resources (each teammate is a process)
- Try reducing `max_builder_teammates` to 1
- Check Claude Code version supports Agent Teams

### State file corrupted
```bash
# View the state
cat .claude/tasks/{service}/orchestration-state.json | jq .

# Delete and start fresh if needed
rm .claude/tasks/{service}/orchestration-state.json
```

### Review keeps failing
- Check the status report: `.claude/tasks/{service}/phase{N}_status.md`
- Lower `review_pass_threshold` if appropriate for your project
- Increase `max_rework_attempts` (default 2)
- Or fix the issues manually and resume

### High token usage
- Reduce `max_builder_teammates` to 1
- Add `human_approval_gates: [1]` to validate architecture early
- Use existing blueprints when possible

## Related Files

| File | Purpose |
|------|---------|
| `agents/workflow/tech-lead.md` | Tech Lead agent definition |
| `skills/orchestrate/SKILL.md` | Orchestration skill with auto-discover |
| `commands/workflow/resume-orchestration.md` | Resume command |
| `shared/orchestration/README.md` | State schema, hooks, patterns |
| `ADOPTION.md` | General plugin adoption guide |

## Version

- **Plugin Version**: 0.5.0
- **Agent Teams Support**: Experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)
- **Last Updated**: 2026-03-07
