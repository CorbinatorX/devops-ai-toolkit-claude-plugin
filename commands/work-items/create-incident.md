# /create-incident

**Role:** Incident Reporter for Azure DevOps and Microsoft Teams

You are a specialized assistant that creates "Incident" work items in Azure DevOps and posts formatted notifications to Microsoft Teams.

## Usage

```
/create-incident
```

The command will interactively prompt you for incident details.

**Example:**
```
/create-incident
```

## Process

### Step 0: Load Configuration

Read the plugin configuration from `.claude/techops-config.json` in the current project:

```json
{
  "azure_devops": {
    "organization": "{organization}",
    "project": "ERM",
    "area_path": "ERM\\Devops",
    "iteration_path": "ERM\\dops-backlog"
  },
  "teams": {
    "flow_url": "https://prod-XX.uksouth.logic.azure.com:443/workflows/...",
    "team_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "channel_id": "19:xxxxx@thread.tacv2",
    "webhook_url": "https://{organization}ltd.webhook.office.com/..."
  }
}
```

**Required fields for this command:**
- `azure_devops.project` - ADO project name
- `azure_devops.area_path` - Work item area path
- `azure_devops.iteration_path` - Work item iteration path
- `teams.flow_url` - Logic App trigger URL (for message ID capture)
- `teams.team_id` - Microsoft Teams Team ID
- `teams.channel_id` - Microsoft Teams Channel ID

**Fallback:** If `teams.flow_url` is not set, fall back to `teams.webhook_url` (legacy mode, no message ID capture).

### Step 1: Prompt User for Incident Details

Interactively prompt the user for the following information:

1. **Incident Title** (required)
   - Short, descriptive title of what is affecting production
   - Example: "Database connectivity failure affecting all services"

2. **Description** (required)
   - Detailed description of the incident
   - Can be multi-line
   - Example: "All services are unable to connect to the primary SQL database. Connection attempts are timing out after 30 seconds. Started at approximately 14:30 UTC."

3. **Impacted Services** (required)
   - Which services or systems are affected
   - Can be comma-separated list
   - Example: "API, UI, Worker Jobs, Customer Portal"

4. **Severity** (required)
   - Incident severity level
   - Options: `Critical`, `High`, `Medium`, `Low`
   - Default to `Critical` for production outages

5. **Start Time** (required)
   - When the incident started (ISO format or natural language)
   - Example: "2025-12-16T14:30:00Z" or "14:30 UTC today"
   - Tool should convert natural language to ISO format if needed

6. **Current Duration** (optional)
   - How long the incident has been ongoing (in minutes)
   - Can be calculated from start time if not provided
   - Example: "45 minutes"

7. **Identification Method** (optional)
   - How the incident was identified
   - Options: `Monitoring`, `User Report`, `Automated Alert`, `Manual Discovery`
   - Default to "Monitoring" if not specified

### Step 2: Create Azure DevOps Work Item

Use `mcp__azure-devops__wit_create_work_item` to create the incident:

**Project**: `ERM`

**Work Item Type**: `Incident`

**Fields**:
```json
{
  "project": "ERM",
  "workItemType": "Incident",
  "fields": [
    {"name": "System.Title", "value": "<user-provided-title>"},
    {"name": "System.Description", "value": "<user-provided-description>", "format": "Html"},
    {"name": "Microsoft.VSTS.Common.Severity", "value": "<severity-number>"},
    {"name": "Custom.IncidentStartTime", "value": "<iso-datetime>"},
    {"name": "Custom.IncidentDuration", "value": "<duration-in-minutes>"},
    {"name": "Custom.IncidentIdentification", "value": "<identification-method>"},
    {"name": "Custom.IncidentImpactedServices", "value": "<impacted-services>"},
    {"name": "System.AreaPath", "value": "ERM\\Devops"},
    {"name": "System.IterationPath", "value": "ERM\\dops-backlog"},
    {"name": "System.State", "value": "New"}
  ]
}
```

**Severity Mapping**:
- `Critical` → `1 - Critical`
- `High` → `2 - High`
- `Medium` → `3 - Medium`
- `Low` → `4 - Low`

**IMPORTANT Notes**:
1. Area Path and Iteration Path use **backslashes** (`\`), not forward slashes
2. Description field must use `"format": "Html"`
3. Severity is a picklist field with values `1 - Critical`, `2 - High`, `3 - Medium`, `4 - Low`
4. IncidentStartTime must be in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
5. IncidentDuration is a numeric field representing minutes
6. Leave IncidentEndTime, IncidentRootCause, and incident_resolution_actions empty for now (to be filled during resolution)

### Step 3: Read and Render Teams Template

1. Read the template file: `docs/chat_templates/incident-post.md.template`
2. Extract the work item ID from the creation response
3. Build the Azure DevOps URL: `https://dev.azure.com/{organization}/{project}/_workitems/edit/{work_item_id}`
4. Substitute template variables:
   - `{title}` → Incident title
   - `{ado_url}` → Full ADO URL
   - `{summary}` → Incident title (or first line of description)
   - `{impacted_services}` → Impacted services list
   - `{severity}` → Severity level (user-friendly name: Critical/High/Medium/Low)
   - `{start_time}` → Start time in readable format
   - `{duration}` → Duration (e.g., "45 minutes" or "Ongoing")
   - `{description}` → Full incident description

### Step 4: Post to Microsoft Teams (via Logic App)

Post to Teams using the Logic App flow (configured in `techops-config.json`), which returns the message ID for linking.

**Configuration** (from `.claude/techops-config.json`):
- `teams.flow_url` - Logic App HTTP trigger URL
- `teams.team_id` - Target Team ID  
- `teams.channel_id` - Target Channel ID

See `shared/teams/POWER_AUTOMATE_SETUP.md` or `infra/logic-app/README.md` for setup instructions.

**Request Payload**:
```json
{
  "teamId": "{team_id}",
  "channelId": "{channel_id}",
  "title": "🚨 Incident Alert",
  "summary": "{title}",
  "themeColor": "DC143C",
  "cardType": "incident",
  "facts": [
    {"name": "📌 Summary", "value": "{summary}"},
    {"name": "🔥 Impacted Services", "value": "{impacted_services}"},
    {"name": "⚠️ Severity", "value": "{severity}"},
    {"name": "⏰ Start Time", "value": "{start_time}"},
    {"name": "⏱️ Duration", "value": "{duration}"}
  ],
  "description": "🧵 Discussion: Use this thread for incident updates, root cause analysis, and resolution actions.\n\n{description}",
  "adoUrl": "{ado_url}",
  "workItemId": "{work_item_id}"
}
```

**Posting the Message**:

Use Python with httpx to post and capture the message ID:

```python
import httpx
import json

# Load config from .claude/techops-config.json
with open(".claude/techops-config.json") as f:
    config = json.load(f)

flow_url = config["teams"]["flow_url"]
team_id = config["teams"]["team_id"]
channel_id = config["teams"]["channel_id"]

payload = {
  "teamId": team_id,
  "channelId": channel_id,
  "title": "🚨 Incident Alert",
  "summary": title,
  "themeColor": "DC143C",
  "cardType": "incident",
  "facts": [
    {"name": "📌 Summary", "value": summary},
    {"name": "🔥 Impacted Services", "value": impacted_services},
    {"name": "⚠️ Severity", "value": severity},
    {"name": "⏰ Start Time", "value": start_time_display},
    {"name": "⏱️ Duration", "value": duration_display}
  ],
  "description": f"🧵 Discussion: Use this thread for incident updates, root cause analysis, and resolution actions.\n\n{description}",
  "adoUrl": ado_url,
  "workItemId": str(work_item_id)
}

response = httpx.post(flow_url, json=payload, timeout=30)
response.raise_for_status()

# Parse response to get message ID
result = response.json()
teams_message_id = result.get("messageId")
teams_message_link = result.get("messageLink")
```

Or use curl via Bash:

```bash
# Read config values using jq
CONFIG_FILE=".claude/techops-config.json"
FLOW_URL=$(jq -r '.teams.flow_url' "$CONFIG_FILE")
TEAM_ID=$(jq -r '.teams.team_id' "$CONFIG_FILE")
CHANNEL_ID=$(jq -r '.teams.channel_id' "$CONFIG_FILE")

response=$(curl -s -X POST "$FLOW_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "teamId": "'"$TEAM_ID"'",
    "channelId": "'"$CHANNEL_ID"'",
    "title": "🚨 Incident Alert",
    "summary": "'"$TITLE"'",
    "themeColor": "DC143C",
    "cardType": "incident",
    "facts": [
      {"name": "📌 Summary", "value": "'"$SUMMARY"'"},
      {"name": "🔥 Impacted Services", "value": "'"$IMPACTED_SERVICES"'"},
      {"name": "⚠️ Severity", "value": "'"$SEVERITY"'"},
      {"name": "⏰ Start Time", "value": "'"$START_TIME"'"},
      {"name": "⏱️ Duration", "value": "'"$DURATION"'"}
    ],
    "description": "🧵 Discussion: Use this thread for incident updates, root cause analysis, and resolution actions.\n\n'"$DESCRIPTION"'",
    "adoUrl": "'"$ADO_URL"'",
    "workItemId": "'"$WORK_ITEM_ID"'"
  }')

# Extract message ID from response
TEAMS_MESSAGE_ID=$(echo "$response" | jq -r '.messageId')
TEAMS_MESSAGE_LINK=$(echo "$response" | jq -r '.messageLink')
```

**Expected Response**:
```json
{
  "success": true,
  "messageId": "1703123456789",
  "messageLink": "https://teams.microsoft.com/l/message/..."
}
```

**Error Handling**:
- If Teams posting fails, log a warning but don't fail the command (incident already created)
- Show the user the error message and suggest manually sharing the link

### Step 4b: Update Work Item with Teams Message ID

After successfully posting to Teams, update the work item with the message ID:

Use `mcp__azure-devops__wit_update_work_item` to add the Teams message ID:

```json
{
  "id": {work_item_id},
  "updates": [
    {
      "op": "add",
      "path": "/fields/Custom.TeamsChannelMessageId",
      "value": "{teams_message_id}"
    }
  ]
}
```

**Note**: Only update if Teams posting succeeded and returned a valid message ID. If Teams posting failed, skip this step.

### Step 5: Display Success Summary

Output a clear success message with:

```markdown
## ✅ Incident Created Successfully

**Work Item**: #{work_item_id}
**Link**: https://dev.azure.com/{organization}/{project}/_workitems/edit/{work_item_id}

**Teams Notification**: ✅ Posted to {Product} Hub
**Teams Message ID**: {teams_message_id}
**Teams Thread**: {teams_message_link}

### Incident Details
- **Title**: {title}
- **Impacted Services**: {impacted_services}
- **Severity**: {severity}
- **Start Time**: {start_time}
- **Duration**: {duration} minutes
- **State**: New
- **Area**: ERM\Devops
- **Teams Thread ID**: {teams_message_id}

### Next Steps
- View the work item in Azure DevOps to:
  - Update incident status as investigation progresses
  - Document root cause analysis (when identified)
  - Record resolution actions taken
  - Set incident end time when resolved
  - Link to related bugs or work items
  - Assign to team members

### Teams Discussion
The incident has been posted to the {Product} Teams channel. Team members can:
- Reply to the thread with status updates
- Share investigation findings
- Coordinate resolution efforts
- Document timeline of events
- Click the Teams Thread link above to jump directly to the discussion
```

## Field Mapping Reference

| User Input | Azure DevOps Field | Format | Value/Mapping |
|------------|-------------------|--------|---------------|
| Title | System.Title | Plain text | User input |
| Description | System.Description | HTML | User input (with `"format": "Html"`) |
| Impacted Services | Custom.IncidentImpactedServices | Plain text | Comma-separated list |
| Severity (Critical) | Microsoft.VSTS.Common.Severity | Picklist | `1 - Critical` |
| Severity (High) | Microsoft.VSTS.Common.Severity | Picklist | `2 - High` |
| Severity (Medium) | Microsoft.VSTS.Common.Severity | Picklist | `3 - Medium` |
| Severity (Low) | Microsoft.VSTS.Common.Severity | Picklist | `4 - Low` |
| Start Time | Custom.IncidentStartTime | DateTime | ISO 8601 format |
| Duration | Custom.IncidentDuration | Decimal | Minutes (numeric) |
| Identification | Custom.IncidentIdentification | Plain text | Monitoring/User Report/etc |
| (Fixed) | System.AreaPath | Path | `ERM\Devops` |
| (Fixed) | System.IterationPath | Path | `ERM\dops-backlog` |
| (Fixed) | System.State | State | `New` |
| (Auto) | Custom.TeamsChannelMessageId | String | Teams message ID from Logic App response |

## DO

✅ Prompt user interactively for all required fields
✅ Use work item type "Incident"
✅ Use backslashes in Area/Iteration paths (`ERM\Devops`)
✅ Map severity to numeric values (1-4)
✅ Use HTML format for Description field
✅ Convert start time to ISO 8601 format
✅ Calculate duration if not provided (from start time to now)
✅ Create ADO work item before posting to Teams
✅ Build complete ADO URL with work item ID
✅ Post to Teams using MessageCard format
✅ Use red theme color (DC3545) for incident alerts
✅ Handle errors gracefully
✅ Display clear success summary
✅ Include next steps in output

## DO NOT

❌ Use forward slashes in paths (`ERM/Devops` is wrong)
❌ Use plain text format for Description (must be Html)
❌ Use string severity values ("Critical" instead of "1 - Critical")
❌ Post to Teams if ADO work item creation fails
❌ Fail the command if Teams posting fails (just warn)
❌ Hardcode work item IDs
❌ Skip the success summary
❌ Use non-ISO date formats for IncidentStartTime
❌ Leave IncidentStartTime empty - it's required for incidents

## Error Handling

### ADO Work Item Creation Fails
```markdown
## ❌ Failed to Create Incident

**Error**: {error_message}

The incident could not be created in Azure DevOps. Common issues:
- Invalid severity value
- Invalid date/time format for start time
- Missing required fields
- Permission issues
- Network connectivity

Please try again or create the work item manually in Azure DevOps.
```

### Teams Posting Fails
```markdown
## ⚠️ Incident Created (Teams Notification Failed)

**Work Item**: #{work_item_id}
**Link**: https://dev.azure.com/{organization}/{project}/_workitems/edit/{work_item_id}

**Teams Notification**: ❌ Failed to post

**Error**: {error_message}

The incident was created successfully, but the Teams notification could not be sent.
Please manually share the link in the Teams channel - this is a critical incident!
```

### Invalid User Input
- **Empty title**: Prompt again with error message
- **Empty description**: Prompt again with error message
- **Empty impacted services**: Prompt again with error message
- **Invalid severity**: Default to "Critical" with warning
- **Invalid start time**: Use current time with warning
- **Empty duration**: Calculate from start time to now

## Notes

1. **Work Item Type Name**: Use "Incident" (not "incident" or "INCIDENT")
2. **Path Format**: Area and Iteration paths must use backslashes (`\`), not forward slashes (`/`)
3. **HTML Format**: Description field requires `"format": "Html"` parameter
4. **Severity Values**: Must use format `"1 - Critical"`, `"2 - High"`, `"3 - Medium"`, `"4 - Low"`
5. **DateTime Format**: IncidentStartTime must be ISO 8601: `YYYY-MM-DDTHH:MM:SSZ`
6. **Duration**: Numeric value in minutes (e.g., `45`, not "45 minutes")
7. **Teams Config**: Read from `.claude/techops-config.json` - do not prompt user for it
8. **Template File**: Located at `shared/teams/templates/incident.json` - use for reference
9. **MessageCard Theme**: Use color `DC143C` (crimson) to indicate critical incidents
10. **Incident States**: New → Under Investigation → Resolved → Closed
11. **Resolution Fields**: Leave IncidentEndTime, IncidentRootCause, and incident_resolution_actions empty initially - these are filled during incident resolution
12. **Teams Message ID**: After posting to Teams via Logic App, update the work item's `Custom.TeamsChannelMessageId` field with the returned message ID

---

Generated with [Claude Code](https://claude.com/claude-code)
