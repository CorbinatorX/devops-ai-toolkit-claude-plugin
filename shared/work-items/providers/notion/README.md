# Notion Work Item Provider

Provider implementation for Notion database items as work items using the Notion MCP server.

## Overview

This provider enables work item operations against Notion databases. Each database row represents a work item, with database properties mapping to work item fields.

**MCP Server**: `notion` (Official Notion MCP Server)

## Configuration

Notion settings in `.claude/techops-config.json`:

```json
{
  "work_items": {
    "provider": "notion",
    "providers": {
      "notion": {
        "database_id": "e45b26718b8d46a2ad9bd5d148845a76",
        "property_mappings": {
          "title": "Name",
          "state": "Status",
          "assignee": "Assignee",
          "type": "Type",
          "priority": "Priority",
          "description": "Description",
          "repository": "Repository"
        },
        "type_mappings": {
          "bug": "Bug",
          "feature": "Feature",
          "task": "Task",
          "tech-debt": "Tech Debt",
          "incident": "Incident"
        },
        "state_mappings": {
          "new": ["To Do", "Backlog", "Not Started"],
          "active": ["In Progress", "Active"],
          "in-progress": ["In Progress"],
          "resolved": ["Done", "Complete", "Review"],
          "closed": ["Closed", "Archived"]
        }
      }
    }
  }
}
```

### Reading Configuration

```bash
# Read Notion configuration
read_notion_config() {
    local config_file=".claude/techops-config.json"

    DATABASE_ID=$(jq -r '.work_items.providers.notion.database_id' "$config_file")
    PROPERTY_MAPPINGS=$(jq -r '.work_items.providers.notion.property_mappings' "$config_file")
    TYPE_MAPPINGS=$(jq -r '.work_items.providers.notion.type_mappings' "$config_file")
    STATE_MAPPINGS=$(jq -r '.work_items.providers.notion.state_mappings' "$config_file")
}
```

## MCP Functions

### Get Work Item (Fetch Page)

```markdown
Function: mcp__notion__notion-fetch

Parameters:
- pageId: string (Notion page UUID)

Response:
- id: string (page UUID)
- url: string (Notion page URL)
- properties: object (database properties)
  - {Title Property}: {title: [{text: {content: "..."}}]}
  - {Status Property}: {select: {name: "..."}}
  - {Assignee Property}: {people: [{name: "...", id: "..."}]}
  - {Priority Property}: {select: {name: "..."}}
  - {Type Property}: {select: {name: "..."}}
  - {Description Property}: {rich_text: [{text: {content: "..."}}]}
- created_time: string (ISO 8601)
- last_edited_time: string (ISO 8601)
- created_by: {id, name}
```

### Create Work Item (Create Page)

```markdown
Function: mcp__notion__notion-create-pages

Parameters:
- parentDatabaseId: string (database UUID)
- properties: object (property values)
  {
    "Name": {"title": [{"text": {"content": "Work item title"}}]},
    "Status": {"select": {"name": "To Do"}},
    "Type": {"select": {"name": "Bug"}},
    "Priority": {"select": {"name": "High"}},
    "Assignee": {"people": [{"id": "user-uuid"}]},
    "Description": {"rich_text": [{"text": {"content": "Description text"}}]}
  }

Returns:
- id: string (new page UUID)
- url: string (page URL)
```

### Update Work Item (Update Page)

```markdown
Function: mcp__notion__notion-update-page

Parameters:
- pageId: string (page UUID)
- properties: object (properties to update)
  {
    "Status": {"select": {"name": "In Progress"}},
    "Assignee": {"people": [{"id": "user-uuid"}]}
  }

Returns:
- Updated page object
```

### Add Comment

```markdown
Function: mcp__notion__notion-create-comment

Parameters:
- pageId: string (page UUID to comment on)
- content: string (comment text in Markdown)

Returns:
- Comment ID
```

### Search Work Items (Query Database)

```markdown
Function: mcp__notion__notion-query-data-sources

Parameters:
- databaseId: string (database UUID)
- filter: object (optional filter)
  {
    "property": "Status",
    "select": {"equals": "In Progress"}
  }
- sorts: array (optional sorting)
  [{"property": "Created", "direction": "descending"}]

Returns:
- results: array of page objects
```

### Get Users

```markdown
Function: mcp__notion__notion-get-users

Parameters: (none)

Returns:
- Array of user objects
  - id: string
  - name: string
  - avatar_url: string
  - type: "person" | "bot"
```

## Property Types

### Title Property

```json
{
  "Name": {
    "title": [
      {
        "text": {
          "content": "Work item title"
        }
      }
    ]
  }
}
```

### Select Property (State, Type, Priority)

```json
{
  "Status": {
    "select": {
      "name": "In Progress"
    }
  }
}
```

### People Property (Assignee)

```json
{
  "Assignee": {
    "people": [
      {
        "id": "user-uuid-here"
      }
    ]
  }
}
```

### Rich Text Property (Description)

```json
{
  "Description": {
    "rich_text": [
      {
        "text": {
          "content": "Description text with **markdown** support"
        }
      }
    ]
  }
}
```

### Multi-Select Property (Tags, Labels)

```json
{
  "Tags": {
    "multi_select": [
      {"name": "urgent"},
      {"name": "frontend"}
    ]
  }
}
```

### Number Property (Story Points)

```json
{
  "Story Points": {
    "number": 5
  }
}
```

### URL Property (Repository Link)

```json
{
  "Repository": {
    "url": "https://github.com/org/repo"
  }
}
```

## Field Mappings

### Normalizing Notion to WorkItem

```markdown
normalize_notion_work_item(notion_page, config) -> WorkItem:

  id = notion_page.id
  provider = "notion"
  url = notion_page.url

  # Get property names from config
  title_prop = config.property_mappings.title  # e.g., "Name"
  state_prop = config.property_mappings.state  # e.g., "Status"
  type_prop = config.property_mappings.type    # e.g., "Type"
  # etc.

  # Extract title
  title = notion_page.properties[title_prop].title[0].text.content

  # Map state
  notion_state = notion_page.properties[state_prop].select.name
  state = reverse_lookup_state(notion_state, config.state_mappings)
  # Returns: "new", "active", "in-progress", "resolved", or "closed"

  # Map type
  notion_type = notion_page.properties[type_prop].select.name
  type = reverse_lookup_type(notion_type, config.type_mappings)
  # Returns: "bug", "feature", "task", "tech-debt", or "incident"

  # Extract description (rich text to Markdown)
  description = extract_rich_text(notion_page.properties[description_prop])

  # Map priority
  priority_prop = config.property_mappings.priority
  notion_priority = notion_page.properties[priority_prop].select.name
  priority = case notion_priority:
    "Critical", "Urgent", "P0" -> "critical"
    "High", "P1" -> "high"
    "Medium", "Normal", "P2" -> "medium"
    "Low", "P3", "P4" -> "low"
    else -> "medium"

  # Extract assignee
  assignee_prop = config.property_mappings.assignee
  people = notion_page.properties[assignee_prop].people
  if people.length > 0:
    assignee = {
      id: people[0].id,
      name: people[0].name
    }

  created_date = notion_page.created_time
  modified_date = notion_page.last_edited_time

  # Store unmapped properties
  provider_fields = {
    all_properties: notion_page.properties
  }

  return WorkItem
```

### Denormalizing WorkItem to Notion

```markdown
denormalize_to_notion(fields: UpdateFields, config) -> Notion_Properties:

  properties = {}

  if fields.title:
    title_prop = config.property_mappings.title
    properties[title_prop] = {
      "title": [{"text": {"content": fields.title}}]
    }

  if fields.description:
    desc_prop = config.property_mappings.description
    properties[desc_prop] = {
      "rich_text": [{"text": {"content": fields.description}}]
    }

  if fields.state:
    state_prop = config.property_mappings.state
    notion_state = config.state_mappings[fields.state][0]  # First mapping
    properties[state_prop] = {
      "select": {"name": notion_state}
    }

  if fields.type:
    type_prop = config.property_mappings.type
    notion_type = config.type_mappings[fields.type]
    properties[type_prop] = {
      "select": {"name": notion_type}
    }

  if fields.priority:
    priority_prop = config.property_mappings.priority
    notion_priority = case fields.priority:
      "critical" -> "Critical"
      "high" -> "High"
      "medium" -> "Medium"
      "low" -> "Low"
    properties[priority_prop] = {
      "select": {"name": notion_priority}
    }

  if fields.assignee_id:
    assignee_prop = config.property_mappings.assignee
    properties[assignee_prop] = {
      "people": [{"id": fields.assignee_id}]
    }

  return properties
```

## Database Setup

### Required Properties

Your Notion database should have these properties (names configurable):

| Property | Type | Purpose |
|----------|------|---------|
| Name (Title) | Title | Work item title (required) |
| Status | Select | Work item state |
| Type | Select | Bug, Feature, Task, etc. |
| Priority | Select | Critical, High, Medium, Low |
| Assignee | People | Assigned person |
| Description | Rich Text | Full description |

### Recommended Additional Properties

| Property | Type | Purpose |
|----------|------|---------|
| Repository | URL | Link to git repository |
| Teams Message ID | Text | Teams thread ID for notifications |
| Created | Created time | Auto-generated |
| Updated | Last edited time | Auto-generated |
| Story Points | Number | Estimation |
| Tags | Multi-select | Labels/categories |

### Status Options

Configure these select options for Status:

| Option | Maps to Normalized State |
|--------|-------------------------|
| To Do | new |
| Backlog | new |
| In Progress | active, in-progress |
| Review | resolved |
| Done | resolved |
| Closed | closed |
| Archived | closed |

### Type Options

Configure these select options for Type:

| Option | Maps to Normalized Type |
|--------|------------------------|
| Bug | bug |
| Feature | feature |
| Task | task |
| Tech Debt | tech-debt |
| Incident | incident |

### Priority Options

Configure these select options for Priority:

| Option | Maps to Normalized Priority |
|--------|----------------------------|
| Critical / Urgent / P0 | critical |
| High / P1 | high |
| Medium / Normal / P2 | medium |
| Low / P3 / P4 | low |

## Error Handling

### Page Not Found

```markdown
## Work Item Not Found

**Error**: Notion page with ID "{id}" not found.

**Troubleshooting**:
1. Verify the page ID is correct
2. Check the page hasn't been deleted or moved to trash
3. Ensure Claude Code has access to the page
4. Verify MCP server authentication

**Database URL**: https://notion.so/{database_id}
```

### Database Not Accessible

```markdown
## Database Not Accessible

**Error**: Cannot access Notion database "{database_id}".

**Troubleshooting**:
1. Verify the database ID is correct
2. Check Claude Code integration has access to the database
3. Ensure the database is shared with the integration
4. Review Notion integration settings
```

### Property Not Found

```markdown
## Property Not Found

**Error**: Property "{property_name}" not found in database.

**Solution**: Update property_mappings in techops-config.json to match your database schema:

```json
{
  "property_mappings": {
    "title": "Your Title Property Name",
    "state": "Your Status Property Name"
  }
}
```
```

### User Not Found

```markdown
## User Not Found

**Error**: Could not find Notion user "{name}".

**Troubleshooting**:
1. Verify the user is a member of the workspace
2. Check the user's name or email is correct
3. Use mcp__notion__notion-get-users to list available users
```

## Usage Examples

### Get and Display Work Item

```markdown
1. Read config and get database_id, property_mappings

2. Call mcp__notion__notion-fetch:
   - pageId: "work-item-uuid"

3. Normalize to WorkItem model using property mappings

4. Display:
   ## {type}: {title}
   **Status**: {state}
   **Priority**: {priority}
   **Assignee**: {assignee.name}
```

### Create Bug

```markdown
1. Read config for database_id and mappings

2. Build properties object:
   {
     "Name": {"title": [{"text": {"content": "Bug title"}}]},
     "Status": {"select": {"name": "To Do"}},
     "Type": {"select": {"name": "Bug"}},
     "Priority": {"select": {"name": "High"}},
     "Description": {"rich_text": [{"text": {"content": "Bug description"}}]}
   }

3. Call mcp__notion__notion-create-pages:
   - parentDatabaseId: "{database_id}"
   - properties: {built properties}

4. Return new page ID
```

### Update Status and Assign

```markdown
1. Get user ID:
   - Call mcp__notion__notion-get-users
   - Find user by name
   - Extract user ID

2. Build update properties:
   {
     "Status": {"select": {"name": "In Progress"}},
     "Assignee": {"people": [{"id": "user-uuid"}]}
   }

3. Call mcp__notion__notion-update-page:
   - pageId: "{work-item-id}"
   - properties: {update properties}
```

### Search by Status

```markdown
1. Build filter:
   {
     "property": "Status",
     "select": {"equals": "In Progress"}
   }

2. Call mcp__notion__notion-query-data-sources:
   - databaseId: "{database_id}"
   - filter: {filter object}

3. Normalize results to WorkItem array
```

## Teams Integration

Notion supports Teams notifications through a custom property:

```markdown
1. Add "Teams Message ID" text property to database

2. When creating work item:
   - Post to Teams via Logic App
   - Capture message ID from response
   - Update Notion page with Teams Message ID property

3. When picking up work item:
   - Read Teams Message ID from page
   - Use for thread reply notifications

Property configuration:
{
  "property_mappings": {
    "teams_message_id": "Teams Message ID"
  }
}
```

## Rate Limits

Notion API rate limit: **3 requests per second** (average)

Best practices:
- Batch operations where possible
- Cache user lookups
- Use filters to reduce result sets
- Implement exponential backoff on 429 errors

## Integration Reference

**Main Documentation**: `.claude/shared/work-items/README.md`
**Interface Spec**: `.claude/shared/work-items/interface.md`
**Field Mappings**: `.claude/shared/work-items/field-mappings.md`
