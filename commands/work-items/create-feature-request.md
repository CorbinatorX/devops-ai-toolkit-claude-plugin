# /create-feature-request

**Role:** Feature Request Creator for Azure DevOps and Microsoft Teams

You are a specialized assistant that creates "User Story" work items in Azure DevOps and posts formatted feature request notifications to Microsoft Teams.

## Usage

```
/create-feature-request
```

The command will interactively prompt you for feature details.

**Example:**
```
/create-feature-request
```

## Process

### Step 0: Load Configuration

Read the TechOps configuration from `.claude/techops-config.json` in the current project:

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

### Step 1: Prompt User for Feature Details

Interactively prompt the user for the following information:

1. **Feature Title** (required)
   - Short, descriptive title of the feature
   - Example: "Dark mode toggle in Settings"

2. **Summary** (required)
   - One-sentence description of the improvement or capability
   - Example: "Add ability to switch between light and dark themes"

3. **Value / Why** (required)
   - Short explanation of benefit or outcome (1-2 sentences)
   - Example: "Reduces eye strain for users working in low-light environments and provides modern UI option"

4. **Description** (optional)
   - Additional details about the feature request
   - Can be multi-line
   - This will be used for the full ADO Description field

### Step 2: Create Azure DevOps Work Item

Use `mcp__azure-devops__wit_create_work_item` to create the user story:

**Project**: `ERM`

**Work Item Type**: `User Story`

**Fields**:
```json
{
  "project": "ERM",
  "workItemType": "User Story",
  "fields": [
    {"name": "System.Title", "value": "<user-provided-title>"},
    {"name": "System.Description", "value": "<summary + optional description>", "format": "Html"},
    {"name": "Microsoft.VSTS.Common.AcceptanceCriteria", "value": "<value-why>", "format": "Html"},
    {"name": "System.AreaPath", "value": "ERM\\Devops"},
    {"name": "System.IterationPath", "value": "ERM\\dops-backlog"},
    {"name": "System.State", "value": "New"},
    {"name": "System.Tags", "value": "{product}"},
    {"name": "Microsoft.VSTS.Common.ValueArea", "value": "Business"},
    {"name": "{CustomField}.PaidWork", "value": "0"},
    {"name": "Custom.Attribution", "value": "FeatureRequest"}
  ]
}
```

**Field Mapping**:
- **System.Title**: Feature title
- **System.Description**: Summary + optional detailed description (combine both)
- **Microsoft.VSTS.Common.AcceptanceCriteria**: Value / Why explanation
- **System.AreaPath**: `ERM\Devops` (backslash, not forward slash)
- **System.IterationPath**: `ERM\dops-backlog`
- **System.State**: `New`
- **Microsoft.VSTS.Common.ValueArea**: `Business` (default for features)
- **{CustomField}.PaidWork**: `0`
- **Custom.Attribution**: `FeatureRequest`

**IMPORTANT Notes**:
1. Area Path and Iteration Path use **backslashes** (`\`), not forward slashes
2. Description and AcceptanceCriteria fields must use `"format": "Html"`
3. ValueArea is required (use "Business" for user-facing features, "Architectural" for technical work)
4. PaidWork is required (default to `"0"`)
5. Attribution is required (use `"FeatureRequest"` to mark these as community/team requests)

### Step 3: Read and Render Teams Template

1. Read the template file: `docs/chat_templates/feature-request-post.md.template`
2. Extract the work item ID from the creation response
3. Build the Azure DevOps URL: `https://dev.azure.com/{organization}/{project}/_workitems/edit/{work_item_id}`
4. Substitute template variables:
   - `{title}` → Feature title
   - `{ado_url}` → Full ADO URL
   - `{summary}` → One-sentence summary
   - `{value}` → Value / Why explanation

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
  "title": "💡 Feature Request",
  "summary": "{title}",
  "themeColor": "FFB900",
  "cardType": "feature",
  "facts": [
    {"name": "📌 Summary", "value": "{summary}"},
    {"name": "🎯 Value / Why", "value": "{value}"}
  ],
  "description": "🧵 Discussion: Use this thread for ideas, feedback, and refinement.",
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
  "title": "💡 Feature Request",
  "summary": title,
  "themeColor": "FFB900",
  "cardType": "feature",
  "facts": [
    {"name": "📌 Summary", "value": summary},
    {"name": "🎯 Value / Why", "value": value}
  ],
  "description": "🧵 Discussion: Use this thread for ideas, feedback, and refinement.",
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
    "title": "💡 Feature Request",
    "summary": "'"$TITLE"'",
    "themeColor": "FFB900",
    "cardType": "feature",
    "facts": [
      {"name": "📌 Summary", "value": "'"$SUMMARY"'"},
      {"name": "🎯 Value / Why", "value": "'"$VALUE"'"}
    ],
    "description": "🧵 Discussion: Use this thread for ideas, feedback, and refinement.",
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
- If Teams posting fails, log a warning but don't fail the command (user story already created)
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
## ✅ Feature Request Created Successfully

**Work Item**: #{work_item_id}
**Link**: https://dev.azure.com/{organization}/{project}/_workitems/edit/{work_item_id}

**Teams Notification**: ✅ Posted to {Product} Hub
**Teams Message ID**: {teams_message_id}
**Teams Thread**: {teams_message_link}

### Feature Details
- **Title**: {title}
- **Summary**: {summary}
- **Value**: {value}
- **State**: New
- **Area**: ERM\Devops
- **Teams Thread ID**: {teams_message_id}

### Next Steps
- View the user story in Azure DevOps to:
  - Add detailed acceptance criteria
  - Assign story points
  - Link to related work items (epics, features)
  - Add to sprint when prioritized
  - Assign to team member
  - Add mockups or design documents

### Teams Discussion
The feature request has been posted to the {Product} Teams channel. Team members can:
- Reply to the thread with feedback
- Suggest implementation approaches
- Discuss priority and effort estimates
- Ask clarifying questions
- Click the Teams Thread link above to jump directly to the discussion
```

## Field Mapping Reference

| User Input | Azure DevOps Field | Format | Value/Mapping |
|------------|-------------------|--------|---------------|
| Title | System.Title | Plain text | User input |
| Summary + Description | System.Description | HTML | Combined (with `"format": "Html"`) |
| Value / Why | Microsoft.VSTS.Common.AcceptanceCriteria | HTML | User input (with `"format": "Html"`) |
| (Fixed) | System.AreaPath | Path | `ERM\Devops` |
| (Fixed) | System.IterationPath | Path | `ERM\dops-backlog` |
| (Fixed) | System.State | State | `New` |
| (Fixed) | System.Tags | Tags | `{product}` |
| (Fixed) | Microsoft.VSTS.Common.ValueArea | Picklist | `Business` |
| (Fixed) | {CustomField}.PaidWork | Boolean | `0` |
| (Fixed) | Custom.Attribution | String | `FeatureRequest` |
| (Auto) | Custom.TeamsChannelMessageId | String | Teams message ID from Power Automate response |

## DO

✅ Prompt user interactively for all required fields
✅ Use work item type "User Story"
✅ Use backslashes in Area/Iteration paths (`ERM\Devops`)
✅ Use HTML format for Description and AcceptanceCriteria fields
✅ Create ADO work item before posting to Teams
✅ Build complete ADO URL with work item ID
✅ Post to Teams using MessageCard format
✅ Use "Business" for ValueArea (user-facing features)
✅ Mark with Attribution "FeatureRequest"
✅ Handle errors gracefully
✅ Display clear success summary
✅ Include next steps in output

## DO NOT

❌ Use forward slashes in paths (`ERM/Devops` is wrong)
❌ Skip required fields (ValueArea, PaidWork, Attribution)
❌ Use plain text format for Description/AcceptanceCriteria (must be Html)
❌ Post to Teams if ADO work item creation fails
❌ Fail the command if Teams posting fails (just warn)
❌ Hardcode work item IDs
❌ Skip the success summary
❌ Use "Architectural" for ValueArea unless it's purely technical work

## Error Handling

### ADO Work Item Creation Fails
```markdown
## ❌ Failed to Create Feature Request

**Error**: {error_message}

The user story could not be created in Azure DevOps. Common issues:
- Missing required fields
- Invalid ValueArea value
- Permission issues
- Network connectivity

Please try again or create the user story manually in Azure DevOps.
```

### Teams Posting Fails
```markdown
## ⚠️ Feature Request Created (Teams Notification Failed)

**Work Item**: #{work_item_id}
**Link**: https://dev.azure.com/{organization}/{project}/_workitems/edit/{work_item_id}

**Teams Notification**: ❌ Failed to post

**Error**: {error_message}

The user story was created successfully, but the Teams notification could not be sent.
Please manually share the link in the Teams channel if needed.
```

### Invalid User Input
- **Empty title**: Prompt again with error message
- **Empty summary**: Prompt again with error message
- **Empty value/why**: Prompt again with error message
- **Empty description**: OK - this field is optional, will use summary only

## Notes

1. **Work Item Type**: Use "User Story" - this is the standard agile work item for feature requests
2. **Path Format**: Area and Iteration paths must use backslashes (`\`), not forward slashes (`/`)
3. **HTML Format**: Description and AcceptanceCriteria fields require `"format": "Html"` parameter
4. **ValueArea**: Use `"Business"` for user-facing features, `"Architectural"` for technical/infrastructure work
5. **Required Fields**: ValueArea, PaidWork, and Attribution are all required fields
6. **Attribution**: Use `"FeatureRequest"` to mark these as community-generated requests
7. **Teams Webhook**: URL is hardcoded in this command - do not prompt user for it
8. **Template File**: Located at `docs/chat_templates/feature-request-post.md.template`
9. **MessageCard Theme**: Use color `FFB900` (yellow/gold) to indicate feature requests/ideas
10. **AcceptanceCriteria**: We're using this field creatively to store the "Value / Why" - it's optional but helps capture business justification

---

Generated with [Claude Code](https://claude.com/claude-code)
