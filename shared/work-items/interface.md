# Work Item Interface Specification

Unified data model and operation interfaces for work item providers.

## WorkItem Model

The normalized work item model used across all providers:

```typescript
interface WorkItem {
  // Identity
  id: string;                              // Provider-specific ID
  provider: "azure-devops" | "notion" | "jira";
  url: string;                             // Web URL to view work item

  // Core Fields
  type: WorkItemType;                      // Normalized type
  title: string;                           // Work item title
  description: string;                     // Markdown format (normalized from HTML/rich text)
  state: WorkItemState;                    // Normalized state

  // Assignment
  assignee?: User;                         // Assigned user
  created_by?: User;                       // Creator

  // Metadata
  created_date: string;                    // ISO 8601 format
  modified_date: string;                   // ISO 8601 format
  priority?: Priority;                     // Normalized priority

  // Provider-Specific
  provider_fields: Record<string, any>;    // Unmapped provider fields

  // Relations (optional)
  parent_id?: string;                      // Parent work item ID
  child_ids?: string[];                    // Child work item IDs
  related_ids?: string[];                  // Related work item IDs
}
```

## Enums and Types

### WorkItemType

```typescript
type WorkItemType = "bug" | "feature" | "task" | "tech-debt" | "incident" | "other";

// Provider Mappings:
// "bug"       -> ADO: "Bug", Notion: "Bug", Jira: "Bug"
// "feature"   -> ADO: "User Story", Notion: "Feature", Jira: "Story"
// "task"      -> ADO: "Task", Notion: "Task", Jira: "Task"
// "tech-debt" -> ADO: "Technical Debt Item", Notion: "Tech Debt", Jira: "Technical Debt"
// "incident"  -> ADO: "Incident", Notion: "Incident", Jira: "Incident"
// "other"     -> Any unmapped type
```

### WorkItemState

```typescript
type WorkItemState = "new" | "active" | "in-progress" | "resolved" | "closed";

// Provider Mappings:
// "new"         -> ADO: "New", Notion: "To Do"/"Backlog", Jira: "To Do"/"Open"
// "active"      -> ADO: "Active", Notion: "In Progress", Jira: "In Progress"
// "in-progress" -> ADO: "In Progress", Notion: "In Progress", Jira: "In Progress"
// "resolved"    -> ADO: "Resolved", Notion: "Done", Jira: "Done"
// "closed"      -> ADO: "Closed", Notion: "Closed"/"Archived", Jira: "Closed"
```

### Priority

```typescript
type Priority = "critical" | "high" | "medium" | "low";

// Provider Mappings:
// "critical" -> ADO: 1, Notion: "Critical"/"Urgent", Jira: "Blocker"/"Highest"
// "high"     -> ADO: 2, Notion: "High", Jira: "Critical"/"High"
// "medium"   -> ADO: 3, Notion: "Medium", Jira: "Major"/"Medium"
// "low"      -> ADO: 4, Notion: "Low", Jira: "Minor"/"Low"
```

### User

```typescript
interface User {
  id: string;                  // Provider-specific ID
  name: string;                // Display name
  email?: string;              // Email address (if available)
}
```

## Provider Interface

All providers must implement these operations:

```typescript
interface WorkItemProvider {
  // Configuration
  readonly provider: "azure-devops" | "notion" | "jira";

  // Read Operations
  getWorkItem(id: string): Promise<WorkItem>;
  searchWorkItems(query: string, filters?: SearchFilters): Promise<WorkItem[]>;

  // Write Operations
  createWorkItem(type: WorkItemType, fields: CreateFields): Promise<string>;
  updateWorkItem(id: string, fields: UpdateFields): Promise<boolean>;
  addComment(id: string, text: string): Promise<string>;

  // Metadata
  resolveUser(nameOrEmail: string): Promise<User>;
  getValidStates(type: WorkItemType): Promise<WorkItemState[]>;
  getValidTransitions(id: string): Promise<WorkItemState[]>;
}
```

### SearchFilters

```typescript
interface SearchFilters {
  type?: WorkItemType[];           // Filter by type
  state?: WorkItemState[];         // Filter by state
  assignee?: string;               // Filter by assignee name
  created_after?: string;          // ISO date
  modified_after?: string;         // ISO date
  limit?: number;                  // Max results (default: 50)
}
```

### CreateFields

```typescript
interface CreateFields {
  title: string;                   // Required
  description?: string;            // Markdown format
  priority?: Priority;
  assignee?: string;               // User name or email

  // Provider-specific fields
  [key: string]: any;
}
```

### UpdateFields

```typescript
interface UpdateFields {
  title?: string;
  description?: string;
  state?: WorkItemState;
  priority?: Priority;
  assignee?: string;

  // Provider-specific fields
  [key: string]: any;
}
```

## Field Normalization Functions

### normalizeWorkItem

Converts provider-specific response to unified WorkItem:

```markdown
normalizeWorkItem(providerData: any, provider: string) -> WorkItem:

  1. Extract ID and URL from provider data
  2. Map type to normalized WorkItemType
  3. Map state to normalized WorkItemState
  4. Extract title as-is
  5. Convert description to Markdown:
     - If HTML (Azure DevOps): strip tags, convert to Markdown
     - If rich text (Notion): extract plain text with formatting
     - If Markdown (Jira): use as-is
  6. Map priority to normalized Priority
  7. Extract assignee with name and ID
  8. Extract dates in ISO 8601 format
  9. Store unmapped fields in provider_fields
  10. Return normalized WorkItem
```

### denormalizeFields

Converts normalized fields to provider-specific format:

```markdown
denormalizeFields(fields: UpdateFields, provider: string) -> ProviderFields:

  1. For each field in UpdateFields:
     - Look up provider-specific field name
     - Convert value to provider format:
       - description: Markdown → HTML (for ADO) or rich text (for Notion)
       - state: Normalized → Provider-specific state name
       - priority: Normalized → Provider-specific value
       - assignee: Name → Provider ID (requires resolveUser call)
  2. Return provider-specific field object
```

## Type Mapping Reference

### Work Item Types

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| bug | Bug | Bug | Bug |
| feature | User Story | Feature | Story |
| task | Task | Task | Task |
| tech-debt | Technical Debt Item | Tech Debt | Technical Debt |
| incident | Incident | Incident | Incident |

### States

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| new | New | To Do | Open/To Do |
| active | Active | In Progress | In Progress |
| in-progress | In Progress | In Progress | In Progress |
| resolved | Resolved | Done | Done |
| closed | Closed | Closed | Closed |

### Priorities

| Normalized | Azure DevOps | Notion | Jira |
|------------|--------------|--------|------|
| critical | 1 | Critical | Blocker |
| high | 2 | High | Critical |
| medium | 3 | Medium | Major |
| low | 4 | Low | Minor |

## Usage Example

```markdown
# In a Skill

### Get and Display Work Item

1. Read provider from config
2. Call provider-specific get operation
3. Normalize to WorkItem model
4. Display using normalized field names

Example:
```bash
provider=$(jq -r '.work_items.provider // "azure-devops"' .claude/techops-config.json)

case "$provider" in
  "azure-devops")
    # Call ADO MCP and normalize
    ;;
  "notion")
    # Call Notion MCP and normalize
    ;;
  "jira")
    # Call Jira MCP and normalize
    ;;
esac

# Display using normalized fields
echo "## ${work_item.type}: ${work_item.title}"
echo "State: ${work_item.state}"
echo "Assignee: ${work_item.assignee.name}"
```
```

## Error Types

```typescript
// Work item not found
interface WorkItemNotFoundError {
  code: "WORK_ITEM_NOT_FOUND";
  id: string;
  provider: string;
  message: string;
}

// Invalid operation
interface InvalidOperationError {
  code: "INVALID_OPERATION";
  operation: string;
  reason: string;
  message: string;
}

// Provider error
interface ProviderError {
  code: "PROVIDER_ERROR";
  provider: string;
  originalError: any;
  message: string;
}

// Authentication error
interface AuthenticationError {
  code: "AUTH_ERROR";
  provider: string;
  message: string;
}
```

## Notes

- All dates use ISO 8601 format (e.g., "2024-01-15T10:30:00Z")
- Description fields are normalized to Markdown
- User resolution requires a separate call to resolveUser
- Provider-specific fields are preserved in provider_fields
- State transitions should be validated using getValidTransitions
