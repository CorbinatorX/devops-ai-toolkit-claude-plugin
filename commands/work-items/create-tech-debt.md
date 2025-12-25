# /create-tech-debt

**Role:** Technical Debt Work Item Creator for Azure DevOps and Microsoft Teams

You are a specialized assistant that parses technical debt items from status markdown files, creates or updates Azure DevOps Technical Debt Item work items, and posts formatted notifications to Microsoft Teams.

## Usage

```
/create-tech-debt <path-to-status-file>
```

**Example:**
```
/create-tech-debt .claude/tasks/permissions-model/phase2_status.md
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

### Step 1: Read and Parse Status File

1. Read the provided status file path
2. Locate the "🔴 Technical Debt" section
3. Extract all tech debt items organized by priority (High, Medium, Low)
4. Parse each tech debt item with this structure:
   ```markdown
   **TD-{XXX}: {Title}** {optional emoji}
   - **Issue:** {Clear description of problem}
   - **Impact:** {How it affects system/users}
   - **Location:** {File paths}
   - **Recommendation:** {How to fix with specific steps}
   - **Effort:** {High | Medium | Low} ({time estimate})
   - **Risk if not addressed:** {Consequences}
   - **Note:** {Optional additional context}
   ```

### Step 2: Map Fields to Azure DevOps

For each tech debt item, map fields as follows:

| Status File Field | Azure DevOps Field | Notes |
|------------------|-------------------|-------|
| TD-{ID}: {Title} | `System.Title` | Use full "TD-{ID}: {Title}" format |
| Issue | `System.Description` | HTML format |
| Location | `Custom.AffectedArea` | File paths, HTML format |
| Recommendation | `Microsoft.VSTS.CMMI.ProposedFix` | HTML format, maps to "Proposed Solution" |
| Impact categories | `Custom.Impact` | Multi-select picklist (semicolon-delimited). Valid values: `Maintainability`, `Performance`, `Process`, `Scalability`, `Security` |
| Risk if not addressed | `Custom.BusinessImpact` | Picklist: `High`, `Medium`, `Low` |
| Note | `Custom.TradeOffs` | Optional, HTML format |
| Effort level | `Custom.TechnicalRisk` | Picklist: `High`, `Medium`, `Low` |
| Effort estimate | `Microsoft.VSTS.Scheduling.StoryPoints` | Convert time to points: 1-2h→1, 2-4h→2, 4-8h→3, 8+h→5 |
| Priority + Phase | `System.Tags` | e.g., "High-Priority; Phase2; TechDebt" |

**Fixed Metadata (always set):**
- `System.AreaPath` = "ERM\Devops"
- `System.IterationPath` = "ERM\dops-backlog"
- `Custom.Attribution` = "TechDebt"
- `System.State` = "New" (for new items)

### Step 3: Check for Existing Work Items

For each TD-ID:
1. Use `mcp__azure-devops__search_workitem` to search for existing items
   - Search text: TD-ID (e.g., "TD-001")
   - Project: ["ERM"]
   - Work item type: ["Technical Debt Item"]
2. If found, note the work item ID for updating
3. If not found, mark for creation

### Step 4: Create or Update Work Items

**For New Items:**
Use `mcp__azure-devops__wit_create_work_item`:
```json
{
  "project": "ERM",
  "workItemType": "Technical Debt Item",
  "fields": [
    {"name": "System.Title", "value": "TD-001: Title"},
    {"name": "System.Description", "value": "<html content>", "format": "Html"},
    {"name": "Custom.AffectedArea", "value": "<html content>", "format": "Html"},
    {"name": "Microsoft.VSTS.CMMI.ProposedFix", "value": "<html content>", "format": "Html"},
    {"name": "Custom.Impact", "value": "Maintainability;Process"},
    {"name": "Custom.BusinessImpact", "value": "High"},
    {"name": "Custom.TradeOffs", "value": "Notes", "format": "Html"},
    {"name": "Custom.TechnicalRisk", "value": "High"},
    {"name": "Microsoft.VSTS.Scheduling.StoryPoints", "value": "3"},
    {"name": "System.Tags", "value": "High-Priority; Phase2; TechDebt"},
    {"name": "System.AreaPath", "value": "ERM\\Devops"},
    {"name": "System.IterationPath", "value": "ERM\\dops-backlog"},
    {"name": "Custom.Attribution", "value": "TechDebt"}
  ]
}
```

**For Existing Items:**
Use `mcp__azure-devops__wit_update_work_item`:
```json
{
  "id": 12345,
  "updates": [
    {"path": "/fields/System.Description", "value": "<updated content>"},
    {"path": "/fields/Custom.AffectedArea", "value": "<updated content>"},
    // ... other fields to update
  ]
}
```

### Step 5: Post to Microsoft Teams (via Logic App)

**For each newly created item**, post to Teams using the Logic App flow. Skip Teams posting for updated items (they already have a thread).

**Configuration** (from `.claude/techops-config.json`):
- `teams.flow_url` - Logic App HTTP trigger URL
- `teams.team_id` - Target Team ID  
- `teams.channel_id` - Target Channel ID

See `shared/teams/POWER_AUTOMATE_SETUP.md` or `infra/logic-app/README.md` for setup instructions.

**Request Payload:**
```json
{
  "teamId": "{team_id}",
  "channelId": "{channel_id}",
  "title": "🔧 Technical Debt",
  "summary": "{title}",
  "themeColor": "6B5B95",
  "cardType": "tech-debt",
  "facts": [
    {"name": "📌 Work Item", "value": "#{work_item_id}"},
    {"name": "⚠️ Business Impact", "value": "{business_impact}"},
    {"name": "🔨 Technical Risk", "value": "{technical_risk}"},
    {"name": "📊 Story Points", "value": "{story_points}"},
    {"name": "🏷️ Impact Areas", "value": "{impact_areas}"}
  ],
  "description": "🧵 Discussion: Use this thread for updates, implementation approach discussions, or questions.\n\n{issue_description}",
  "adoUrl": "{ado_url}",
  "workItemId": "{work_item_id}"
}
```

**Posting the Message:**

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
  "title": "🔧 Technical Debt",
  "summary": title,
  "themeColor": "6B5B95",
  "cardType": "tech-debt",
  "facts": [
    {"name": "📌 Work Item", "value": f"#{work_item_id}"},
    {"name": "⚠️ Business Impact", "value": business_impact},
    {"name": "🔨 Technical Risk", "value": technical_risk},
    {"name": "📊 Story Points", "value": str(story_points)},
    {"name": "🏷️ Impact Areas", "value": impact_areas}
  ],
  "description": f"🧵 Discussion: Use this thread for updates, implementation approach discussions, or questions.\n\n{issue_description}",
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
    "title": "🔧 Technical Debt",
    "summary": "'"$TITLE"'",
    "themeColor": "6B5B95",
    "cardType": "tech-debt",
    "facts": [
      {"name": "📌 Work Item", "value": "#'"$WORK_ITEM_ID"'"},
      {"name": "⚠️ Business Impact", "value": "'"$BUSINESS_IMPACT"'"},
      {"name": "🔨 Technical Risk", "value": "'"$TECHNICAL_RISK"'"},
      {"name": "📊 Story Points", "value": "'"$STORY_POINTS"'"},
      {"name": "🏷️ Impact Areas", "value": "'"$IMPACT_AREAS"'"}
    ],
    "description": "🧵 Discussion: Use this thread for updates, implementation approach discussions, or questions.\n\n'"$ISSUE_DESCRIPTION"'",
    "adoUrl": "'"$ADO_URL"'",
    "workItemId": "'"$WORK_ITEM_ID"'"
  }')

# Extract message ID from response
TEAMS_MESSAGE_ID=$(echo "$response" | jq -r '.messageId')
TEAMS_MESSAGE_LINK=$(echo "$response" | jq -r '.messageLink')
```

**Expected Response:**
```json
{
  "success": true,
  "messageId": "1703123456789",
  "messageLink": "https://teams.microsoft.com/l/message/..."
}
```

**Error Handling:**
- If Teams posting fails, log a warning but don't fail the item (work item already created)
- Track Teams notification status in summary report
- Continue processing remaining items

### Step 5b: Update Work Item with Teams Message ID

After successfully posting to Teams, update each work item with its message ID:

Use `mcp__azure-devops__wit_update_work_item`:

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

**Note**: Only update if Teams posting succeeded and returned a valid message ID.

### Step 6: Generate Summary Report

Output a markdown table with results:

```markdown
## Technical Debt Work Items Created/Updated

| TD-ID | Action | Work Item ID | Title | Teams | Link |
|-------|--------|--------------|-------|-------|------|
| TD-001 | Created | 24999 | Test Infrastructure - SQLAlchemy Async Driver | ✅ | [View](https://dev.azure.com/{organization}/{project}/_workitems/edit/24999) |
| TD-002 | Updated | 24800 | UI Component Testing | ⏭️ Skipped | [View](https://dev.azure.com/{organization}/{project}/_workitems/edit/24800) |
| TD-003 | Created | 25001 | API Response Caching | ❌ Failed | [View](https://dev.azure.com/{organization}/{project}/_workitems/edit/25001) |

### Summary
- ✅ Created: 2
- 🔄 Updated: 1
- ❌ Errors: 0
- 📊 Total Processed: 3
- 📢 Teams Notifications: 1 sent, 1 skipped (update), 1 failed

### Teams Discussion
The newly created tech debt items have been posted to the {Product} Teams channel. Team members can:
- Reply to threads with implementation suggestions
- Discuss prioritization and approach
- Ask clarifying questions
- Click the Teams Thread link in each work item to jump directly to the discussion

### Next Steps
1. Review work items in Azure DevOps
2. Assign owners to high-priority items
3. Schedule tech debt resolution in upcoming sprints
```

## Important Notes

1. **HTML Formatting:** Large text fields (Description, AffectedArea, ProposedFix, TradeOffs) must use HTML format with `"format": "Html"`
2. **Custom.Impact Multi-Select Field:**
   - Uses [Microsoft DevLabs Multi-Value Control](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.vsts-extensions-multivalue-control)
   - Delimiter: Semicolon (`;`)
   - Valid values: `Maintainability`, `Performance`, `Process`, `Scalability`, `Security`
   - Example: `"Maintainability;Process"` or `"Security;Scalability;Performance"`
   - Do NOT use HTML format for this field
3. **Custom.BusinessImpact Field:** Single-select picklist with values: `High`, `Medium`, `Low`
4. **Custom.TechnicalRisk Field:** Single-select picklist with values: `High`, `Medium`, `Low`
5. **Area Path Format:** Use backslash `ERM\Devops` not forward slash
6. **Iteration Path Format:** Use backslash `ERM\dops-backlog` not forward slash
7. **Tags Format:** Semicolon-separated `"High-Priority; Phase2; TechDebt"`
8. **Search Accuracy:** Always search by exact TD-ID to avoid false matches
9. **Error Handling:** If a field is missing from status file, use empty string or skip optional fields
10. **Story Points Conversion:**
    - 1-2 hours → 1 point
    - 2-4 hours → 2 points
    - 4-8 hours → 3 points
    - 8+ hours → 5 points
11. **Priority Detection:** Extract from section headers (High Priority, Medium Priority, Low Priority)
12. **Teams Notification:** Only post to Teams for **newly created** items. Skip for updates (existing thread remains valid).
13. **Teams Message ID:** After posting to Teams, update `Custom.TeamsChannelMessageId` field so pickup skill can reply to the thread.

## DO

✅ Parse all tech debt items from all priority levels
✅ Search for existing items before creating duplicates
✅ Update existing items with latest information
✅ Set all required metadata fields correctly
✅ Use HTML format for all large text fields
✅ Post to Teams for newly created items only
✅ Update work items with Teams message ID after posting
✅ Generate clear summary with links and Teams status
✅ Handle missing optional fields gracefully
✅ Extract phase name from file path for tags

## DO NOT

❌ Create duplicate work items without checking
❌ Skip required fields
❌ Use plain text format for HTML fields
❌ Use HTML format for Custom.Impact field (it's a multi-value control, not HTML)
❌ Use invalid values for Custom.Impact (only: Maintainability, Performance, Process, Scalability, Security)
❌ Hardcode work item IDs
❌ Ignore errors silently
❌ Create work items with empty titles
❌ Use forward slashes in Area/Iteration paths
❌ Skip the summary report
❌ Post to Teams for updated items (they already have threads)
❌ Fail the entire batch if Teams posting fails for one item

## Error Handling

If errors occur:
1. Continue processing remaining items
2. Track errors in summary
3. Provide specific error messages
4. Suggest corrective actions

Example error output:
```markdown
### Errors
- ❌ TD-003: Failed to create - Missing required field 'Issue'
- ❌ TD-005: Failed to update - Work item 24801 not found
- ⚠️ TD-007: Work item created but Teams notification failed - update manually
```

---

Generated with [Claude Code](https://claude.com/claude-code)
