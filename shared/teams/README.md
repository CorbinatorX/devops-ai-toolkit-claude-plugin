# Teams Notification Helpers for Claude Code Skills

Reusable patterns for posting notifications to Microsoft Teams.

## Recommended: Power Automate Flow

For capturing Teams message IDs (to link work items to their discussion threads), use the Power Automate approach:

**See**: [POWER_AUTOMATE_SETUP.md](POWER_AUTOMATE_SETUP.md)

This enables:
- Capturing the Teams message ID after posting
- Updating work items with `Custom.TeamsChannelMessageId`
- Direct links to discussion threads from work items

## Legacy: Incoming Webhooks

The patterns below use incoming webhooks, which are simpler but **cannot return the message ID**.

## Webhook Configuration

**Location**: `.claude/shared/teams/webhook_config.json`

```json
{
  "webhookUrl": "{teams_webhook_url}",
  "defaultTimeout": 30
}
```

**Note**: The webhook URL should be extracted from existing commands (create-bug, create-feature-request, create-incident).

## Message Card Format

Teams uses the **MessageCard** format for webhook messages.

### Basic Structure

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "{color_hex}",
  "summary": "{notification_summary}",
  "sections": [
    {
      "activityTitle": "{title}",
      "activitySubtitle": "{subtitle}",
      "facts": [
        {"name": "Field Name", "value": "Field Value"}
      ],
      "markdown": true
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "View in Azure DevOps",
      "targets": [
        {"os": "default", "uri": "{work_item_url}"}
      ]
    }
  ]
}
```

### Theme Colors

| Notification Type | Color Hex | Visual |
|-------------------|-----------|--------|
| Bug | `#FF0000` | Red |
| Feature Request | `#FFD700` | Gold |
| Incident | `#DC143C` | Crimson |
| Success | `#28A745` | Green |
| Warning | `#FFC107` | Amber |
| Info | `#17A2B8` | Cyan |

## Notification Patterns

### Pattern 1: Bug Notification

**Use Case**: Notify team when new Bug is created

**Template**: `.claude/shared/teams/templates/bug_card.json`

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "FF0000",
  "summary": "New Bug: {{title}}",
  "sections": [
    {
      "activityTitle": "🐛 Bug #{{work_item_id}}",
      "activitySubtitle": "{{title}}",
      "facts": [
        {"name": "Severity", "value": "{{severity_text}}"},
        {"name": "Environment", "value": "{{environment}}"},
        {"name": "Reported By", "value": "{{created_by}}"},
        {"name": "Created", "value": "{{created_date}}"}
      ],
      "markdown": true,
      "text": "{{description}}"
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "View Bug in Azure DevOps",
      "targets": [
        {"os": "default", "uri": "https://dev.azure.com/{organization}/{project}/_workitems/edit/{{work_item_id}}"}
      ]
    }
  ]
}
```

**Variables**:
- `{{work_item_id}}` - Work item ID
- `{{title}}` - Bug title
- `{{severity_text}}` - "Critical", "High", "Medium", or "Low"
- `{{environment}}` - Production, Staging, Dev, etc.
- `{{created_by}}` - User who created the bug
- `{{created_date}}` - ISO date formatted nicely
- `{{description}}` - Bug description (truncated to 500 chars)

### Pattern 2: Feature Request Notification

**Use Case**: Notify team when new User Story/Feature Request is created

**Template**: `.claude/shared/teams/templates/feature_card.json`

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "FFD700",
  "summary": "New Feature Request: {{title}}",
  "sections": [
    {
      "activityTitle": "💡 Feature Request #{{work_item_id}}",
      "activitySubtitle": "{{title}}",
      "facts": [
        {"name": "Summary", "value": "{{summary}}"},
        {"name": "Value/Why", "value": "{{value_why}}"},
        {"name": "Requested By", "value": "{{created_by}}"},
        {"name": "Created", "value": "{{created_date}}"}
      ],
      "markdown": true,
      "text": "{{description}}"
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "View User Story in Azure DevOps",
      "targets": [
        {"os": "default", "uri": "https://dev.azure.com/{organization}/{project}/_workitems/edit/{{work_item_id}}"}
      ]
    }
  ]
}
```

**Variables**:
- `{{work_item_id}}` - Work item ID
- `{{title}}` - Feature/Story title
- `{{summary}}` - Brief summary
- `{{value_why}}` - Business value and reasoning
- `{{created_by}}` - User who created the request
- `{{created_date}}` - ISO date formatted nicely
- `{{description}}` - Full description (truncated to 500 chars)

### Pattern 3: Incident Notification

**Use Case**: Alert team about critical incidents

**Template**: `.claude/shared/teams/templates/incident_card.json`

```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "DC143C",
  "summary": "🚨 INCIDENT: {{title}}",
  "sections": [
    {
      "activityTitle": "🚨 Incident #{{work_item_id}}",
      "activitySubtitle": "{{title}}",
      "facts": [
        {"name": "Severity", "value": "{{severity_text}}"},
        {"name": "Impacted Services", "value": "{{impacted_services}}"},
        {"name": "Start Time", "value": "{{start_time}}"},
        {"name": "Duration", "value": "{{duration}} minutes"},
        {"name": "Identified By", "value": "{{identification_method}}"}
      ],
      "markdown": true,
      "text": "{{description}}"
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "View Incident in Azure DevOps",
      "targets": [
        {"os": "default", "uri": "https://dev.azure.com/{organization}/{project}/_workitems/edit/{{work_item_id}}"}
      ]
    }
  ]
}
```

**Variables**:
- `{{work_item_id}}` - Work item ID
- `{{title}}` - Incident title
- `{{severity_text}}` - "Critical", "High", "Medium", or "Low"
- `{{impacted_services}}` - Comma-separated list
- `{{start_time}}` - ISO datetime formatted
- `{{duration}}` - Duration in minutes
- `{{identification_method}}` - How incident was detected
- `{{description}}` - Incident description (truncated to 500 chars)

## Posting Messages

### Pattern: Post to Webhook

```bash
# Using curl
post_teams_message() {
    local webhook_url="$1"
    local message_json="$2"

    curl -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$message_json" \
        --max-time 30

    if [ $? -eq 0 ]; then
        echo "✅ Teams notification sent successfully"
    else
        echo "⚠️ Teams notification failed (non-blocking)"
    fi
}

# Usage
message=$(cat /path/to/template.json | sed "s/{{work_item_id}}/25123/g")
post_teams_message "$webhook_url" "$message"
```

### Template Variable Substitution

```bash
# Replace template variables
substitute_variables() {
    local template="$1"
    local work_item_id="$2"
    local title="$3"
    # ... other variables

    # Use sed for simple substitution
    result=$(echo "$template" | \
        sed "s/{{work_item_id}}/$work_item_id/g" | \
        sed "s/{{title}}/$title/g" | \
        sed "s/{{severity_text}}/$severity_text/g")

    echo "$result"
}
```

## Severity Mapping

| Severity Value | Text | Emoji |
|----------------|------|-------|
| 1 | Critical | 🔴 |
| 2 | High | 🟠 |
| 3 | Medium | 🟡 |
| 4 | Low | 🟢 |

## Error Handling

### Non-Blocking Approach

Teams notifications should **never block** the main operation:

```bash
# Post notification, but don't fail if it errors
post_teams_message "$webhook_url" "$message" || echo "⚠️ Teams notification failed (non-blocking)"

# Continue with rest of command regardless of Teams result
```

### Webhook Connection Failures

```markdown
## ⚠️ Teams Notification Failed (Non-Blocking)

**Warning**: Could not send Teams notification.

Possible reasons:
- Webhook URL is invalid or expired
- Network connectivity issues
- Teams service temporary unavailable
- Webhook rate limiting

**Note**: This does not affect the work item operation, which completed successfully.

To fix Teams notifications:
1. Verify webhook URL in .claude/shared/teams/webhook_config.json
2. Test webhook manually: curl -X POST "{webhook_url}" -H "Content-Type: application/json" -d '{"text":"Test"}'
3. Check Teams channel webhook settings
```

## Usage in Skills

Skills should reference Teams patterns when needed:

```markdown
# In SKILL.md or command

## Teams Integration (Optional)

This command can send Teams notifications after work item creation.

**Reference**: See `.claude/shared/teams/README.md` for:
- Message card templates
- Webhook configuration
- Variable substitution
- Error handling (non-blocking)

**Note**: Teams notifications are optional and non-blocking.
```

## Testing

When implementing Teams notifications:

1. **Test with real webhook**: Use actual Teams channel webhook
2. **Test variable substitution**: Verify all placeholders replaced
3. **Test error handling**: Disconnect network, verify non-blocking
4. **Test message formatting**: Check appearance in Teams
5. **Test character limits**: Verify truncation of long descriptions

## Character Limits

| Field | Limit | Behavior |
|-------|-------|----------|
| Title | 256 chars | Truncate with "..." |
| Description | 500 chars | Truncate with "... (view full in ADO)" |
| Fact Value | 100 chars | Truncate with "..." |
| Summary | 100 chars | Truncate with "..." |

## Common Patterns

### Pattern 1: Truncate Long Text

```bash
truncate_text() {
    local text="$1"
    local max_length="${2:-500}"

    if [ ${#text} -gt $max_length ]; then
        echo "${text:0:$max_length}..."
    else
        echo "$text"
    fi
}

# Usage
description=$(truncate_text "$long_description" 500)
```

### Pattern 2: Format Date for Display

```bash
format_date() {
    local iso_date="$1"

    # Convert ISO 8601 to friendly format
    date -d "$iso_date" "+%B %d, %Y at %I:%M %p" 2>/dev/null || echo "$iso_date"
}

# Usage
created_date=$(format_date "2025-12-19T10:30:00Z")
# Result: "December 19, 2025 at 10:30 AM"
```

### Pattern 3: Escape JSON Special Characters

```bash
escape_json() {
    local text="$1"

    # Escape quotes, backslashes, newlines
    echo "$text" | \
        sed 's/\\/\\\\/g' | \
        sed 's/"/\\"/g' | \
        sed 's/\n/\\n/g'
}

# Usage
safe_description=$(escape_json "$description")
```

## Notes

- Teams notifications are **always optional and non-blocking**
- Webhook URL should never be hardcoded in Skills
- Template files make it easy to update formatting
- Character limits prevent rendering issues in Teams
- ISO dates should be formatted for readability
- Special JSON characters must be escaped
- Consider rate limiting if posting many notifications
