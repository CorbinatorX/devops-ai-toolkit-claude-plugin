# Azure DevOps Work Item Provider

Provider implementation for Azure DevOps work items using the Azure DevOps MCP server.

## Overview

This provider enables work item operations against Azure DevOps using the `azure-devops` MCP server. It supports all standard work item types and custom fields.

**MCP Server**: `azure-devops`

## Configuration

Azure DevOps settings in `.claude/techops-config.json`:

```json
{
  "work_items": {
    "provider": "azure-devops",
    "providers": {
      "azure-devops": {
        "organization": "{org}",
        "project": "ERM",
        "area_path": "ERM\\Devops",
        "iteration_path": "ERM\\dops-backlog"
      }
    }
  },
  "azure_devops": {
    "organization": "{org}",
    "project": "ERM",
    "area_path": "ERM\\Devops",
    "iteration_path": "ERM\\dops-backlog"
  }
}
```

**Note**: For backward compatibility, settings can also be read from the `azure_devops` section directly.

### Reading Configuration

```bash
# Read Azure DevOps configuration
read_ado_config() {
    local config_file=".claude/techops-config.json"

    # Try new location first, fall back to legacy
    PROJECT=$(jq -r '.work_items.providers["azure-devops"].project // .azure_devops.project' "$config_file")
    AREA_PATH=$(jq -r '.work_items.providers["azure-devops"].area_path // .azure_devops.area_path' "$config_file")
    ITERATION_PATH=$(jq -r '.work_items.providers["azure-devops"].iteration_path // .azure_devops.iteration_path' "$config_file")
    ORGANIZATION=$(jq -r '.work_items.providers["azure-devops"].organization // .azure_devops.organization' "$config_file")
}
```

## MCP Functions

### Get Work Item

```markdown
Function: mcp__azure-devops__wit_get_work_item

Parameters:
- project: string (e.g., "ERM")
- id: integer (work item ID)
- expand: string (optional, "relations" for linked items)

Response Fields:
- id: integer
- fields: object
  - System.Title: string
  - System.State: string
  - System.AssignedTo: object {displayName, id}
  - System.Description: string (HTML)
  - System.WorkItemType: string
  - System.AreaPath: string
  - System.IterationPath: string
  - System.CreatedDate: string (ISO 8601)
  - System.ChangedDate: string (ISO 8601)
  - Microsoft.VSTS.Common.Severity: integer (1-4)
  - Microsoft.VSTS.TCM.ReproSteps: string (HTML, for bugs)
  - Microsoft.VSTS.Common.AcceptanceCriteria: string (HTML, for stories)
  - Custom.*: various (custom fields)
- relations: array (if expanded)
- _links.html.href: string (web URL)
```

### Create Work Item

```markdown
Function: mcp__azure-devops__wit_create_work_item

Parameters:
- project: string
- workItemType: string (e.g., "Bug", "User Story")
- fields: array of field objects
  [
    {"name": "System.Title", "value": "Title"},
    {"name": "System.Description", "value": "<p>Description</p>", "format": "Html"},
    {"name": "System.AreaPath", "value": "ERM\\Devops"},
    {"name": "Microsoft.VSTS.Common.Severity", "value": "2"}
  ]

Returns:
- id: integer (new work item ID)
- url: string

Notes:
- AreaPath and IterationPath use backslash (\\)
- HTML fields require format: "Html"
- Some fields are required per work item type
```

### Update Work Item

```markdown
Function: mcp__azure-devops__wit_update_work_item

Parameters:
- id: integer
- updates: array of JSON patch operations
  [
    {"op": "add", "path": "/fields/System.State", "value": "In Progress"},
    {"op": "add", "path": "/fields/System.AssignedTo", "value": "{identity_id}"}
  ]

Operations:
- "add": Set field value (creates or updates)
- "replace": Replace existing value
- "remove": Clear field value

Returns:
- Success/failure
- Updated work item
```

### Add Comment

```markdown
Function: mcp__azure-devops__wit_add_work_item_comment

Parameters:
- project: string
- workItemId: integer
- comment: string (comment text)
- format: string ("html" or "markdown", default: "html")

Returns:
- Comment ID
```

### Search Work Items

```markdown
Function: mcp__azure-devops__search_workitem

Parameters:
- searchText: string (search query)
- project: array (e.g., ["ERM"])
- workItemType: array (optional, e.g., ["Bug"])
- state: array (optional, e.g., ["Active", "In Progress"])
- top: integer (max results, default: 50)

Returns:
- Array of matching work items (summary)
```

### Resolve User Identity

```markdown
Function: mcp__azure-devops__core_get_identity_ids

Parameters:
- searchFilter: string (user name or email)

Returns:
- Identity ID string (GUID format)

Usage:
- Required before assigning work items
- Identity ID is used in System.AssignedTo updates
```

## Field Mappings

### Normalizing Azure DevOps to WorkItem

```markdown
normalize_ado_work_item(ado_response) -> WorkItem:

  id = ado_response.id
  provider = "azure-devops"
  url = ado_response._links.html.href

  # Map type
  ado_type = ado_response.fields["System.WorkItemType"]
  type = case ado_type:
    "Bug" -> "bug"
    "User Story" -> "feature"
    "Task" -> "task"
    "Technical Debt Item" -> "tech-debt"
    "Incident" -> "incident"
    else -> "other"

  title = ado_response.fields["System.Title"]

  # Convert HTML description to Markdown
  description = html_to_markdown(ado_response.fields["System.Description"])

  # Map state
  ado_state = ado_response.fields["System.State"]
  state = case ado_state:
    "New" -> "new"
    "Active" -> "active"
    "In Progress" -> "in-progress"
    "Resolved" -> "resolved"
    "Closed" -> "closed"
    else -> "active"

  # Map priority (Severity in ADO)
  severity = ado_response.fields["Microsoft.VSTS.Common.Severity"]
  priority = case severity:
    1 -> "critical"
    2 -> "high"
    3 -> "medium"
    4 -> "low"
    else -> "medium"

  # Extract assignee
  assignee = {
    id: ado_response.fields["System.AssignedTo"]?.id,
    name: ado_response.fields["System.AssignedTo"]?.displayName
  }

  created_date = ado_response.fields["System.CreatedDate"]
  modified_date = ado_response.fields["System.ChangedDate"]

  # Store unmapped fields
  provider_fields = {
    area_path: ado_response.fields["System.AreaPath"],
    iteration_path: ado_response.fields["System.IterationPath"],
    repro_steps: ado_response.fields["Microsoft.VSTS.TCM.ReproSteps"],
    acceptance_criteria: ado_response.fields["Microsoft.VSTS.Common.AcceptanceCriteria"],
    teams_message_id: ado_response.fields["Custom.TeamsChannelMessageId"],
    repository: ado_response.fields["Custom.Repository"]
  }

  return WorkItem
```

### Denormalizing WorkItem to Azure DevOps

```markdown
denormalize_to_ado(fields: UpdateFields) -> ADO_Updates:

  updates = []

  if fields.title:
    updates.push({op: "add", path: "/fields/System.Title", value: fields.title})

  if fields.description:
    html = markdown_to_html(fields.description)
    updates.push({op: "add", path: "/fields/System.Description", value: html})

  if fields.state:
    ado_state = case fields.state:
      "new" -> "New"
      "active" -> "Active"
      "in-progress" -> "In Progress"
      "resolved" -> "Resolved"
      "closed" -> "Closed"
    updates.push({op: "add", path: "/fields/System.State", value: ado_state})

  if fields.priority:
    severity = case fields.priority:
      "critical" -> 1
      "high" -> 2
      "medium" -> 3
      "low" -> 4
    updates.push({op: "add", path: "/fields/Microsoft.VSTS.Common.Severity", value: severity})

  if fields.assignee:
    # Requires prior call to resolve_user
    updates.push({op: "add", path: "/fields/System.AssignedTo", value: fields.assignee_id})

  return updates
```

## Work Item Types

### Bug

```markdown
Work Item Type: "Bug"
Normalized Type: "bug"

Required Fields:
- System.Title
- System.AreaPath
- System.IterationPath

Optional Fields:
- System.Description (HTML)
- Microsoft.VSTS.TCM.ReproSteps (HTML)
- Microsoft.VSTS.Common.Severity (1-4)
- Custom.Environment
- Custom.TeamsChannelMessageId
- Custom.TechOpsSpawnedFromIncident ("0" or "1")
- Custom.TechOpsFixContained ("0" or "1")

States: New → Active → In Progress → Resolved → Closed
```

### User Story

```markdown
Work Item Type: "User Story"
Normalized Type: "feature"

Required Fields:
- System.Title
- System.AreaPath
- System.IterationPath

Optional Fields:
- System.Description (HTML)
- Microsoft.VSTS.Common.AcceptanceCriteria (HTML)
- Microsoft.VSTS.Common.ValueArea ("Business" or "Architectural")
- Microsoft.VSTS.Scheduling.StoryPoints (integer)
- Custom.TeamsChannelMessageId

States: New → Active → Resolved → Closed
```

### Technical Debt Item

```markdown
Work Item Type: "Technical Debt Item"
Normalized Type: "tech-debt"

Required Fields:
- System.Title
- System.AreaPath
- System.IterationPath

Optional Fields:
- System.Description (HTML)
- Custom.AffectedArea (HTML)
- Microsoft.VSTS.CMMI.ProposedFix (HTML)
- Custom.Impact (semicolon-delimited: "Maintainability;Performance")
- Custom.BusinessImpact ("High", "Medium", "Low")
- Custom.TechnicalRisk ("High", "Medium", "Low")
- Microsoft.VSTS.Scheduling.StoryPoints (integer)

States: New → Active → In Progress → Resolved → Closed
```

## State Transitions

| From State | Valid Transitions |
|------------|-------------------|
| New | Active, In Progress |
| Active | In Progress, Resolved |
| In Progress | Resolved, Active |
| Resolved | Closed, Active |
| Closed | Active (reopen) |

## Error Handling

### Work Item Not Found

```markdown
## Work Item Not Found

**Error**: Work item #{id} does not exist in project {project}.

**Troubleshooting**:
1. Verify the work item ID is correct
2. Check you have access to the project
3. Confirm the work item hasn't been deleted

**URL**: https://dev.azure.com/{organization}/{project}/_workitems
```

### Invalid Work Item Type

```markdown
## Invalid Work Item Type

**Error**: Work item #{id} is type "{actual_type}", expected "{expected_type}".

**Solution**: Use the appropriate skill for this work item type:
- Bug: /pickup-bug
- User Story: /pickup-feature
```

### Identity Resolution Failed

```markdown
## Cannot Resolve User Identity

**Error**: Could not find identity ID for "{user_name}".

**Troubleshooting**:
1. Verify the user name is spelled correctly
2. Check the user exists in the Azure DevOps organization
3. Try using the user's email address instead
```

### Invalid State Transition

```markdown
## Invalid State Transition

**Error**: Cannot transition from "{current_state}" to "{target_state}".

**Valid transitions from {current_state}**:
- {list valid states}

**Solution**: Update to a valid intermediate state first.
```

## Usage Examples

### Get and Display Bug

```markdown
1. Call mcp__azure-devops__wit_get_work_item:
   - project: "ERM"
   - id: 25123
   - expand: "relations"

2. Validate type == "Bug"

3. Normalize to WorkItem model

4. Display:
   ## Bug #25123: {title}
   **State**: {state}
   **Severity**: {priority}
   **Assignee**: {assignee.name}
```

### Update Bug State

```markdown
1. Resolve user identity:
   mcp__azure-devops__core_get_identity_ids("Corbin Taylor")

2. Update work item:
   mcp__azure-devops__wit_update_work_item
   - id: 25123
   - updates: [
       {"op": "add", "path": "/fields/System.State", "value": "In Progress"},
       {"op": "add", "path": "/fields/System.AssignedTo", "value": "{identity_id}"}
     ]

3. Add comment:
   mcp__azure-devops__wit_add_work_item_comment
   - project: "ERM"
   - workItemId: 25123
   - comment: "Bug picked up by Corbin Taylor"
```

## Integration Reference

**Main Documentation**: `.claude/shared/work-items/README.md`
**Interface Spec**: `.claude/shared/work-items/interface.md`
**Field Mappings**: `.claude/shared/work-items/field-mappings.md`
**Legacy Reference**: `.claude/shared/azure-devops/README.md`
