---
name: pickup-tech-debt
description: Pick up Technical Debt Item work items from Azure DevOps, assign to developer, create git branch, investigate, plan, and implement the fix
allowed-tools: Read, Write, Bash, Grep, Glob, Edit
auto-discover:
  - "pick up tech debt"
  - "pickup tech debt"
  - "tech debt #"
  - "refactor"
  - "work on tech debt"
  - "TD-"
---

# Pickup Tech Debt Skill

## Purpose

Complete workflow for picking up "Technical Debt Item" work items from Azure DevOps. Handles assignment, branch creation, Teams notification, investigation, refactoring plan, implementation, and testing in a 12-step process.

This Skill integrates with Azure DevOps for work item management and follows {Product} git branching conventions.

## Auto-Discovery Triggers

This Skill automatically activates when users mention:
- "Pick up tech debt {number}"
- "Work on tech debt #{id}"
- "Refactor TD-001"
- "I need to work on tech debt {id}"
- "Pickup TD-{number}"

## Example Invocations

```
"Pick up tech debt 25300"
"Work on tech debt #25400"
"Refactor TD-001"
"I need to work on tech debt 25350"
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
- Branch slug generation from tech debt title (7-step algorithm)
- Branch creation or checkout
- Branch naming pattern: `refactor/{id}-{slug}`

**Teams** (`.claude/shared/teams/`):
- Logic App for post/reply operations
- Config: `.claude/techops-config.json` (flow_url, team_id, channel_id)
- Reply to Teams threads when work items have `TeamsChannelMessageId`

See shared module READMEs for detailed patterns and examples.

## Workflow (12 Steps)

### Step 1: Retrieve Work Item Details

Use `mcp__azure-devops__wit_get_work_item` to fetch tech debt item details.

**Parameters:**
```json
{
  "project": "ERM",
  "id": work_item_id,
  "expand": "relations"
}
```

**Extract:**
- Work Item Type (MUST be "Technical Debt Item")
- Title, State, AssignedTo, Description
- Custom.AffectedArea (location/file paths)
- Microsoft.VSTS.CMMI.ProposedFix (proposed solution)
- Custom.Impact (impact areas: Maintainability, Performance, etc.)
- Custom.BusinessImpact (High/Medium/Low)
- Custom.TechnicalRisk (High/Medium/Low)
- Microsoft.VSTS.Scheduling.StoryPoints
- Custom.TradeOffs (notes)
- CreatedDate, ChangedDate
- Related work items
- Custom.TeamsChannelMessageId (for Teams thread reply)

**Validation:**
- If type is NOT "Technical Debt Item", show error and stop
- If work item not found, show error

### Step 2: Display Tech Debt Context

Present formatted summary:

```markdown
## Tech Debt #{work_item_id}: {title}

**Current State:** {state}
**Assigned To:** {assignee or "Unassigned"}
**Business Impact:** {business_impact} (High/Medium/Low)
**Technical Risk:** {technical_risk} (High/Medium/Low)
**Story Points:** {story_points}
**Impact Areas:** {impact_areas}
**Reported:** {created_date}
**Last Updated:** {changed_date}

### Description (Issue)
{description}

### Affected Area (Location)
{affected_area}

### Proposed Solution
{proposed_fix}

### Trade-offs / Notes
{trade_offs}

### Related Work Items
- #{id}: {title} ({state})
```

### Step 3: Interactive Context Clarification

Engage in natural conversation to gather additional context:
- "Are there any additional considerations for this refactoring?"
- "Do you have specific concerns or areas to focus on?"
- "Are there related changes or dependencies to consider?"
- "Any constraints on the approach (backward compatibility, etc.)?"

Allow user to provide extra information or say "no"/"none"/"proceed" to continue.

**Store any additional context** for use in the refactoring plan.

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
  Tech debt item picked up by Corbin Taylor for refactoring via Claude Code /pickup-tech-debt command
  ```
- If assigned to someone else:
  ```
  Tech debt item picked up by Corbin Taylor for refactoring via Claude Code /pickup-tech-debt command (previously assigned to {previous_assignee})
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
    "content": "🔧 **Tech Debt Picked Up**\n\nTech debt #{work_item_id} has been picked up by **Corbin Taylor** for refactoring.\n\n**Branch:** `refactor/{work_item_id}-{slug}`\n\n_via Claude Code /pickup-tech-debt command_"
  }'
```

**On Success:** Log that Teams thread was notified.

**On Failure:** Log warning but continue workflow (Teams notification is non-blocking).

**Reference**: See `.claude/shared/teams/README.md` for Logic App patterns.

### Step 8: Create Git Branch

Generate branch name: `refactor/{work_item_id}-{title-slug}`

**Branch slug generation** (7-step algorithm from `.claude/shared/git/README.md`):
1. Convert title to lowercase
2. Replace special chars: `'` → remove, `/\` → `-`, `&` → `and`, `+` → `plus`
3. Replace spaces/underscores with hyphens
4. Remove non-alphanumeric except hyphens
5. Collapse multiple hyphens to single hyphen
6. Trim hyphens from start/end
7. Truncate to 50 chars at word boundary (break at last hyphen after position 30)

**Examples:**
- "TD-001: SQLAlchemy Async Driver Migration" → `refactor/25300-td-001-sqlalchemy-async-driver-migration`
- "TD-005: API Response Caching" → `refactor/25350-td-005-api-response-caching`

**Git operations:**

```bash
# Check if branch exists
git rev-parse --verify refactor/{work_item_id}-{slug} 2>/dev/null
```

**If exists:** `git checkout refactor/{work_item_id}-{slug}`

**If not:** `git checkout -b refactor/{work_item_id}-{slug}`

Inform user of branch created or checked out.

**Reference**: See `.claude/shared/git/README.md` for branch creation patterns.

### Step 9: Generate Comprehensive Refactoring Plan

Create detailed refactoring plan by researching codebase.

**Research Phase:**
1. **Search for affected code** using Grep (files from AffectedArea)
2. **Find relevant files** using Glob (test files, config, related modules)
3. **Check recent commits** using git log (changes in related files)
4. **Analyze dependencies** using imports and references

**Plan Structure:**

```markdown
# Tech Debt Refactoring Plan: #{work_item_id} - {title}

**Created:** {timestamp}
**State:** {old_state} → In Progress
**Assigned To:** Corbin Taylor
**Branch:** refactor/{work_item_id}-{slug}

## 1. Tech Debt Summary
{1-2 paragraph summary with business and technical impact}

## 2. Context Analysis
### Impact Areas
{Maintainability, Performance, Process, Scalability, Security}

### Business Impact
{High/Medium/Low with explanation}

### Technical Risk
{High/Medium/Low with explanation}

### Additional Context (from Step 3)
{context provided by user}

## 3. Current State Analysis
**Files Affected:**
{list of files from AffectedArea}

**Code Patterns Observed:**
{analysis of current implementation}

**Pain Points:**
{specific issues identified}

## 4. Proposed Solution
{from Microsoft.VSTS.CMMI.ProposedFix field}

### Implementation Approach
{detailed steps}

### Alternative Approaches Considered
{list alternatives and why not chosen}

## 5. Refactoring Details
### Files to Modify
- `{file1}` - {what changes}
- `{file2}` - {what changes}

### Files to Create
- `{new_file}` - {purpose}

### Files to Delete/Deprecate
- `{old_file}` - {reason}

### Database Changes (if applicable)
- Migration: {description}

## 6. Testing Strategy
### Unit Tests
**Existing Tests to Update:**
- `{test_file}` - {what changes}

**New Tests to Create:**
- Test for {scenario 1}
- Test for {scenario 2}

### Integration Tests
- {integration test plan}

### Manual Testing
1. {step 1}
2. {step 2}
3. **Expected Result:** {what should happen}

### Regression Testing
- {areas to verify no regression}

## 7. Implementation Checklist
- [ ] {task 1}
- [ ] {task 2}
- [ ] Update/create unit tests
- [ ] Update/create integration tests
- [ ] Run full test suite
- [ ] Verify no regressions
- [ ] Update documentation if applicable

## 8. Architecture Compliance
- Follow API/Application layer separation (CLAUDE.md)
- Use Clean Architecture principles
- Feature-based organization
- Constructor injection with protocol-based interfaces
- No breaking changes unless discussed

## 9. Rollback Plan
{steps to rollback if issues arise}

## 10. Trade-offs / Considerations
{from Custom.TradeOffs field}

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

Once approved, implement the refactoring:

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

**Refactoring Best Practices:**
- Make small, incremental changes
- Ensure tests pass after each change
- Preserve backward compatibility when possible
- Document any breaking changes
- Update related documentation

**Testing:**
- Unit tests as specified in plan
- Integration tests
- pytest conventions
- 80%+ coverage on new/modified code

### Step 12: Manual Testing Requirement

After implementation, **BLOCK** and require manual testing.

```markdown
## ✅ Refactoring Complete - Manual Testing Required

### Changes Made
{summary of modifications}

### Testing Instructions

#### Manual Test Steps
1. {step 1 from plan}
2. {step 2}
3. **Expected Result:** {what should happen}

#### Verification Checklist
- [ ] Refactoring addresses the tech debt issue
- [ ] No regression in related functionality
- [ ] All automated tests pass
- [ ] Performance not degraded (if applicable)
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
**After manual testing**, confirm refactoring works before committing.
```

Wait for user confirmation that manual testing passed before considering tech debt pickup complete.

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

Work item #{id} is type "{type}", but /pickup-tech-debt requires "Technical Debt Item".

Use instead:
- /pickup-bug for "TechOps Bug" work items
- /pickup-feature for "User Story" work items
- Contact team if work item type should be Technical Debt Item
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
- After refactoring is implemented and tested, use `/commit` command
- Then use `/create-pr` to create pull request
- Link PR back to work item

**Related Skills:**
- `pickup-bug` - Similar workflow for TechOps Bug work items
- `pickup-feature` - Similar workflow for User Story work items
- `implement-task` - For implementing tasks from blueprints

**Related Commands:**
- `/create-tech-debt` - Create tech debt items from status files
- `/commit` - Smart commit with conventional message
- `/create-pr` - Create pull request with auto-generated description

## Notes

- This Skill is specific to "Technical Debt Item" work items
- Always reassigns to Corbin Taylor regardless of current assignment
- Branch naming follows {Product} git conventions (`refactor/{id}-{slug}`)
- Refactoring plans are comprehensive and require approval before implementation
- Manual testing is mandatory before considering tech debt resolved
- Follows Clean Architecture and feature-based organization
- References {Product} CLAUDE.md for architecture patterns
- Pre-commit hooks will validate formatting and linting
- Teams notification is optional and non-blocking (requires `TeamsChannelMessageId` field and config)
- Unlike bugs, tech debt often requires more careful planning to avoid regressions
