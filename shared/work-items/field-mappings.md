# Work Item Field Mappings

Complete field mapping reference between normalized fields and provider-specific implementations.

## Core Field Mappings

### Identity Fields

| Normalized | Azure DevOps | Notion | Jira | Notes |
|------------|--------------|--------|------|-------|
| id | `id` (integer) | `id` (UUID) | `key` (string) | ADO uses numeric, Notion uses UUID, Jira uses PROJECT-123 |
| url | `_links.html.href` | `url` | `self` + `/browse/{key}` | Web URL to view item |
| provider | N/A | N/A | N/A | Set by abstraction layer |

### Core Fields

| Normalized | Azure DevOps | Notion | Jira | Format |
|------------|--------------|--------|------|--------|
| title | `System.Title` | Title property | `summary` | Plain text |
| description | `System.Description` | Rich text property | `description` | ADO: HTML, Notion: Rich text, Jira: Markdown |
| state | `System.State` | Status (select) | `status.name` | See State Mapping |
| type | `System.WorkItemType` | Type (select) | `issuetype.name` | See Type Mapping |
| priority | `Microsoft.VSTS.Common.Severity` | Priority (select) | `priority.name` | See Priority Mapping |

### User Fields

| Normalized | Azure DevOps | Notion | Jira | Notes |
|------------|--------------|--------|------|-------|
| assignee.id | `System.AssignedTo` (identity ID) | Person property (user ID) | `assignee.accountId` | Provider-specific ID format |
| assignee.name | Identity display name | User name | `assignee.displayName` | Display name |
| assignee.email | Identity email | User email | `assignee.emailAddress` | May not always be available |
| created_by.id | `System.CreatedBy` | `created_by.id` | `reporter.accountId` | Creator/reporter |
| created_by.name | Identity display name | `created_by.name` | `reporter.displayName` | Display name |

### Date Fields

| Normalized | Azure DevOps | Notion | Jira | Format |
|------------|--------------|--------|------|--------|
| created_date | `System.CreatedDate` | `created_time` | `created` | ISO 8601 |
| modified_date | `System.ChangedDate` | `last_edited_time` | `updated` | ISO 8601 |

## Type Mappings

### Bug Type

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| bug | TechOps Bug | Bug | Bug |

**Bug-Specific Fields:**

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| repro_steps | `Microsoft.VSTS.TCM.ReproSteps` | Repro Steps (rich text) | (in description) |
| environment | Extract from ReproSteps | Environment (select) | `environment` |
| severity | `Microsoft.VSTS.Common.Severity` | Severity (select) | `priority` |

### Feature/Story Type

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| feature | User Story | Feature | Story |

**Feature-Specific Fields:**

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| acceptance_criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` | Acceptance Criteria (rich text) | (custom field) |
| story_points | `Microsoft.VSTS.Scheduling.StoryPoints` | Story Points (number) | `customfield_10016` (varies) |
| value_area | `Microsoft.VSTS.Common.ValueArea` | Value Area (select) | (custom field) |

### Tech Debt Type

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| tech-debt | Technical Debt Item | Tech Debt | Technical Debt |

**Tech Debt-Specific Fields:**

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| affected_area | `Custom.AffectedArea` | Affected Area (multi-select) | `components` |
| proposed_fix | `Microsoft.VSTS.CMMI.ProposedFix` | Proposed Fix (rich text) | (custom field) |
| impact | `Custom.Impact` | Impact (multi-select) | `labels` |
| business_impact | `Custom.BusinessImpact` | Business Impact (select) | (custom field) |
| technical_risk | `Custom.TechnicalRisk` | Technical Risk (select) | (custom field) |

### Incident Type

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| incident | Incident | Incident | Incident |

**Incident-Specific Fields:**

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| start_time | `Custom.IncidentStartTime` | Start Time (date) | (custom field) |
| duration | `Custom.IncidentDuration` | Duration (number) | (custom field) |
| identification | `Custom.IncidentIdentification` | Identification (select) | (custom field) |
| impacted_services | `Custom.IncidentImpactedServices` | Impacted Services (multi-select) | `components` |

## State Mappings

### Normalized States

| Normalized | Description |
|------------|-------------|
| new | Just created, not started |
| active | Being worked on |
| in-progress | Actively in development |
| resolved | Work complete, pending verification |
| closed | Verified and closed |

### Provider State Mappings

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| new | New | To Do, Backlog | Open, To Do |
| active | Active | In Progress | In Progress |
| in-progress | In Progress | In Progress | In Progress |
| resolved | Resolved | Done, Review | Done, In Review |
| closed | Closed | Closed, Archived | Closed, Resolved |

### State Transition Rules

**Azure DevOps:**
- New → Active, In Progress
- Active → In Progress, Resolved
- In Progress → Resolved
- Resolved → Closed, Active (reopen)
- Closed → Active (reopen)

**Notion:**
- Any state → Any state (no restrictions)

**Jira:**
- Configurable per project workflow
- Common: Open → In Progress → Done → Closed

## Priority Mappings

| Normalized | Azure DevOps | Notion | Jira | Numeric |
|------------|--------------|--------|------|---------|
| critical | 1 | Critical, Urgent, P0 | Blocker, Highest | 1 |
| high | 2 | High, P1 | Critical, High | 2 |
| medium | 3 | Medium, P2, Normal | Major, Medium | 3 |
| low | 4 | Low, P3, P4 | Minor, Low, Lowest | 4 |

## Custom Fields

### Teams Integration

| Field | Azure DevOps | Notion | Jira |
|-------|--------------|--------|------|
| teams_message_id | `Custom.TeamsChannelMessageId` | TeamsMessageId (text) | (label or custom field) |

### Repository Link

| Field | Azure DevOps | Notion | Jira |
|-------|--------------|--------|------|
| repository | `Custom.Repository` | Repository (text/url) | (custom field or link) |

## Format Conversions

### Description Format

| Provider | Native Format | Conversion |
|----------|--------------|------------|
| Azure DevOps | HTML | Strip tags → Markdown |
| Notion | Rich text blocks | Extract → Markdown |
| Jira | Markdown (ADF) | Use as-is |

### Converting HTML to Markdown

```markdown
HTML to Markdown conversion:
- <p>...</p> → paragraph with newline
- <br> → newline
- <strong>...</strong> → **...**
- <em>...</em> → *...*
- <code>...</code> → `...`
- <ul><li>...</li></ul> → - ...
- <ol><li>...</li></ol> → 1. ...
- <a href="url">text</a> → [text](url)
- Strip all other tags
```

### Converting Markdown to HTML

```markdown
Markdown to HTML conversion (for Azure DevOps):
- **text** → <strong>text</strong>
- *text* → <em>text</em>
- `code` → <code>code</code>
- - item → <ul><li>item</li></ul>
- 1. item → <ol><li>item</li></ol>
- [text](url) → <a href="url">text</a>
- Wrap paragraphs in <p>...</p>
```

## Notion Property Types

When configuring Notion, specify property types in the mapping:

```json
{
  "notion": {
    "database_id": "...",
    "property_mappings": {
      "title": {"property": "Name", "type": "title"},
      "state": {"property": "Status", "type": "select"},
      "assignee": {"property": "Assignee", "type": "people"},
      "priority": {"property": "Priority", "type": "select"},
      "type": {"property": "Type", "type": "select"},
      "description": {"property": "Description", "type": "rich_text"},
      "created": {"property": "Created", "type": "created_time"},
      "modified": {"property": "Updated", "type": "last_edited_time"}
    }
  }
}
```

### Notion Property Type Reference

| Type | Usage | Notes |
|------|-------|-------|
| title | Work item title | Required, one per database |
| rich_text | Description, notes | Supports formatting |
| select | State, priority, type | Single selection |
| multi_select | Tags, labels, impact | Multiple selections |
| people | Assignee, created_by | User references |
| date | Due date, start time | Date/time values |
| number | Story points, duration | Numeric values |
| url | Links, repository | URL values |
| checkbox | Flags, booleans | True/false |
| created_time | Created date | Auto-generated |
| last_edited_time | Modified date | Auto-generated |

## MCP Function Reference

### Azure DevOps

| Operation | MCP Function |
|-----------|--------------|
| Get | `mcp__azure-devops__wit_get_work_item` |
| Create | `mcp__azure-devops__wit_create_work_item` |
| Update | `mcp__azure-devops__wit_update_work_item` |
| Comment | `mcp__azure-devops__wit_add_work_item_comment` |
| Search | `mcp__azure-devops__search_workitem` |
| User | `mcp__azure-devops__core_get_identity_ids` |

### Notion

| Operation | MCP Function |
|-----------|--------------|
| Get | `mcp__notion__notion-fetch` |
| Create | `mcp__notion__notion-create-pages` |
| Update | `mcp__notion__notion-update-page` |
| Comment | `mcp__notion__notion-create-comment` |
| Search | `mcp__notion__notion-query-data-sources` |
| User | `mcp__notion__notion-get-users` |

### Jira

| Operation | MCP Function |
|-----------|--------------|
| Get | `getJiraIssue` |
| Create | `createJiraIssue` |
| Update | `editJiraIssue` |
| Comment | `addCommentToJiraIssue` |
| Search | `searchJiraIssuesUsingJql` |
| User | `lookupJiraAccountId` |

## Notes

- Field names are case-sensitive for all providers
- Azure DevOps paths use backslash (e.g., `ERM\\Devops`)
- Notion property names must match exactly
- Jira custom field IDs vary by instance
- Always resolve user IDs before assignment operations
- State transitions may fail if transition is not allowed
