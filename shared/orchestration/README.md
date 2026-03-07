# Orchestration State Management

Patterns and schemas for persisting orchestration state during multi-phase feature delivery with the Tech Lead agent.

## Overview

The orchestration state file is the **single source of truth** for multi-phase delivery progress. It enables:
- **Crash recovery** — resume from last checkpoint if the Tech Lead session is interrupted
- **Progress tracking** — know which phases are complete, in progress, or pending
- **Audit trail** — record review scores, PR URLs, and rework history per phase
- **Continuation prompts** — structured prompts for seamless session resumption

## State File Location

```
.claude/tasks/{service-name}/orchestration-state.json
```

**Examples:**
- `.claude/tasks/payment-service/orchestration-state.json`
- `.claude/tasks/user-profile/orchestration-state.json`
- `.claude/tasks/notification-system/orchestration-state.json`

## Schema

```json
{
  "version": "1.0",
  "feature": "payment-service",
  "input_source": {
    "type": "work-item",
    "reference": "25186",
    "provider": "azure-devops",
    "url": "https://dev.azure.com/org/project/_workitems/edit/25186"
  },
  "blueprint_path": ".claude/blueprints/payment-service-blueprint.md",
  "branch_name": "feature/25186-payment-service",
  "total_phases": 4,
  "current_phase": 2,
  "status": "in_progress",
  "phase_status": {
    "phase1": {
      "status": "completed",
      "started_at": "2026-03-07T10:00:00Z",
      "completed_at": "2026-03-07T11:30:00Z",
      "pr_url": "https://github.com/org/repo/pull/42",
      "pr_number": 42,
      "review_score": 88,
      "review_grade": "A",
      "review_attempts": 1,
      "tasks_total": 8,
      "tasks_completed": 8,
      "teammates_spawned": 2
    },
    "phase2": {
      "status": "in_progress",
      "started_at": "2026-03-07T11:35:00Z",
      "completed_at": null,
      "pr_url": null,
      "pr_number": null,
      "review_score": null,
      "review_grade": null,
      "review_attempts": 0,
      "tasks_total": 10,
      "tasks_completed": 4,
      "tasks_completed_ids": ["1.1", "1.2", "2.1", "2.2"],
      "tasks_remaining_ids": ["2.3", "3.1", "3.2", "4.1", "4.2", "5.1"],
      "teammates_spawned": 2,
      "current_team": "payment-phase2"
    }
  },
  "review_history": [
    {
      "phase": "phase1",
      "attempt": 1,
      "score": 88,
      "grade": "A",
      "status_file": ".claude/tasks/payment-service/phase1_status.md",
      "timestamp": "2026-03-07T11:25:00Z"
    }
  ],
  "continuation_prompt": null,
  "created_at": "2026-03-07T09:45:00Z",
  "updated_at": "2026-03-07T12:00:00Z"
}
```

## Field Reference

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version (`"1.0"`) |
| `feature` | string | Yes | Service or feature name (used for directory naming) |
| `input_source` | object | Yes | How the orchestration was initiated |
| `blueprint_path` | string | Yes | Path to the architecture blueprint |
| `branch_name` | string | Yes | Git branch for this feature |
| `total_phases` | integer | Yes | Total number of implementation phases |
| `current_phase` | integer | Yes | Currently active phase number (1-indexed) |
| `status` | enum | Yes | Overall orchestration status |
| `phase_status` | object | Yes | Per-phase status details (keyed by `phase{N}`) |
| `review_history` | array | No | Chronological log of all review attempts |
| `continuation_prompt` | string | null | No | Structured resume prompt (set before session exit) |
| `created_at` | string | Yes | ISO 8601 timestamp of orchestration start |
| `updated_at` | string | Yes | ISO 8601 timestamp of last state update |

### input_source

| Field | Type | Description |
|-------|------|-------------|
| `type` | enum | `"work-item"`, `"blueprint"`, or `"free-text"` |
| `reference` | string | Work item ID, blueprint path, or feature description |
| `provider` | string | null | Work item provider (`"azure-devops"`, `"notion"`, `"jira"`) |
| `url` | string | null | URL to the source (work item URL, Notion page, etc.) |

### status (Top-Level)

| Value | Description |
|-------|-------------|
| `initializing` | State file created, awaiting architecture |
| `architecture` | Architect teammate spawned, blueprint in progress |
| `task_generation` | Blueprint complete, generating phase task files |
| `in_progress` | Actively delivering phases |
| `blocked` | Waiting for human intervention (rework exhausted) |
| `completed` | All phases delivered successfully |
| `failed` | Unrecoverable error |

### phase_status.phase{N}

| Field | Type | Description |
|-------|------|-------------|
| `status` | enum | `"pending"`, `"in_progress"`, `"review"`, `"rework"`, `"completed"`, `"blocked"` |
| `started_at` | string | null | ISO 8601 start timestamp |
| `completed_at` | string | null | ISO 8601 completion timestamp |
| `pr_url` | string | null | GitHub PR URL |
| `pr_number` | integer | null | GitHub PR number |
| `review_score` | integer | null | Final review score (0-100) |
| `review_grade` | string | null | Letter grade (S/A/B/C/D/F) |
| `review_attempts` | integer | Number of review attempts (0 = not yet reviewed) |
| `tasks_total` | integer | Total tasks in this phase |
| `tasks_completed` | integer | Number of completed tasks |
| `tasks_completed_ids` | array | null | List of completed task IDs (e.g., `["1.1", "1.2"]`) |
| `tasks_remaining_ids` | array | null | List of remaining task IDs |
| `teammates_spawned` | integer | Number of Builder teammates used |
| `current_team` | string | null | Agent Teams team name (for active phases) |

### review_history entry

| Field | Type | Description |
|-------|------|-------------|
| `phase` | string | Phase key (e.g., `"phase1"`) |
| `attempt` | integer | Review attempt number (1-indexed) |
| `score` | integer | Review score (0-100) |
| `grade` | string | Letter grade |
| `status_file` | string | Path to the Manager's status report |
| `timestamp` | string | ISO 8601 timestamp |

## State Transitions

```
initializing
    |
    v
architecture  -->  (architect spawned, plan approval, blueprint written)
    |
    v
task_generation  -->  (/blueprint-tasks run, phase files created)
    |
    v
in_progress  -->  (iterating through phases)
    |               |
    |               v
    |           phase.in_progress  -->  (builders working)
    |               |
    |               v
    |           phase.review  -->  (reviewer scoring)
    |               |          \
    |               |           v
    |               |       phase.rework  -->  (builders fixing, max 2 attempts)
    |               |           |          \
    |               |           |           v
    |               |           |       phase.blocked  -->  (human intervention needed)
    |               |           |                               |
    |               v           v                               v
    |           phase.completed                             blocked (top-level)
    |               |
    |               v
    |           [next phase or completion]
    |
    v
completed  -->  (all phases delivered)
```

## Continuation Prompt Generation

When the Tech Lead approaches context limits or needs to exit, it generates a structured continuation prompt:

### Algorithm

```markdown
generate_continuation_prompt(state):

  1. List completed phases with PR URLs and scores
  2. Describe current phase progress (tasks done vs remaining)
  3. Note any pending review feedback or rework items
  4. Specify exact next action to take
  5. Write to state.continuation_prompt
  6. Save state file
```

### Example Continuation Prompts

**Mid-phase:**
```
Resume orchestrating payment-service.
Phase 1 complete (PR #42, score 88/100).
Phase 2 in progress - tasks 1.1, 1.2, 2.1, 2.2 done.
Spawn builders for remaining tasks 2.3, 3.1, 3.2, 4.1, 4.2, 5.1.
Blueprint: .claude/blueprints/payment-service-blueprint.md
Phase file: .claude/tasks/payment-service/phase2.md
```

**During review:**
```
Resume orchestrating payment-service.
Phase 1 complete (PR #42, score 88/100).
Phase 2 implementation complete. Spawn reviewer to run Manager scoring workflow.
Blueprint: .claude/blueprints/payment-service-blueprint.md
Phase file: .claude/tasks/payment-service/phase2.md
```

**During rework:**
```
Resume orchestrating payment-service.
Phase 1 complete (PR #42, score 88/100).
Phase 2 review attempt 1 scored 62/100 (Grade D).
Rework needed: input validation missing on POST /payments, test coverage at 55%.
Spawn builder to fix rework items, then re-review. This is rework attempt 1 of 2.
```

## Resume Algorithm

The `/resume-orchestration` command uses this algorithm:

```markdown
resume_orchestration(state_file_path):

  1. Read and validate state file
  2. Check state.status:
     - "completed": Report "Already complete" and exit
     - "failed": Report error and ask user how to proceed
     - "blocked": Report blocking issues and ask user how to proceed
  3. Read state.continuation_prompt if present
  4. Determine resume point:
     - status == "initializing": Start from scratch
     - status == "architecture": Re-spawn architect
     - status == "task_generation": Re-run /blueprint-tasks
     - status == "in_progress": Resume at current_phase
  5. For current_phase:
     - phase.status == "pending": Start phase from beginning
     - phase.status == "in_progress": Spawn builders for remaining tasks
     - phase.status == "review": Spawn reviewer
     - phase.status == "rework": Spawn builders with rework items
     - phase.status == "completed": Advance to next phase
     - phase.status == "blocked": Report and ask user
  6. Continue normal Tech Lead workflow from resume point
```

## State File Operations

### Creating State

```markdown
When Tech Lead starts orchestration:

1. Create directory: mkdir -p .claude/tasks/{service-name}
2. Write initial state:
   {
     "version": "1.0",
     "feature": "{service-name}",
     "input_source": { ... },
     "blueprint_path": null,
     "branch_name": null,
     "total_phases": 0,
     "current_phase": 0,
     "status": "initializing",
     "phase_status": {},
     "review_history": [],
     "continuation_prompt": null,
     "created_at": "{now}",
     "updated_at": "{now}"
   }
```

### Updating State

```markdown
After each significant event, update the state file:

Events that trigger state updates:
- Blueprint created (set blueprint_path, status -> "task_generation")
- Phase tasks generated (set total_phases, initialize phase_status entries)
- Phase started (phase.status -> "in_progress", set started_at)
- Task completed (increment tasks_completed, update tasks_completed_ids)
- Review started (phase.status -> "review")
- Review completed (set review_score, review_grade, add to review_history)
- Rework started (phase.status -> "rework", increment review_attempts)
- Phase completed (phase.status -> "completed", set pr_url, completed_at)
- Orchestration completed (status -> "completed")
- Blocked (status -> "blocked" or phase.status -> "blocked")

Always update "updated_at" on every write.
```

### Reading State

```markdown
Before resuming:

1. Read the JSON file
2. Validate version field matches "1.0"
3. Validate required fields are present
4. Check for data consistency:
   - current_phase <= total_phases
   - tasks_completed <= tasks_total for each phase
   - review_attempts <= 3 (max 2 reworks + initial review)
```

## Integration with Skills

### Reference in Tech Lead Agent

```markdown
# In agents/workflow/tech-lead.md

## State Management

This agent uses orchestration state for crash recovery.

**Reference**: See `.claude/shared/orchestration/README.md` for:
- State file schema
- State transition rules
- Continuation prompt generation
- Resume algorithm
```

### Reference in Resume Command

```markdown
# In commands/workflow/resume-orchestration.md

## State Reading

Read and validate the orchestration state file.

**Reference**: See `.claude/shared/orchestration/README.md` for:
- State file location pattern
- Field validation rules
- Resume algorithm
```

## Hook Patterns

The Tech Lead configures Agent Teams hooks for automated quality enforcement during each phase.

### TaskCompleted Hook

Validates work before accepting task completion:

```markdown
TaskCompleted hook algorithm:

  1. Identify the task that was marked complete
  2. Run build command from .claude/config.json
  3. Run test command from .claude/config.json
  4. If build or tests fail:
     - Reject task completion
     - Message teammate with failure output
     - Do NOT update orchestration state
  5. If build and tests pass:
     - Accept task completion
     - Update state: increment tasks_completed, add to tasks_completed_ids
     - Remove from tasks_remaining_ids
```

### TeammateIdle Hook

Checks teammate status when idle:

```markdown
TeammateIdle hook algorithm:

  1. Check shared task list for unclaimed tasks with met dependencies
  2. If unclaimed tasks exist:
     - Nudge teammate to claim next task
  3. If no unclaimed tasks and teammate's work is done:
     - Verify acceptance criteria from phase file
     - Record teammate as finished
  4. If all teammates finished:
     - Transition phase to "review" status
     - Spawn Reviewer teammate
```

## Work Item Status Update Patterns

When a work item provider is configured, the Tech Lead updates status at milestones.

### Update Algorithm

```markdown
update_work_item_status(state, milestone, details):

  1. Check if input_source.type == "work-item"
     - If not, skip (no work item to update)
  2. Read provider from input_source.provider
  3. Based on provider, call appropriate MCP tool:
     - azure-devops: mcp__azure-devops__wit_update_work_item + wit_add_work_item_comment
     - notion: mcp__notion__notion-update-page + notion-create-comment
     - jira: Jira MCP update + comment tools
  4. On failure: Log warning, continue (non-blocking)
```

### Milestone → Update Mapping

```json
{
  "orchestration_started": {
    "state_change": "active",
    "comment": "Feature picked up for autonomous delivery via Tech Lead orchestration"
  },
  "architecture_complete": {
    "state_change": null,
    "comment": "Architecture blueprint created: {blueprint_path}"
  },
  "phase_review_passed": {
    "state_change": null,
    "comment": "Phase {N}/{total} complete — Score: {score}/100 ({grade}), PR: {pr_url}"
  },
  "phase_blocked": {
    "state_change": null,
    "comment": "Phase {N} blocked after 2 rework attempts — human review needed"
  },
  "orchestration_complete": {
    "state_change": "resolved",
    "comment": "Feature delivery complete — {total_phases} phases, {pr_count} PRs created"
  }
}
```

**Reference:** See `.claude/shared/work-items/interface.md` for provider-specific field mappings and state names.

## Notification Patterns

### Teams Notification Integration

When Teams is configured in `.claude/techops-config.json`, send notifications at milestones:

```markdown
send_teams_notification(milestone, details):

  1. Read teams config from .claude/techops-config.json:
     - flow_url, team_id, channel_id
  2. If config missing, skip silently
  3. Build message content based on milestone type
  4. POST to flow_url:
     {
       "action": "post",
       "teamId": "{team_id}",
       "channelId": "{channel_id}",
       "content": "{message}"
     }
  5. On failure: Log warning, continue (non-blocking)
```

### Notification Milestones

| Milestone | Notify? | Content |
|-----------|---------|---------|
| Orchestration started | No | — |
| Architecture complete | No | — |
| Phase review passed | Yes | Phase N complete, score, PR link |
| Phase blocked | Yes | Blocked, needs human intervention |
| Orchestration complete | Yes | All phases delivered, summary |

## Orchestration Configuration Schema

Optional configuration in `.claude/config.json` under the `orchestration` key:

```json
{
  "orchestration": {
    "review_pass_threshold": 75,
    "review_production_threshold": 85,
    "max_rework_attempts": 2,
    "max_builder_teammates": 3,
    "require_plan_approval": true,
    "human_approval_gates": []
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `review_pass_threshold` | integer | 75 | Minimum review score to pass (0-100) |
| `review_production_threshold` | integer | 85 | Score indicating production-ready quality |
| `max_rework_attempts` | integer | 2 | Max rework loops before escalating to human |
| `max_builder_teammates` | integer | 3 | Max Builder teammates spawned per phase |
| `require_plan_approval` | boolean | true | Require Architect plan approval before blueprint |
| `human_approval_gates` | array | [] | Phase numbers requiring human approval |

When these fields are absent, defaults are used. The Tech Lead reads this configuration at startup and applies it throughout the orchestration.

## Notes

- State file is JSON for easy reading and writing by Claude Code
- All timestamps use ISO 8601 format with timezone (UTC)
- State file survives teammate loss (teammates don't write to it — only the Tech Lead does)
- The continuation_prompt field is the primary mechanism for cross-session resumption
- Review history provides a complete audit trail of quality gate outcomes
- Phase status includes both summary counts and detailed task ID lists for precise resumption
- Version field enables future schema migrations
