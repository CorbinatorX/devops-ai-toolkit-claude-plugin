---
name: pickup-feature
description: Pick up User Story work items from Azure DevOps, assign to developer, create git branch, investigate, plan, and implement the feature
allowed-tools: Read, Write, Bash, Grep, Glob, Edit
auto-discover:
  - "pick up feature"
  - "pickup feature"
  - "user story"
  - "work on story"
  - "pick up story"
---

# Pickup Feature Skill

## Purpose

Complete workflow for picking up "User Story" work items from Azure DevOps. Handles assignment, branch creation, requirements analysis, implementation planning, coding, and testing in an 11-step process.

This Skill integrates with Azure DevOps for work item management and follows {Product} git branching conventions.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "Pick up user story {number}"
- "Work on user story #{id}"
- "Pickup feature {number}"
- "I need to implement user story {id}"
- "Pick up story {number}"

## Example Invocations

```
"Pick up user story 25200"
"Work on story #25150"
"Pickup feature 25175"
"I need to work on user story 25180"
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
- Branch slug generation from story title (7-step algorithm)
- Branch creation or checkout
- Branch naming pattern: `feature/{id}-{slug}`

**Teams** (`.claude/shared/teams/`):
- Logic App for post/reply operations
- Config: `.claude/techops-config.json` (flow_url, team_id, channel_id)
- Reply to Teams threads when work items have `TeamsChannelMessageId`

See shared module READMEs for detailed patterns and examples.

## Workflow (12 Steps)

### Step 1: Retrieve Work Item Details

**First, determine the work item provider:**

```bash
provider=$(jq -r '.work_items.provider // "azure-devops"' .claude/techops-config.json 2>/dev/null || echo "azure-devops")
```

#### Provider: Azure DevOps (default)

Use `mcp__azure-devops__wit_get_work_item` to fetch user story details.

**Parameters:**
```json
{
  "project": "ERM",
  "id": work_item_id,
  "expand": "relations"
}
```

**Extract:**
- Work Item Type (MUST be "User Story")
- Title, State, AssignedTo, Description
- Acceptance Criteria
- Priority, Story Points
- CreatedDate, ChangedDate
- Related work items (parent features, child tasks)
- Custom.TeamsChannelMessageId (for Teams thread reply)
- **`work_item_id`**: Use the `id` field from response (integer)

#### Provider: Notion

Use `mcp__notion__notion-fetch` to fetch the page.

**Parameters:**
```json
{
  "pageId": "{user_provided_id}"
}
```

**CRITICAL - Work Item ID Extraction:**
```markdown
# The work_item_id for worktree creation MUST come from the page response:
work_item_id = notion_page.id  # Page UUID, unique per work item

# DO NOT use database_id from config - it's the same for ALL work items!
# WRONG: work_item_id = config.work_items.providers.notion.database_id
```

**Extract (using property_mappings from config):**
- Title from mapped title property
- State from mapped state property
- Type from mapped type property (should map to "feature")
- Description from mapped description property
- **`work_item_id`**: Use the page's `id` field from response (UUID)

**Reference**: See `.claude/shared/work-items/providers/notion/README.md` for property mapping patterns.

#### Validation (all providers)

- If type is NOT "User Story" (ADO) or "Feature" (Notion), show error and stop
- If work item not found, show error

### Step 2: Display User Story Context

Present formatted summary:

```markdown
## User Story #{work_item_id}: {title}

**Current State:** {state}
**Assigned To:** {assignee or "Unassigned"}
**Priority:** {priority}
**Story Points:** {story_points}
**Iteration:** {iteration_path}
**Reported:** {created_date}
**Last Updated:** {changed_date}

### Description
{description}

### Acceptance Criteria
{acceptance_criteria}

### Related Work Items
- Parent Feature: #{id}: {title} ({state})
- Child Tasks:
  - #{id}: {title} ({state})
```

### Step 3: Interactive Context Clarification

Engage in natural conversation to gather additional context:
- "Are there any additional requirements or edge cases to consider?"
- "Do you have specific implementation preferences?"
- "Is there context from related features or recent work?"
- "Any technical constraints or dependencies?"

Allow user to provide extra information or say "no"/"none"/"proceed" to continue.

**Store any additional context** for use in the implementation plan.

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
      "value": "Active"
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
  User story picked up by Corbin Taylor for implementation via Claude Code /pickup-feature command
  ```
- If assigned to someone else:
  ```
  User story picked up by Corbin Taylor for implementation via Claude Code /pickup-feature command (previously assigned to {previous_assignee})
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
    "content": "💡 **Feature Picked Up**\n\nUser story #{work_item_id} has been picked up by **Corbin Taylor** for implementation.\n\n**Branch:** `feature/{work_item_id}-{slug}`\n\n_via Claude Code /pickup-feature command_"
  }'
```

**On Success:** Log that Teams thread was notified.

**On Failure:** Log warning but continue workflow (Teams notification is non-blocking).

**Reference**: See `.claude/shared/teams/README.md` for Logic App patterns.

### Step 8: Create Git Branch

Generate branch name: `feature/{work_item_id}-{title-slug}`

**Branch slug generation** (7-step algorithm from `.claude/shared/git/README.md`):
1. Convert title to lowercase
2. Replace special chars: `'` → remove, `/\` → `-`, `&` → `and`, `+` → `plus`
3. Replace spaces/underscores with hyphens
4. Remove non-alphanumeric except hyphens
5. Collapse multiple hyphens to single hyphen
6. Trim hyphens from start/end
7. Truncate to 50 chars at word boundary (break at last hyphen after position 30)

**Examples:**
- "Add user notification preferences" → `feature/25200-add-user-notification-preferences`
- "Implement P95/P99 metrics display" → `feature/25099-implement-p95-p99-metrics-display`

#### Check for Worktree Mode

First, check if worktree mode is enabled in `.claude/techops-config.json`:

```bash
worktree_enabled=$(cat .claude/techops-config.json 2>/dev/null | jq -r '.worktree.enabled // false')
```

#### Option A: Worktree Mode (if enabled)

If `worktree.enabled` is `true`, create an isolated worktree for this feature:

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
    branch_name="feature/{work_item_id}-{slug}"

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
**Branch:** `feature/{work_item_id}-{slug}`

This worktree is independent of your main workspace. All changes will be made here.
```

#### Option B: Standard Mode (default)

If worktree mode is disabled, use existing behavior:

```bash
# Check if branch exists
git rev-parse --verify feature/{work_item_id}-{slug} 2>/dev/null
```

**If exists:** `git checkout feature/{work_item_id}-{slug}`

**If not:** `git checkout -b feature/{work_item_id}-{slug}`

Inform user of branch created or checked out.

**Reference**:
- See `.claude/shared/git/README.md` for branch creation patterns
- See `.claude/shared/worktree/README.md` for worktree patterns

### Step 9: Generate Comprehensive Implementation Plan

Create detailed implementation plan by researching codebase.

**Research Phase:**
1. **Search for related code** using Grep (keywords from title, similar features)
2. **Find relevant files** using Glob (existing features, test files, API endpoints)
3. **Check recent commits** using git log (recent feature additions)
4. **Study architecture** - Read CLAUDE.md for {Product} patterns

**Plan Structure:**

```markdown
# Feature Implementation Plan: #{work_item_id} - {title}

**Created:** {timestamp}
**Story State:** {old_state} → Active
**Assigned To:** Corbin Taylor
**Branch:** feature/{work_item_id}-{slug}
**Story Points:** {points}

## 1. Feature Summary
{1-2 paragraph summary with business value and user benefit}

## 2. Requirements Analysis
### User Story
{description from work item}

### Acceptance Criteria
{numbered list of acceptance criteria}

### Additional Context (from Step 3)
{context provided by user}

### Out of Scope
{explicitly state what is NOT included in this story}

## 3. Technical Approach
### Architecture Overview
{how this feature fits into existing architecture}

### Design Decisions
**Decision 1:** {choice} - **Rationale:** {reason}
**Decision 2:** {choice} - **Rationale:** {reason}

### Integration Points
- {existing service/component it integrates with}
- {API endpoints it consumes}
- {databases/stores it uses}

## 4. Implementation Details
### API Layer Changes (`api/`)
**Files to Create:**
- `api/src/{product}_api/features/{feature}/models.py` - Pydantic request/response models
- `api/src/{product}_api/features/{feature}/controller.py` - HTTP logic
- `api/src/{product}_api/features/{feature}/router.py` - FastAPI routes

**Files to Modify:**
- `api/src/{product}_api/main.py` - Register new router

### Application Layer Changes (`application/`)
**Files to Create:**
- `application/src/{product}_application/features/{feature}/models.py` - SQLAlchemy entities
- `application/src/{product}_application/features/{feature}/service.py` - Business logic
- `application/src/{product}_application/features/{feature}/repository.py` - Data access

**Database Changes:**
- Migration: `application/alembic/versions/{timestamp}_{description}.py`
- Tables: {list new tables}
- Indexes: {list indexes for performance}

### UI Changes (if applicable) (`ui/`)
**Files to Create:**
- `ui/src/features/{feature}/components/` - React components
- `ui/src/features/{feature}/hooks/` - Custom hooks
- `ui/src/features/{feature}/services/` - API client

## 5. Testing Strategy
### Unit Tests
**API Tests** (`api/tests/`):
- Test request validation
- Test response serialization
- Test error handling

**Application Tests** (`application/tests/`):
- Test business logic in services
- Test repository data access
- Test entity behavior

### Integration Tests
- End-to-end API endpoint tests
- Database integration tests
- External service integration (if applicable)

### Manual Testing
1. {manual test step 1}
2. {manual test step 2}
3. **Expected Result:** {what should happen}

## 6. Implementation Checklist
- [ ] Create API layer (models, controller, router)
- [ ] Create Application layer (entities, service, repository)
- [ ] Create database migration
- [ ] Write unit tests (API layer)
- [ ] Write unit tests (Application layer)
- [ ] Write integration tests
- [ ] Create UI components (if applicable)
- [ ] Update API documentation
- [ ] Manual testing
- [ ] Verify acceptance criteria met

## 7. Architecture Compliance
**{Product} Architecture (from CLAUDE.md):**
- API layer: FastAPI routers, Pydantic models, HTTP only
- Application layer: Business logic, SQLAlchemy entities, repositories
- Feature-based organization: `features/{feature}/`
- Constructor injection with protocol-based interfaces
- Clean Architecture: No business logic in API layer

## 8. Performance Considerations
- Database query optimization (indexes, eager loading)
- API response caching (if applicable)
- Pagination for large result sets
- Async/await patterns

## 9. Security Considerations
- Input validation in Pydantic models
- Authorization checks in controllers
- SQL injection prevention (parameterized queries)
- No secrets in code

## 10. Deployment Notes
- Database migration must run before deployment
- Feature flags (if applicable)
- Backward compatibility considerations

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

Once approved, implement the feature:

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
{summary of files created/modified}

### Testing Instructions

#### Manual Test Steps
1. {step 1 from plan}
2. {step 2}
3. **Expected Result:** {what should happen}

#### Acceptance Criteria Verification
- [ ] {acceptance criterion 1}
- [ ] {acceptance criterion 2}
- [ ] {acceptance criterion 3}

#### Verification Checklist
- [ ] All acceptance criteria met
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

**UI Tests (if applicable):**
```bash
cd ui/
npm test
npm run lint
```

---
**After manual testing**, confirm feature works before committing.
```

Wait for user confirmation that manual testing passed.

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

Work item #{id} is type "{type}", but /pickup-feature requires "User Story".

Use instead:
- /pickup-bug for "Bug" work items
- Contact team if work item type should be User Story
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
- After feature is implemented and tested, use `/commit` command
- Then use `/create-pr` to create pull request
- Link PR back to work item

**Related Skills:**
- `pickup-bug` - Similar workflow for Bug work items
- `implement-task` - For implementing tasks from blueprints
- `blueprint` - For creating architecture blueprints for new features

**Related Commands:**
- `/commit` - Smart commit with conventional message
- `/create-pr` - Create pull request with auto-generated description

## Notes

- This Skill is specific to "User Story" work items
- Always reassigns to Corbin Taylor regardless of current assignment
- Branch naming follows {Product} git conventions (`feature/{id}-{slug}`)
- Implementation plans are comprehensive and require approval
- Manual testing is mandatory before considering feature complete
- Follows Clean Architecture and feature-based organization
- References {Product} CLAUDE.md for architecture patterns
- Pre-commit hooks will validate formatting and linting
- Acceptance criteria from work item must be explicitly verified
- Teams notification is optional and non-blocking (requires `TeamsChannelMessageId` field and config)
