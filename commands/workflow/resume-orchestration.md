# Resume Orchestration Command

Resume a Tech Lead orchestration from its last checkpoint, using the persisted orchestration state file.

## Command Format

```bash
/resume-orchestration [service-name]
```

**Examples:**
```bash
/resume-orchestration payment-service
/resume-orchestration user-profile
/resume-orchestration notification-system
```

**If no service name provided:** scan `.claude/tasks/` for directories containing `orchestration-state.json` and list available orchestrations to resume.

## Step-by-Step Process

### 1. Locate State File

```bash
# If service name provided
STATE_FILE=".claude/tasks/{service-name}/orchestration-state.json"

# If no service name, scan for available orchestrations
find .claude/tasks -name "orchestration-state.json" -type f
```

**If no state file found:**
```
No orchestration state found.

To start a new orchestration, use one of:
- "Orchestrate the full build of {feature}" (auto-discovers Tech Lead)
- Invoke the Tech Lead agent directly with a feature description
```

**If multiple state files found and no service name provided:**
```
Multiple orchestrations found:

1. payment-service — Phase 2/4 in progress (score: 88 on phase 1)
2. user-profile — Phase 1/3 blocked (rework limit reached)

Specify which to resume:
  /resume-orchestration payment-service
```

### 2. Read and Validate State

Read the state file and validate:

```bash
# Read JSON
state=$(cat .claude/tasks/{service-name}/orchestration-state.json)
```

**Validation checks:**
- [ ] File is valid JSON
- [ ] `version` field is `"1.0"`
- [ ] `feature` field matches service name
- [ ] `status` is not `"completed"` (nothing to resume)
- [ ] `current_phase` <= `total_phases`
- [ ] Required fields present: `feature`, `status`, `blueprint_path`

**If validation fails:**
```
Orchestration state file is invalid.

Path: .claude/tasks/{service-name}/orchestration-state.json
Error: {specific validation error}

Options:
1. Delete the state file and start fresh
2. Manually fix the JSON and retry
```

### 3. Check Terminal States

**If status is `"completed"`:**
```
Orchestration for {feature} is already complete.

Phases delivered: {N}
PRs created: {list of PR URLs}

Nothing to resume. To re-run, delete the state file:
  rm .claude/tasks/{service-name}/orchestration-state.json
```

**If status is `"failed"`:**
```
Orchestration for {feature} previously failed.

Last error context: {continuation_prompt or status details}

Options:
1. Fix the issue and run /resume-orchestration again
2. Delete state file and start fresh
```

**If status is `"blocked"`:**
```
Orchestration for {feature} is blocked waiting for human intervention.

Phase {N} failed review after 2 rework attempts.
Latest score: {score}/100 (Grade {grade})
Status report: .claude/tasks/{service-name}/phase{N}_status.md

Review the status report and decide:
1. Manually fix the issues, then update phase status to "in_progress" and resume
2. Accept the current state and advance: update phase status to "completed"
3. Abandon this phase and skip to next
```

### 4. Display Resume Summary

Show the user what will be resumed:

```markdown
## Resuming Orchestration: {feature}

**Blueprint:** {blueprint_path}
**Branch:** {branch_name}
**Progress:** Phase {current_phase}/{total_phases}
**Status:** {status}

### Completed Phases
| Phase | Score | Grade | PR |
|-------|-------|-------|----|
| Phase 1 | 88/100 | A | #42 |

### Current Phase: Phase {N}
**Status:** {phase_status}
**Tasks:** {completed}/{total} complete
**Review Attempts:** {attempts}/3

### Resume Action
{description of what will happen next}
```

### 5. Read Continuation Prompt

If `continuation_prompt` is set in the state file, use it as the primary instruction for resumption:

```markdown
## Continuation Context

{continuation_prompt content}
```

The continuation prompt contains structured instructions from the previous Tech Lead session describing exactly where to pick up.

### 6. Check Prerequisites

Before resuming, verify:

```bash
# Check Agent Teams is enabled
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

# Check blueprint exists
test -f {blueprint_path}

# Check phase files exist
ls .claude/tasks/{service-name}/phase*.md

# Check branch exists
git rev-parse --verify {branch_name}
```

**If Agent Teams not enabled:**
```
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not enabled.

The orchestration was started with Agent Teams. To resume:
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

Alternatively, continue manually using sequential commands:
  /implement-task {service-name}/phase{N}#{next-task}
```

**If branch doesn't exist locally:**
```bash
# Try to checkout from remote
git checkout {branch_name} 2>/dev/null || git checkout -b {branch_name} origin/{branch_name}
```

### 7. Determine Resume Point

Based on the orchestration status and current phase status:

| Top-Level Status | Phase Status | Resume Action |
|-----------------|--------------|---------------|
| `initializing` | — | Start from scratch: spawn Architect |
| `architecture` | — | Re-spawn Architect teammate |
| `task_generation` | — | Re-run `/blueprint-tasks` |
| `in_progress` | `pending` | Start phase: create task list, spawn Builders |
| `in_progress` | `in_progress` | Spawn Builders for remaining tasks only |
| `in_progress` | `review` | Spawn Reviewer teammate |
| `in_progress` | `rework` | Spawn Builders with rework items |
| `in_progress` | `completed` | Advance to next phase |

**Reference:** See `.claude/shared/orchestration/README.md` for the full resume algorithm.

### 8. Invoke Tech Lead

Hand off to the Tech Lead agent with resume context:

```markdown
Resume the Tech Lead orchestration for {feature}.

State file: .claude/tasks/{service-name}/orchestration-state.json
Blueprint: {blueprint_path}
Branch: {branch_name}
Current phase: {current_phase}/{total_phases}
Phase status: {current_phase_status}

{continuation_prompt if available}

Resume from the current checkpoint. Do not repeat completed work.
Read the orchestration state file for full context.
```

The Tech Lead agent reads the state file and continues from the exact checkpoint.

## Error Handling

### State File Not Found

```
No orchestration state found for "{service-name}".

Searched: .claude/tasks/{service-name}/orchestration-state.json

Available orchestrations:
{list from scanning .claude/tasks/*/orchestration-state.json}

If none exist, start a new orchestration using the Tech Lead agent.
```

### Blueprint Missing

```
Blueprint file not found: {blueprint_path}

The orchestration state references a blueprint that no longer exists.

Options:
1. Re-create the blueprint: /blueprint {feature-description}
2. Update the state file with the correct path
3. Delete state and start fresh
```

### Phase Files Missing

```
Phase task files not found for {service-name}.

Expected: .claude/tasks/{service-name}/phase{N}.md

Options:
1. Re-generate from blueprint: /blueprint-tasks {blueprint_path}
2. Check if files were moved or renamed
3. Delete state and start fresh
```

### Branch Conflict

```
Branch {branch_name} has diverged from the expected state.

The branch may have been modified outside of orchestration.

Options:
1. Continue on the current branch state
2. Reset to the last known good commit
3. Create a new branch and update the state file
```

## Integration with Workflow

```
1. /blueprint              - Architect creates architecture
2. /blueprint-tasks        - Convert to phase-based tasks
3. [Tech Lead orchestrates implementation automatically]
4. [If Tech Lead session interrupted...]
5. /resume-orchestration   - Resume from checkpoint  <-- YOU ARE HERE
6. [Tech Lead continues from last checkpoint]
```

## Notes

- The resume command is a thin wrapper — it reads state and hands off to the Tech Lead agent
- All intelligence about what to do next lives in the Tech Lead agent and the state file
- The continuation_prompt in the state file is the most important field for seamless resumption
- Multiple orchestrations can exist simultaneously (different service names)
- Resume is idempotent — running it on a completed orchestration is a no-op
- Branch checkout is automatic — no need to manually switch branches before resuming
