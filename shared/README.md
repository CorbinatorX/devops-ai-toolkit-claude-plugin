# Claude Code Shared Modules

Reusable helper modules and patterns for Skills and slash commands.

These modules eliminate code duplication and provide consistent patterns for common operations across {Product} workflows.

---

## Configuration

Commands and skills read configuration from `.claude/techops-config.json` in each consuming repository.

### Schema

```json
{
  "$comment": "TechOps-specific configuration",
  "version": "1.0",
  "contributor": "Your Name",
  "azure_devops": {
    "organization": "{organization}",
    "project": "ERM",
    "area_path": "ERM\\Devops",
    "iteration_path": "ERM\\dops-backlog"
  },
  "confluence": {
    "cloud_id": "",
    "space_key": "Tech",
    "postmortem_parent_page_id": "287244316"
  },
  "teams": {
    "flow_url": "https://prod-XX.uksouth.logic.azure.com:443/workflows/...",
    "team_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "channel_id": "19:xxxxx@thread.tacv2",
    "webhook_url": "https://{organization}ltd.webhook.office.com/..."
  },
  "created_at": "2025-12-22T00:00:00Z",
  "created_by": "migration",
  "plugin_version": "0.1.0"
}
```

### Field Reference

| Section | Field | Required | Description |
|---------|-------|----------|-------------|
| `azure_devops` | `organization` | Yes | Azure DevOps organization name |
| `azure_devops` | `project` | Yes | Azure DevOps project name |
| `azure_devops` | `area_path` | Yes | Default area path for work items |
| `azure_devops` | `iteration_path` | Yes | Default iteration path for work items |
| `teams` | `flow_url` | Yes* | Logic App trigger URL for Teams posting |
| `teams` | `team_id` | Yes* | Microsoft Teams Team ID (GUID) |
| `teams` | `channel_id` | Yes* | Microsoft Teams Channel ID |
| `teams` | `webhook_url` | No | Legacy webhook URL (fallback, no message ID) |
| `confluence` | `space_key` | No | Confluence space for post-mortems |
| `confluence` | `postmortem_parent_page_id` | No | Parent page ID for post-mortems |

*Required for Teams message ID capture. If not set, falls back to `webhook_url`.

### Finding Teams IDs

See `infra/logic-app/README.md` for instructions on finding your Team ID and Channel ID.

---

## Available Modules

### 1. Azure DevOps (`azure-devops/`)

**Purpose**: Work item operations, field validation, identity resolution

**Key Features**:
- Work item CRUD operations (get, update, create, comment)
- Identity ID resolution for assignments
- Field validation (severity, state transitions, work item types)
- Standard field mappings and path references
- Error handling templates

**MCP Tools Used**:
- `mcp__azure-devops__wit_get_work_item`
- `mcp__azure-devops__wit_update_work_item`
- `mcp__azure-devops__wit_add_work_item_comment`
- `mcp__azure-devops__core_get_identity_ids`
- `mcp__azure-devops__wit_create_work_item`

**Documentation**: [azure-devops/README.md](azure-devops/README.md)

**Usage Example**:
```markdown
# In a Skill's SKILL.md

## Azure DevOps Integration

This Skill uses Azure DevOps MCP tools for work item operations.

**Reference**: See `.claude/shared/azure-devops/README.md` for:
- Work item CRUD patterns
- Field mappings and validation
- Error handling templates

**Common Operations**:
1. Get work item: Use get_work_item pattern with expand="relations"
2. Update work item: Use update_work_item with field paths
3. Add comment: Use add_comment pattern
4. Resolve identity: Use get_identity_id for assignments
```

---

### 2. Git (`git/`)

**Purpose**: Branch creation, slug generation, commit analysis

**Key Features**:
- Branch slug generation algorithm (special char handling, truncation)
- Branch existence checking and creation
- Conventional commit patterns
- Git status and diff patterns
- Error handling for git operations

**Branch Patterns**:
- Bug: `bug/{work_item_id}-{slug}`
- Feature: `feature/{work_item_id}-{slug}`
- Task: `task/{work_item_id}-{slug}`

**Documentation**: [git/README.md](git/README.md)

**Usage Example**:
```markdown
# In a Skill's SKILL.md

## Git Integration

This Skill uses git for branch management.

**Reference**: See `.claude/shared/git/README.md` for:
- Branch slug generation algorithm
- Branch creation patterns
- Conventional commit format

**Branch Creation Process**:
1. Generate slug from title: GitHelper.generate_branch_slug(title)
2. Construct branch name: "{prefix}/{work_item_id}-{slug}"
3. Check if exists: git rev-parse --verify
4. Create or checkout: git checkout -b OR git checkout
```

---

### 3. Teams (`teams/`)

**Purpose**: Microsoft Teams webhook notifications

**Key Features**:
- MessageCard format templates (bug, feature, incident)
- Theme colors for different notification types
- Variable substitution patterns
- Non-blocking error handling
- Character limit handling

**Templates**:
- `templates/bug_card.json` - Bug notifications (red)
- `templates/feature_card.json` - Feature requests (gold)
- `templates/incident_card.json` - Incident alerts (crimson)

**Documentation**: [teams/README.md](teams/README.md)

**Usage Example**:
```markdown
# In a Skill's SKILL.md

## Teams Notifications (Optional)

This Skill can send Teams notifications after work item creation.

**Reference**: See `.claude/shared/teams/README.md` for:
- Message card templates
- Variable substitution
- Non-blocking error handling

**Note**: Teams notifications are optional and non-blocking.
If they fail, the main operation continues successfully.
```

---

### 4. Confluence (`confluence/`)

**Purpose**: Confluence page creation, post-mortem management

**Key Features**:
- Post-mortem template structure
- SLA calculation algorithm (business hours only)
- Multi-region SLA handling
- Timezone-aware duration calculations
- Page creation and update patterns

**MCP Tools Used**:
- `mcp__atlassian__getConfluenceSpaces`
- `mcp__atlassian__createConfluencePage`
- `mcp__atlassian__updateConfluencePage`

**Documentation**: [confluence/README.md](confluence/README.md)

**Usage Example**:
```markdown
# In a Skill's SKILL.md

## Confluence Integration

This Skill creates incident post-mortem pages in Confluence.

**Reference**: See `.claude/shared/confluence/README.md` for:
- Post-mortem template structure
- SLA calculation algorithm
- Multi-region patterns

**SLA Calculation**:
- Business hours: 9am-5pm local time
- Business days: Monday-Friday only
- Excludes weekends and non-business hours
- Timezone-aware per region
```

---

## Module Structure

```
.claude/shared/
├── README.md                    # This file - overview of all modules
├── azure-devops/
│   ├── README.md               # Azure DevOps patterns and MCP tool usage
│   └── field_mappings.json     # Standard field mappings (optional)
├── git/
│   └── README.md               # Git patterns and branch slug algorithm
├── teams/
│   ├── README.md               # Teams notification patterns
│   ├── templates/
│   │   ├── bug_card.json       # Bug notification template
│   │   ├── feature_card.json   # Feature notification template
│   │   └── incident_card.json  # Incident notification template
│   └── webhook_config.json     # Webhook URL (optional)
└── confluence/
    ├── README.md               # Confluence patterns and SLA calculation
    └── templates/
        └── post_mortem_template.md  # Post-mortem template
```

---

## Design Principles

### 1. Documentation Over Code

These modules provide **documentation and patterns** rather than executable code, because:
- Skills are instruction-based (Markdown)
- MCP tools are the executable layer
- Patterns are more flexible than rigid code
- Documentation can be referenced in SKILL.md files

### 2. Non-Blocking Operations

Optional integrations (Teams, Confluence) should **never block** main operations:
```markdown
# Always use || true or similar for optional operations
post_teams_message "$webhook_url" "$message" || echo "⚠️ Teams notification failed (non-blocking)"
```

### 3. Consistent Error Handling

All modules provide error handling templates that:
- Are user-friendly with clear troubleshooting steps
- Include specific error context
- Provide fallback options
- Never fail silently

### 4. Platform Awareness

Patterns are designed for Claude Code's environment:
- Use Bash commands (not Python scripts)
- Reference MCP tool names directly
- Work within Skill/command context
- Support both Skills and slash commands

---

## Usage in Skills

### Pattern 1: Reference in SKILL.md

```yaml
---
name: pickup-bug
description: Pick up TechOps Bug work items from Azure DevOps
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Pickup Bug Skill

## Shared Modules

This Skill uses several shared modules:

**Azure DevOps** (`.claude/shared/azure-devops/`):
- Work item retrieval, updates, comments
- Identity resolution for assignments
- Field validation

**Git** (`.claude/shared/git/`):
- Branch slug generation from bug title
- Branch creation or checkout

**Teams** (`.claude/shared/teams/`) - Optional:
- Bug notification posting (non-blocking)

See individual module READMEs for detailed patterns and examples.
```

### Pattern 2: Inline Pattern Reference

```markdown
## Step 3: Generate Branch Slug

Use the branch slug algorithm from `.claude/shared/git/README.md`:

1. Convert title to lowercase
2. Replace special characters (' " / \ & + %)
3. Replace spaces with hyphens
4. Remove non-alphanumeric except hyphens
5. Collapse multiple hyphens
6. Trim hyphens from ends
7. Truncate to 50 chars at word boundary

Example: "Feature flags don't display" → "feature-flags-dont-display"
```

---

## Integration Points

### Azure DevOps Project Configuration

```
PROJECT = "ERM"
AREA_PATH = "ERM\\Devops"  # Note: Backslash!
ITERATION_PATH = "ERM\\dops-backlog"
```

### Confluence Configuration

```
SPACE_KEY = "Tech"
SPACE_ID = {resolve from space key}
POST_MORTEM_PARENT_ID = "287244316"
```

### Teams Configuration

```
WEBHOOK_URL = {stored in webhook_config.json or extracted from commands}
```

---

## Testing

When implementing Skills that use shared modules:

### Azure DevOps Module
- [ ] Test work item retrieval with real work item ID
- [ ] Test identity resolution for "Corbin Taylor"
- [ ] Test field updates (state, assignee)
- [ ] Test error cases (invalid ID, wrong type)

### Git Module
- [ ] Test slug generation with special characters
- [ ] Test slug truncation at 50 chars
- [ ] Test branch creation (new)
- [ ] Test branch checkout (existing)
- [ ] Test from different base branches

### Teams Module
- [ ] Test message posting with real webhook
- [ ] Test variable substitution
- [ ] Test non-blocking behavior on error
- [ ] Test character truncation

### Confluence Module
- [ ] Test page creation in Tech space
- [ ] Test SLA calculation with edge cases (weekends, multi-day)
- [ ] Test multi-region SLA summation
- [ ] Test markdown rendering

---

## Common Patterns Across Modules

### Pattern: Non-Blocking Optional Operations

```bash
# Pattern for optional integrations that shouldn't fail main operation
optional_operation() {
    local result
    if ! result=$(perform_operation 2>&1); then
        echo "⚠️ Optional operation failed (non-blocking): $result" >&2
        return 0  # Don't propagate error
    fi
    echo "✅ Optional operation succeeded"
}
```

### Pattern: Field Validation

```markdown
# Validate before using
validate_field() {
    local value="$1"
    local valid_values=("value1" "value2" "value3")

    if [[ ! " ${valid_values[@]} " =~ " ${value} " ]]; then
        echo "Error: Invalid value '$value'. Must be one of: ${valid_values[*]}"
        return 1
    fi
    return 0
}
```

### Pattern: Template Variable Substitution

```bash
# Replace template variables
substitute_variables() {
    local template="$1"
    shift  # Remaining args are key=value pairs

    local result="$template"
    for pair in "$@"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        result=$(echo "$result" | sed "s/{{$key}}/$value/g")
    done
    echo "$result"
}

# Usage
content=$(substitute_variables "$template" \
    "work_item_id=25123" \
    "title=Bug title" \
    "severity=High")
```

---

## Benefits of Shared Modules

### For Skills

✅ **Consistency**: Same patterns across all Skills
✅ **Reliability**: Tested and proven patterns
✅ **Maintainability**: Update once, benefit everywhere
✅ **Discoverability**: Central documentation
✅ **Onboarding**: New Skills easier to create

### For Users

✅ **Predictability**: Same behavior across commands
✅ **Better Errors**: Consistent error messages
✅ **Transparency**: Can review shared patterns
✅ **Confidence**: Proven, tested patterns

### For Maintenance

✅ **Single Source of Truth**: No duplication
✅ **Easy Updates**: Change once, propagate everywhere
✅ **Version Control**: Track pattern evolution
✅ **Testing**: Test patterns independently

---

## Migration from Slash Commands

When converting slash commands to Skills:

1. **Identify shared code**: Look for repeated patterns (branch creation, work item updates)
2. **Extract to module**: Add pattern to appropriate shared module README
3. **Reference in Skill**: Link to shared module in SKILL.md
4. **Update tests**: Verify Skill uses shared pattern correctly
5. **Document integration**: Note which modules the Skill depends on

**Example**: The `/pickup-bug` command's branch slug generation logic was extracted to `.claude/shared/git/README.md` and is now used by both `pickup-bug` and `pickup-feature` Skills.

---

## Future Enhancements

Potential additions to shared modules:

1. **Test Utilities Module**:
   - Common test patterns
   - Coverage report parsing
   - Test result formatting

2. **Validation Module**:
   - Input sanitization
   - URL validation
   - Email validation
   - JSON schema validation

3. **Formatting Module**:
   - Date/time formatting
   - Number formatting
   - Duration formatting
   - File size formatting

4. **Graph API Module** (Teams):
   - Reply to existing messages
   - Thread notifications
   - Adaptive cards

---

## Support

For questions or issues with shared modules:

- **Documentation**: Each module has detailed README
- **Examples**: See Skills that use the modules (pickup-bug, blueprint, etc.)
- **Testing**: Refer to testing sections in module READMEs
- **Updates**: Check git history for pattern evolution

---

## Notes

- Shared modules are **documentation-focused**, not executable code
- Patterns reference MCP tools, Bash commands, and Skill conventions
- All patterns are designed for Claude Code's environment
- Optional integrations (Teams, Confluence) are always non-blocking
- Error handling is consistent and user-friendly across all modules
- Module documentation includes examples, edge cases, and testing guidance
