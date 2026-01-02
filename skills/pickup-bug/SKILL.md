---
name: pickup-bug
description: Pick up TechOps Bug work items from Azure DevOps, assign to developer, create git branch, investigate, plan, and implement the fix
allowed-tools: Read, Write, Bash, Grep, Glob, Edit
auto-discover:
  - "pick up bug"
  - "pickup bug"
  - "bug #"
  - "fix bug"
  - "work on bug"
---

# Pickup Bug Skill

## Purpose

Complete workflow for picking up "TechOps Bug" work items from Azure DevOps. Handles assignment, branch creation, Teams notification, investigation, fix planning, implementation, and testing in a 12-step process.

This Skill integrates with Azure DevOps for work item management and follows {Product} git branching conventions.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "Pick up bug {number}"
- "Work on bug #{id}"
- "Fix bug {number}"
- "I need to fix bug {id}"
- "Pickup bug {number}"

## Example Invocations

```
"Pick up bug 25123"
"Work on bug #25200"
"Fix bug 25099"
"I need to work on bug 25150"
```

## Shared Modules

This Skill uses shared helper modules for common patterns:

**Azure DevOps** (`.claude/shared/azure-devops/`):
- Work item retrieval, updates, comments
- Identity resolution for assignments
- Field validation
- **Project**: ERM
- **Area Path**: ERM\\Devops
- **Iteration Path**: ERM\\dops-backlog

**Git** (`.claude/shared/git/`):
- Branch slug generation from bug title (7-step algorithm)
- Branch creation or checkout
- Branch naming pattern: `bug/{id}-{slug}`

**Teams** (`.claude/shared/teams/`):
- Logic App for post/reply operations
- Config: `.claude/techops-config.json` (flow_url, team_id, channel_id)
- Reply to Teams threads when work items have `TeamsChannelMessageId`

See shared module READMEs for detailed patterns and examples.

## Workflow (12 Steps)

### Step 1: Retrieve Work Item Details

Use `mcp__azure-devops__wit_get_work_item` to fetch bug details.

**Parameters:**
```json
{
  "project": "ERM",
  "id": work_item_id,
  "expand": "relations"
}
```

**Extract:**
- Work Item Type (MUST be "TechOps Bug")
- Title, State, AssignedTo, Description
- ReproSteps, Severity (1-4)
- CreatedDate, ChangedDate
- Related work items
- Custom.TeamsChannelMessageId (for Teams thread reply)

**Validation:**
- If type is NOT "TechOps Bug", show error and stop
- If work item not found, show error

**Parse environment** from ReproSteps: Extract "Environment: {value}" line.

### Step 2: Display Bug Context

Present formatted summary:

```markdown
## Bug #{work_item_id}: {title}

**Current State:** {state}
**Assigned To:** {assignee or "Unassigned"}
**Severity:** {severity} (1-Critical, 2-High, 3-Medium, 4-Low)
**Environment:** {environment}
**Reported:** {created_date}
**Last Updated:** {changed_date}

### Description
{description}

### Reproduction Steps
{repro_steps}

### Related Work Items
- #{id}: {title} ({state})
```

### Step 3: Interactive Context Clarification

Engage in natural conversation to gather additional context:
- "Are there any additional details about this bug?"
- "Do you have specific concerns or areas to focus on?"
- "Is there context from recent changes/deployments?"

Allow user to provide extra information or say "no"/"none"/"proceed" to continue.

**Store any additional context** for use in the fix plan.

### Step 4: Get User Identity for Assignment

Use `mcp__azure-devops__core_get_identity_ids`:

**Parameters:**
```json
{
  "searchFilter": "Corbin Taylor"
}
```

**Store the identity ID** for assignment update.

**Reference**: See `.claude/shared/azure-devops/README.md` for identity resolution patterns.

### Step 5: Update Work Item State and Assignment

Use `mcp__azure-devops__wit_update_work_item`:

**Parameters:**
```json
{
  "id": work_item_id,
  "updates": [
    {
      "op": "add",
      "path": "/fields/System.State",
      "value": "In Progress"
    },
    {
      "op": "add",
      "path": "/fields/System.AssignedTo",
      "value": "{identity_id from Step 4}"
    }
  ]
}
```

**IMPORTANT:**
- Always reassign to Corbin Taylor, even if already assigned
- No warning or confirmation required for reassignment
- Store previous assignee name for comment (Step 6)

**Reference**: See `.claude/shared/azure-devops/README.md` for work item update patterns.

### Step 6: Add Work Item Comment

Use `mcp__azure-devops__wit_add_work_item_comment`:

**Parameters:**
```json
{
  "project": "ERM",
  "workItemId": work_item_id,
  "comment": "{comment_text}",
  "format": "html"
}
```

**Comment text:**
- If unassigned or already assigned to Corbin:
  ```
  Bug picked up by Corbin Taylor for investigation and fix via Claude Code /pickup-bug command
  ```
- If assigned to someone else:
  ```
  Bug picked up by Corbin Taylor for investigation and fix via Claude Code /pickup-bug command (previously assigned to {previous_assignee})
  ```

### Step 7: Notify Teams Thread (Optional)

If the work item has a `Custom.TeamsChannelMessageId` field populated, reply to the Teams thread to notify the team.

**Prerequisites:**
- Read `.claude/techops-config.json` from the consuming repo
- Extract: `teams.flow_url`, `teams.team_id`, `teams.channel_id`

**Skip if:**
- `Custom.TeamsChannelMessageId` is empty or not set
- Config file doesn't exist or is missing Teams config

**HTTP Request:**

```bash
curl -X POST "{flow_url}" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "reply",
    "teamId": "{team_id}",
    "channelId": "{channel_id}",
    "messageId": "{TeamsChannelMessageId from Step 1}",
    "content": "🔧 **Bug Picked Up**\n\nBug #{work_item_id} has been picked up by **Corbin Taylor** for investigation.\n\n**Branch:** `bug/{work_item_id}-{slug}`\n\n_via Claude Code /pickup-bug command_"
  }'
```

**On Success:** Log that Teams thread was notified.

**On Failure:** Log warning but continue workflow (Teams notification is non-blocking).

**Reference**: See `.claude/shared/teams/README.md` for Logic App patterns.

### Step 8: Create Git Branch

Generate branch name: `bug/{work_item_id}-{title-slug}`

**Branch slug generation** (7-step algorithm from `.claude/shared/git/README.md`):
1. Convert title to lowercase
2. Replace special chars: `'` → remove, `/\` → `-`, `&` → `and`, `+` → `plus`
3. Replace spaces/underscores with hyphens
4. Remove non-alphanumeric except hyphens
5. Collapse multiple hyphens to single hyphen
6. Trim hyphens from start/end
7. Truncate to 50 chars at word boundary (break at last hyphen after position 30)

**Examples:**
- "Feature flags don't display" → `bug/25123-feature-flags-dont-display`
- "P95/P99 response times not displaying" → `bug/25099-p95-p99-response-times-not-displaying`

#### Check for Worktree Mode

First, check if worktree mode is enabled in `.claude/techops-config.json`:

```bash
worktree_enabled=$(cat .claude/techops-config.json 2>/dev/null | jq -r '.worktree.enabled // false')
```

#### Option A: Worktree Mode (if enabled)

If `worktree.enabled` is `true`, create an isolated worktree for this bug fix:

1. **Get repository from work item**: Extract `Custom.Repository` field from Step 1
2. **Parse repository name**: Extract repo name from org/repo or URL format
3. **Create worktree** using algorithm from `.claude/shared/worktree/README.md`
4. **Change working directory** to worktree path
5. **Continue implementation** in isolated environment

```bash
if [ "$worktree_enabled" = "true" ]; then
    # Get repository from work item
    repository_field="{work_item.Custom.Repository}"

    # Parse repo name
    repo_name=$(echo "$repository_field" | sed 's|.*/||' | sed 's|\.git$||')

    # Build paths
    user=$(whoami)
    base_path="/home/${user}/workspace/github/agent-worktrees"
    repo_cache="/home/${user}/.claude/repos"
    worktree_path="${base_path}/${repo_name}-{work_item_id}"
    cached_repo="${repo_cache}/${repo_name}.git"
    branch_name="bug/{work_item_id}-{slug}"

    # Create directories
    mkdir -p "$base_path" "$repo_cache"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        cd "$worktree_path"
        echo "Using existing worktree: $worktree_path"
    else
        # Ensure bare repo cache exists
        if [ ! -d "$cached_repo" ]; then
            repo_url="git@github.com:${repository_field}.git"
            git clone --bare "$repo_url" "$cached_repo"
        else
            git -C "$cached_repo" fetch --all --prune
        fi

        # Fetch latest main
        git -C "$cached_repo" fetch origin main:main 2>/dev/null || \
            git -C "$cached_repo" fetch origin master:master

        # Create worktree with new branch
        git -C "$cached_repo" worktree add -b "$branch_name" "$worktree_path" main 2>/dev/null || \
            git -C "$cached_repo" worktree add -b "$branch_name" "$worktree_path" master

        cd "$worktree_path"
        git push -u origin "$branch_name" 2>/dev/null || true
    fi
fi
```

**Output (worktree mode):**

```markdown
## Worktree Created

Working in isolated worktree: `/home/{user}/workspace/github/agent-worktrees/{repo}-{work_item_id}`

**Repository:** {repository_field}
**Branch:** `bug/{work_item_id}-{slug}`

This worktree is independent of your main workspace. All changes will be made here.
```

#### Option B: Standard Mode (default)

If worktree mode is disabled, use existing behavior:

```bash
# Check if branch exists
git rev-parse --verify bug/{work_item_id}-{slug} 2>/dev/null
```

**If exists:** `git checkout bug/{work_item_id}-{slug}`

**If not:** `git checkout -b bug/{work_item_id}-{slug}`

Inform user of branch created or checked out.

**Reference**:
- See `.claude/shared/git/README.md` for branch creation patterns
- See `.claude/shared/worktree/README.md` for worktree patterns

### Step 9: Generate Comprehensive Fix Plan

Create detailed fix plan by researching codebase.

**Research Phase:**
1. **Search for related code** using Grep (keywords from title, error messages)
2. **Find relevant files** using Glob (test files, config, API endpoints)
3. **Check recent commits** using git log (changes in related files)

**Plan Structure:**

```markdown
# Bug Fix Plan: #{work_item_id} - {title}

**Created:** {timestamp}
**Bug State:** {old_state} → In Progress
**Assigned To:** Corbin Taylor
**Branch:** bug/{work_item_id}-{slug}

## 1. Bug Summary
{1-2 paragraph summary with business impact}

## 2. Context Analysis
### Environment
### Severity & Impact
### Recent Changes
### Additional Context (from Step 3)

## 3. Root Cause Hypothesis
**Primary Theory:** {most likely cause}
**Alternative Theories:** {list}

## 4. Investigation Steps
{what to examine, logs to check}

## 5. Proposed Fix
### Approach
### Alternative Approaches
### Implementation Details
- Files to Modify
- New Files to Create

## 6. Testing Strategy
### Unit Tests
### Integration Tests
### Manual Testing
### Regression Testing

## 7. Implementation Checklist
- [ ] {task 1}
- [ ] {task 2}
- [ ] Write unit tests
- [ ] Manual testing
- [ ] Verify no regressions

## 8. Architecture Compliance
- Follow API/Application layer separation (CLAUDE.md)
- Use Clean Architecture principles
- Feature-based organization
- Constructor injection with protocol-based interfaces

## 9. Rollback Plan
{steps to rollback if issues arise}

## 10. Monitoring & Verification
{metrics/logs to watch after deployment}

---
**Ready to implement?** Reply 'yes' or provide feedback.
```

### Step 10: Plan Approval Loop

Present plan and wait for approval.

**User responses:**
- **"yes"/"looks good"/"proceed"** → Move to Step 11
- **"change {aspect}"** → Regenerate that section
- **"{question}?"** → Answer to clarify
- **"skip {step}"** → Update plan to skip
- **"add {item}"** → Add requested item

**Iterate** until user approves.

### Step 11: Implementation Phase

Once approved, implement the fix:

**Follow {Product} Architecture:**

**API Layer** (`api/`):
- Only FastAPI routers, Pydantic models, HTTP concerns
- Delegate business logic to Application layer
- No SQLAlchemy or ORM imports
- No business logic

**Application Layer** (`application/`):
- All business logic, services, repositories
- Owns ORM models and database sessions
- No FastAPI imports
- Constructor injection with protocols

**Feature Organization:**
```
features/{feature_name}/
├── models.py        # Pydantic (API) / SQLAlchemy (Application)
├── controller.py    # HTTP logic (API only)
├── router.py        # FastAPI routes (API only)
├── service.py       # Business logic (Application)
├── repository.py    # Data access (Application)
└── __init__.py
```

**Code Quality:**
- Black formatting (API: 88 chars, Application: 100 chars)
- isort for imports
- flake8 compliance
- Type hints for all functions
- Docstrings for complex logic

**Testing:**
- Unit tests as specified in plan
- Integration tests
- pytest conventions
- 80%+ coverage on new/modified code

### Step 12: Manual Testing Requirement

After implementation, **BLOCK** and require manual testing.

```markdown
## ✅ Implementation Complete - Manual Testing Required

### Changes Made
{summary of modifications}

### Testing Instructions

#### Manual Test Steps
1. {step 1 from plan}
2. {step 2}
3. **Expected Result:** {what should happen}

#### Verification Checklist
- [ ] Bug no longer reproduces
- [ ] No regression in related functionality
- [ ] All automated tests pass
- [ ] Code follows project standards
- [ ] Aligns with {Product} architecture

### Running Tests Locally

**API Tests:**
```bash
cd api/
poetry run pytest
poetry run flake8 .
```

**Application Tests:**
```bash
cd application/
pytest -v --strict-markers --cov=.
```

---
**After manual testing**, confirm fix works before committing.
```

Wait for user confirmation that manual testing passed before considering bug pickup complete.

## Error Handling

### Work Item Not Found
```
❌ Work Item Not Found

Work item #{id} was not found in Azure DevOps project "ERM".

Please verify:
- Work item ID is correct
- Work item exists in ERM project
- You have access to view the work item
```

### Wrong Work Item Type
```
❌ Invalid Work Item Type

Work item #{id} is type "{type}", but /pickup-bug requires "TechOps Bug".

Use instead:
- /pickup-feature for "User Story" work items
- Contact team if work item type should be TechOps Bug
```

### Identity Resolution Failed
```
❌ User Identity Not Found

Could not find Azure DevOps identity for "Corbin Taylor".

Troubleshooting:
- Verify Azure DevOps MCP server connection
- Check user exists in organization
- Try full email: corbin.taylor@example.com
```

### Git Branch Creation Failed
```
❌ Git Branch Creation Failed

Error: {error_message}

Troubleshooting:
- Ensure you're in git repository
- Check no uncommitted changes blocking checkout
- Verify branch name doesn't conflict
- Try: git status
```

### Work Item Update Failed
```
❌ Work Item Update Failed

Failed to update work item #{id}: {error_message}

Troubleshooting:
- Verify you have edit permissions
- Check if work item is locked
- Validate state transition is allowed
- Review Azure DevOps field rules
```

### Teams Notification Failed (Non-Blocking)
```
⚠️ Teams Notification Skipped

Could not notify Teams thread: {error_message}

This is non-blocking. The workflow continues.

Possible causes:
- TeamsChannelMessageId not set on work item
- Logic App endpoint not configured in techops-config.json
- Teams channel or message no longer exists
- Network connectivity issues
```

## Integration with Workflow

**Downstream:**
- After fix is implemented and tested, use `/commit` command
- Then use `/create-pr` to create pull request
- Link PR back to work item

**Related Skills:**
- `pickup-feature` - Similar workflow for User Story work items
- `implement-task` - For implementing tasks from blueprints

**Related Commands:**
- `/commit` - Smart commit with conventional message
- `/create-pr` - Create pull request with auto-generated description

## Notes

- This Skill is specific to "TechOps Bug" work items
- Always reassigns to Corbin Taylor regardless of current assignment
- Branch naming follows {Product} git conventions
- Fix plans are comprehensive and require approval before implementation
- Manual testing is mandatory before considering bug fixed
- Follows Clean Architecture and feature-based organization
- References {Product} CLAUDE.md for architecture patterns
- Pre-commit hooks will validate formatting and linting
- Teams notification is optional and non-blocking (requires `TeamsChannelMessageId` field and config)
