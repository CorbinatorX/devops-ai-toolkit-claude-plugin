# Work Item Provider Abstraction Layer

Unified interface for work item operations across multiple providers (Azure DevOps, Notion, Jira). Skills and commands use this abstraction layer to work with any configured work item provider.

## Overview

This module provides:
- Provider-agnostic work item operations
- Automatic provider selection based on configuration
- Unified data model across providers
- Field mapping between provider-specific and normalized formats

## Supported Providers

| Provider | Status | MCP Server | Documentation |
|----------|--------|------------|---------------|
| Azure DevOps | Stable | `azure-devops` | `providers/azure-devops/README.md` |
| Notion | Stable | `notion` | `providers/notion/README.md` |
| Jira | Planned | `atlassian` | `providers/jira/README.md` |

## Configuration

Work item provider settings in `.claude/techops-config.json`:

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
      },
      "notion": {
        "database_id": "{database_id}",
        "property_mappings": {
          "title": "Name",
          "state": "Status",
          "assignee": "Assignee",
          "type": "Type",
          "priority": "Priority"
        }
      },
      "jira": {
        "site_url": "https://{company}.atlassian.net",
        "project_key": "PROD",
        "issue_type_mappings": {
          "bug": "Bug",
          "feature": "Story",
          "tech-debt": "Technical Debt"
        }
      }
    }
  }
}
```

### Backward Compatibility

If `work_items.provider` is not set, the system defaults to `azure-devops` and uses the existing `azure_devops` configuration section for backward compatibility:

```bash
# Check provider selection
provider=$(jq -r '.work_items.provider // "azure-devops"' .claude/techops-config.json)

if [ "$provider" = "azure-devops" ]; then
    # Use existing azure_devops config for backward compatibility
    PROJECT=$(jq -r '.azure_devops.project // .work_items.providers["azure-devops"].project' .claude/techops-config.json)
fi
```

## Provider Selection

### Reading Provider Configuration

```bash
# Get active provider
get_work_item_provider() {
    local config_file=".claude/techops-config.json"

    if [ ! -f "$config_file" ]; then
        echo "azure-devops"  # Default
        return
    fi

    local provider=$(jq -r '.work_items.provider // "azure-devops"' "$config_file")
    echo "$provider"
}

# Usage
provider=$(get_work_item_provider)
echo "Using work item provider: $provider"
```

### Provider Dispatch Pattern

Skills should use this pattern to dispatch to the correct provider:

```markdown
## Work Item Operations

1. Read provider from config: `.work_items.provider`
2. Dispatch to provider-specific implementation:
   - If "azure-devops": Use Azure DevOps MCP tools
   - If "notion": Use Notion MCP tools
   - If "jira": Use Atlassian MCP tools
3. Normalize response to unified WorkItem model
4. Return normalized data to skill

**Reference**: See `.claude/shared/work-items/interface.md` for the unified WorkItem model.
```

## Unified Operations

All providers must support these core operations:

### Get Work Item

```markdown
get_work_item(id: string) -> WorkItem

Parameters:
- id: Work item identifier (provider-specific format)

Returns: Normalized WorkItem object

Provider Mapping:
- Azure DevOps: mcp__azure-devops__wit_get_work_item
- Notion: mcp__notion__notion-fetch (page by ID)
- Jira: getJiraIssue
```

### Create Work Item

```markdown
create_work_item(type: string, fields: Record<string, any>) -> string

Parameters:
- type: Work item type ("bug", "feature", "task", "tech-debt")
- fields: Normalized field values

Returns: New work item ID

Provider Mapping:
- Azure DevOps: mcp__azure-devops__wit_create_work_item
- Notion: mcp__notion__notion-create-pages
- Jira: createJiraIssue
```

### Update Work Item

```markdown
update_work_item(id: string, fields: Record<string, any>) -> boolean

Parameters:
- id: Work item identifier
- fields: Fields to update (normalized names)

Returns: Success boolean

Provider Mapping:
- Azure DevOps: mcp__azure-devops__wit_update_work_item
- Notion: mcp__notion__notion-update-page
- Jira: editJiraIssue
```

### Add Comment

```markdown
add_comment(id: string, text: string) -> string

Parameters:
- id: Work item identifier
- text: Comment text (Markdown format)

Returns: Comment ID

Provider Mapping:
- Azure DevOps: mcp__azure-devops__wit_add_work_item_comment
- Notion: mcp__notion__notion-create-comment
- Jira: addCommentToJiraIssue
```

### Search Work Items

```markdown
search_work_items(query: string, filters?: SearchFilters) -> WorkItem[]

Parameters:
- query: Search text
- filters: Optional filters (type, state, assignee)

Returns: Array of matching WorkItems

Provider Mapping:
- Azure DevOps: mcp__azure-devops__search_workitem
- Notion: mcp__notion__notion-query-data-sources
- Jira: searchJiraIssuesUsingJql
```

### Resolve User

```markdown
resolve_user(name: string) -> User

Parameters:
- name: User display name or email

Returns: User object with provider-specific ID

Provider Mapping:
- Azure DevOps: mcp__azure-devops__core_get_identity_ids
- Notion: mcp__notion__notion-get-users
- Jira: lookupJiraAccountId
```

## Field Normalization

When reading work items, normalize provider-specific fields to unified names:

```markdown
Normalized Field -> Provider Field:

title        -> ADO: System.Title, Notion: title property, Jira: summary
description  -> ADO: System.Description, Notion: rich text, Jira: description
state        -> ADO: System.State, Notion: Status select, Jira: status.name
assignee     -> ADO: System.AssignedTo, Notion: Person property, Jira: assignee
priority     -> ADO: Microsoft.VSTS.Common.Severity, Notion: Priority select, Jira: priority
type         -> ADO: System.WorkItemType, Notion: Type select, Jira: issuetype
created      -> ADO: System.CreatedDate, Notion: created_time, Jira: created
modified     -> ADO: System.ChangedDate, Notion: last_edited_time, Jira: updated
```

**Reference**: See `.claude/shared/work-items/field-mappings.md` for complete field mapping tables.

## Usage in Skills

Skills should use the abstraction layer instead of calling providers directly:

```markdown
# In SKILL.md

## Work Item Integration

This Skill uses the work item abstraction layer for provider-agnostic operations.

**Reference**: See `.claude/shared/work-items/README.md` for:
- Provider selection and configuration
- Unified operations (get, create, update, comment)
- Field normalization

### Step 1: Get Work Item

1. Read provider from `.claude/techops-config.json`
2. Call provider-specific get operation
3. Normalize response to unified model
4. Extract required fields using normalized names

**Provider-Specific Documentation**:
- Azure DevOps: `.claude/shared/work-items/providers/azure-devops/README.md`
- Notion: `.claude/shared/work-items/providers/notion/README.md`
- Jira: `.claude/shared/work-items/providers/jira/README.md`
```

## Error Handling

### Provider Not Configured

```markdown
## Provider Not Configured

**Error**: Work item provider "{provider}" is not configured.

**Solution**: Add provider configuration to `.claude/techops-config.json`:

```json
{
  "work_items": {
    "provider": "{provider}",
    "providers": {
      "{provider}": {
        // Provider-specific settings
      }
    }
  }
}
```

Or run `/configure-techops` to set up the configuration.
```

### MCP Server Not Available

```markdown
## MCP Server Not Available

**Error**: Cannot connect to {provider} MCP server.

**Troubleshooting**:
1. Verify MCP server is installed and configured
2. Check authentication credentials
3. Test connection manually
4. Review Claude Code MCP settings
```

### Work Item Not Found

```markdown
## Work Item Not Found

**Error**: Work item "{id}" not found in {provider}.

**Troubleshooting**:
1. Verify the work item ID is correct
2. Check you have access to the work item
3. Confirm the work item hasn't been deleted
```

## Teams Integration

Teams notifications work with all providers. The Teams message is sent independently of the work item provider.

```markdown
Teams Integration Pattern:

1. Create/update work item in configured provider
2. Post notification to Teams via Logic App
3. Store Teams message ID in work item (if supported):
   - Azure DevOps: Custom.TeamsChannelMessageId field
   - Notion: TeamsMessageId property
   - Jira: Custom field or label

This enables thread replies when picking up work items.
```

## Migration Guide

### Migrating from Direct Azure DevOps Usage

If your skills currently use Azure DevOps directly, update them to use the abstraction:

**Before**:
```markdown
Use `mcp__azure-devops__wit_get_work_item`:
- project: "ERM"
- id: {work_item_id}
```

**After**:
```markdown
1. Read provider: `.work_items.provider`
2. If "azure-devops":
   - Use `mcp__azure-devops__wit_get_work_item`
   - project: from config
   - id: {work_item_id}
3. Normalize response to WorkItem model
```

## Provider Documentation

Detailed provider-specific documentation:

- **Azure DevOps**: `.claude/shared/work-items/providers/azure-devops/README.md`
- **Notion**: `.claude/shared/work-items/providers/notion/README.md`
- **Jira**: `.claude/shared/work-items/providers/jira/README.md`

## Notes

- Default provider is "azure-devops" for backward compatibility
- Provider selection is per-project (in techops-config.json)
- Field mappings handle format differences (HTML vs Markdown)
- State transitions vary by provider - check provider docs
- User resolution requires provider-specific ID formats
