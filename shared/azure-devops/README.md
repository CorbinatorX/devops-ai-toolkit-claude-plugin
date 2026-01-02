# Azure DevOps Helpers for Claude Code Skills

> **Note**: This module is being superseded by the work items abstraction layer.
> For new implementations, see `.claude/shared/work-items/providers/azure-devops/README.md`.
> This file is maintained for backward compatibility.

Reusable patterns and helpers for Azure DevOps work item operations in Skills.

## Project Configuration

### Reading from techops-config.json

All Skills and commands should read Azure DevOps configuration from `.claude/techops-config.json`:

```bash
# Read configuration
if [ ! -f ".claude/techops-config.json" ]; then
    echo "❌ Configuration not found. Please run: /configure-techops"
    exit 1
fi

# Extract Azure DevOps settings
PROJECT=$(jq -r '.azure_devops.project' .claude/techops-config.json)
AREA_PATH=$(jq -r '.azure_devops.area_path' .claude/techops-config.json)
ITERATION_PATH=$(jq -r '.azure_devops.iteration_path' .claude/techops-config.json)
ORGANIZATION=$(jq -r '.azure_devops.organization' .claude/techops-config.json)
CONTRIBUTOR=$(jq -r '.contributor' .claude/techops-config.json)
```

**Note**: Project details (name, description, tech stack) should be read from `.claude/config.json` to avoid duplication.

**Configuration created by**: `/configure-techops` command

### Fallback Constants (Legacy)

If `.claude/techops-config.json` doesn't exist, use these defaults for backward compatibility:

```
PROJECT = "ERM"
AREA_PATH = "ERM\\Devops"  # Note: Backslash, not forward slash!
ITERATION_PATH = "ERM\\dops-backlog"
```

## Work Item Operations

### Get Work Item

**Pattern**: Retrieve work item details with optional expansion

```markdown
Use `mcp__azure-devops__wit_get_work_item` tool:

Parameters:
- project: "ERM"
- id: {work_item_id}
- expand: "relations" (optional)

Extract fields:
- System.Title
- System.State
- System.AssignedTo
- System.Description
- Microsoft.VSTS.TCM.ReproSteps (for bugs)
- Microsoft.VSTS.Common.Severity
- System.CreatedDate
- System.ChangedDate
- relations (if expanded)
```

### Update Work Item

**Pattern**: Update one or more work item fields

```markdown
Use `mcp__azure-devops__wit_update_work_item` tool:

Parameters:
- id: {work_item_id}
- updates: [
    {"op": "add", "path": "/fields/System.State", "value": "In Progress"},
    {"op": "add", "path": "/fields/System.AssignedTo", "value": "{identity_id}"}
  ]

Common field paths:
- /fields/System.State (values: New, Active, In Progress, Resolved, Closed)
- /fields/System.AssignedTo (requires identity ID)
- /fields/System.Title
- /fields/System.Description
- /fields/Microsoft.VSTS.Common.Severity (1-4)
- /fields/System.AreaPath (use backslash: ERM\\Devops)
- /fields/System.IterationPath
```

### Add Work Item Comment

**Pattern**: Add comment to work item

```markdown
Use `mcp__azure-devops__wit_add_work_item_comment` tool:

Parameters:
- project: "ERM"
- workItemId: {work_item_id}
- comment: "{comment_text}"
- format: "html" (default) or "markdown"

Example comment:
"Bug picked up by Corbin Taylor for investigation and fix via Claude Code /pickup-bug command"
```

### Get Identity ID for Assignment

**Pattern**: Resolve user display name to identity ID

```markdown
Use `mcp__azure-devops__core_get_identity_ids` tool:

Parameters:
- searchFilter: "Corbin Taylor"

Returns: Identity ID string needed for System.AssignedTo field

Store the returned ID for use in update_work_item calls.
```

## Validation Helpers

### Validate Severity

```markdown
Severity values must be 1-4:
- 1 = Critical
- 2 = High
- 3 = Medium
- 4 = Low

Pattern:
if severity not in [1, 2, 3, 4]:
    return error
```

### Validate Work Item Type

```markdown
For /pickup-bug: Must be "TechOps Bug" (exact case)
For /pickup-feature: Must be "User Story" (exact case)

Pattern:
work_item_type = work_item["fields"]["System.WorkItemType"]
if work_item_type != "TechOps Bug":
    return error message
```

### Validate State Transitions

```markdown
Valid state transitions:
- New → Active
- New → In Progress
- Active → In Progress
- In Progress → Resolved
- Resolved → Closed
- Any state → Active (reopen)

Closed/Done states require confirmation before reopening.
```

## Error Handling Patterns

### Work Item Not Found

```markdown
## ❌ Work Item Not Found

**Error**: Work item #{work_item_id} does not exist in project ERM.

Please verify:
- The work item ID is correct
- You have access to the ERM project
- The work item hasn't been deleted

You can search for work items at: https://dev.azure.com/{organization}/{project}/_workitems
```

### Invalid Work Item Type

```markdown
## ❌ Invalid Work Item Type

**Error**: Work item #{work_item_id} is a "{actual_type}", not a "{expected_type}".

The command only works with {expected_type} work items.
```

### Identity ID Not Found

```markdown
## ❌ Cannot Resolve User Identity

**Error**: Could not find identity ID for "{user_name}".

This might be due to:
- Azure DevOps permissions issue
- User not found in the organization
- Network connectivity problem
- MCP server connection issue

**Troubleshooting:**
- Verify you're authenticated to Azure DevOps
- Check network connectivity
- Try again in a few moments
```

## Field Mappings Reference

### Standard Fields

| Field Path | Type | Values/Notes |
|------------|------|--------------|
| System.Title | String | Work item title |
| System.State | String | New, Active, In Progress, Resolved, Closed |
| System.AssignedTo | Identity | Requires identity ID from get_identity_ids |
| System.Description | HTML | Large text field, format: "Html" |
| System.WorkItemType | String | TechOps Bug, User Story, Task, etc. |
| System.AreaPath | String | Use backslash: ERM\\Devops |
| System.IterationPath | String | Use backslash: ERM\\dops-backlog |
| System.CreatedDate | DateTime | ISO 8601 format |
| System.ChangedDate | DateTime | ISO 8601 format |

### Bug-Specific Fields

| Field Path | Type | Values/Notes |
|------------|------|--------------|
| Microsoft.VSTS.TCM.ReproSteps | HTML | Reproduction steps |
| Microsoft.VSTS.Common.Severity | Integer | 1-4 (Critical-Low) |
| Custom.Environment | String | Production, Staging, Dev, etc. |

### User Story Fields

| Field Path | Type | Values/Notes |
|------------|------|--------------|
| Microsoft.VSTS.Common.AcceptanceCriteria | HTML | Acceptance criteria |
| Microsoft.VSTS.Common.ValueArea | String | Business, Architectural |
| Microsoft.VSTS.Scheduling.StoryPoints | Integer | Story point estimate |

## Usage in Skills

Skills should document these patterns in their SKILL.md or reference files:

```markdown
# In SKILL.md

## Azure DevOps Integration

This Skill uses Azure DevOps MCP tools for work item operations.

**Reference**: See `.claude/shared/azure-devops/README.md` for:
- Work item CRUD patterns
- Field mappings and validation
- Error handling templates
- Identity resolution

**MCP Tools Used**:
- mcp__azure-devops__wit_get_work_item
- mcp__azure-devops__wit_update_work_item
- mcp__azure-devops__wit_add_work_item_comment
- mcp__azure-devops__core_get_identity_ids
```

## Testing

When implementing Skills that use Azure DevOps:

1. **Test with real work item**: Use an actual TechOps Bug or User Story
2. **Test error cases**: Non-existent ID, wrong work item type, closed states
3. **Test identity resolution**: Verify "Corbin Taylor" resolves to valid ID
4. **Test state transitions**: Verify transitions are valid
5. **Verify field updates**: Check Azure DevOps UI to confirm changes

## Common Patterns

### Pattern 1: Pickup Bug Workflow

```markdown
1. Get work item with expand="relations"
2. Validate type is "TechOps Bug"
3. Get identity ID for "Corbin Taylor"
4. Update state to "In Progress" and assign
5. Add comment documenting pickup
```

### Pattern 2: Create Work Item

```markdown
Use mcp__azure-devops__wit_create_work_item:

Parameters:
- project: "ERM"
- workItemType: "TechOps Bug"
- fields: [
    {"name": "System.Title", "value": "Bug title"},
    {"name": "System.Description", "value": "Description", "format": "Html"},
    {"name": "System.AreaPath", "value": "ERM\\Devops"},
    {"name": "Microsoft.VSTS.Common.Severity", "value": "2"}
  ]
```

### Pattern 3: Search for Existing Work Items

```markdown
Use mcp__azure-devops__search_workitem:

Parameters:
- searchText: "search query"
- project: ["ERM"]
- workItemType: ["TechOps Bug"]
- state: ["Active", "In Progress"]
- top: 10
```

## Notes

- Always use backslash (`\`) for paths (AreaPath, IterationPath), not forward slash
- Identity IDs are dynamic - never hardcode them, always resolve via get_identity_ids
- Large text fields (Description, ReproSteps, AcceptanceCriteria) require `"format": "Html"`
- Work item state transitions should be validated before updating
- Comments are HTML by default, markdown requires `"format": "markdown"` parameter
