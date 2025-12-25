# Power Automate Flow Setup for Teams Message ID Capture

This guide explains how to set up a Power Automate flow that posts messages to Teams and returns the message ID, enabling work items to link directly to their Teams discussion thread.

## Why Power Automate Instead of Webhooks?

| Feature | Incoming Webhook | Power Automate Flow |
|---------|------------------|---------------------|
| Returns message ID | ❌ No (returns `1`) | ✅ Yes |
| Authentication | Webhook URL only | Azure AD / M365 |
| Message formatting | MessageCard only | Adaptive Cards + rich text |
| Can reply to threads | ❌ No | ✅ Yes |
| Rate limiting | Basic | Better controls |

## Prerequisites

- Microsoft 365 account with Power Automate access
- Permissions to create flows in your tenant
- Access to the target Teams channel

---

## Step 1: Create the Flow

1. Go to [Power Automate](https://make.powerautomate.com/)
2. Click **+ Create** → **Instant cloud flow**
3. Name it: `Teams Post Message with ID Return`
4. Select trigger: **When an HTTP request is received**
5. Click **Create**

---

## Step 2: Configure the HTTP Trigger

In the HTTP trigger, click **Use sample payload to generate schema** and paste:

```json
{
  "title": "Bug Detected",
  "summary": "Feature flags don't display for sites",
  "themeColor": "FF6B6B",
  "cardType": "bug",
  "facts": [
    {"name": "Summary", "value": "Feature flags issue"},
    {"name": "Environment", "value": "Production"},
    {"name": "Severity", "value": "High"}
  ],
  "description": "On the sites table feature flags column just displays 'no features' for all sites.",
  "adoUrl": "https://dev.azure.com/{organization}/{project}/_workitems/edit/12345",
  "workItemId": "12345"
}
```

This generates the schema automatically. The trigger will now accept these fields.

**Copy the HTTP POST URL** - you'll need this later (it's generated after you save the flow).

---

## Step 3: Add "Post message in a chat or channel" Action

1. Click **+ New step**
2. Search for **Microsoft Teams**
3. Select **Post message in a chat or channel**

Configure the action:

| Field | Value |
|-------|-------|
| Post as | Flow bot |
| Post in | Channel |
| Team | *Select your team (e.g., {Product} Hub)* |
| Channel | *Select your channel (e.g., General or Bugs)* |
| Message | See Adaptive Card below |

### Message Content (Adaptive Card)

Click the `</>` code view toggle and paste:

```json
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.4",
  "body": [
    {
      "type": "TextBlock",
      "size": "Large",
      "weight": "Bolder",
      "text": "@{triggerBody()?['title']}",
      "wrap": true,
      "color": "@{if(equals(triggerBody()?['cardType'], 'bug'), 'Attention', if(equals(triggerBody()?['cardType'], 'feature'), 'Warning', 'Default'))}"
    },
    {
      "type": "TextBlock",
      "text": "@{triggerBody()?['summary']}",
      "wrap": true,
      "spacing": "Small"
    },
    {
      "type": "FactSet",
      "facts": "@{triggerBody()?['facts']}"
    },
    {
      "type": "TextBlock",
      "text": "@{triggerBody()?['description']}",
      "wrap": true,
      "spacing": "Medium",
      "isSubtle": true
    },
    {
      "type": "TextBlock",
      "text": "🧵 Reply to this thread for discussion",
      "wrap": true,
      "spacing": "Medium",
      "isSubtle": true
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "🔗 View in Azure DevOps",
      "url": "@{triggerBody()?['adoUrl']}"
    }
  ]
}
```

**Alternative: Simple Text Message**

If you prefer a simpler message without Adaptive Cards:

```
@{triggerBody()?['title']}

📌 @{triggerBody()?['summary']}
@{join(triggerBody()?['facts'], '
')}

@{triggerBody()?['description']}

🔗 Azure DevOps: @{triggerBody()?['adoUrl']}

🧵 Reply to this thread for updates.
```

---

## Step 4: Add Response Action

1. Click **+ New step**
2. Search for **Response** (under "Request")
3. Select **Response**

Configure:

| Field | Value |
|-------|-------|
| Status Code | `200` |
| Headers | `Content-Type`: `application/json` |
| Body | See below |

**Response Body:**

```json
{
  "success": true,
  "messageId": "@{outputs('Post_message_in_a_chat_or_channel')?['body/id']}",
  "messageLink": "@{outputs('Post_message_in_a_chat_or_channel')?['body/messageLink']}"
}
```

> **Note**: The action name `Post_message_in_a_chat_or_channel` may vary. Click in the Body field, then use **Dynamic content** to select the `Message ID` and `Message Link` from the Teams action output.

---

## Step 5: Save and Test

1. Click **Save**
2. Copy the **HTTP POST URL** from the trigger (click on the trigger to see it)
3. Test with curl:

```bash
curl -X POST "YOUR_FLOW_URL_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "🐞 Bug Detected",
    "summary": "Test bug from Power Automate setup",
    "themeColor": "FF6B6B",
    "cardType": "bug",
    "facts": [
      {"name": "📌 Summary", "value": "Test summary"},
      {"name": "📍 Environment", "value": "Test"},
      {"name": "⚠️ Severity", "value": "Low"}
    ],
    "description": "This is a test message to verify the flow works.",
    "adoUrl": "https://dev.azure.com/{organization}/{project}/_workitems/edit/1",
    "workItemId": "1"
  }'
```

**Expected Response:**

```json
{
  "success": true,
  "messageId": "1703123456789",
  "messageLink": "https://teams.microsoft.com/l/message/19%3A...%40thread.tacv2/1703123456789?..."
}
```

---

## Step 6: Configure the Plugin

Once your flow is working, add the flow URL to your configuration.

### Option A: Environment Variable (Recommended)

Set an environment variable:

```bash
export TEAMS_FLOW_URL="https://prod-XX.westus.logic.azure.com:443/workflows/..."
```

### Option B: Config File

Create or update `.claude/config.json` in your project:

```json
{
  "teams": {
    "flowUrl": "https://prod-XX.westus.logic.azure.com:443/workflows/...",
    "fallbackWebhookUrl": "https://{organization}ltd.webhook.office.com/..."
  }
}
```

The fallback webhook is used if the flow fails (non-blocking, but won't capture message ID).

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Power Automate Flow                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐                                   │
│  │  HTTP Request        │ ◄── Claude Code calls this URL    │
│  │  (Trigger)           │     with bug/feature details      │
│  └──────────┬───────────┘                                   │
│             │                                                │
│             ▼                                                │
│  ┌──────────────────────┐                                   │
│  │  Post message in     │                                   │
│  │  Teams channel       │ ──► Message appears in Teams      │
│  └──────────┬───────────┘                                   │
│             │                                                │
│             ▼                                                │
│  ┌──────────────────────┐                                   │
│  │  Response            │                                   │
│  │  {messageId, link}   │ ──► Returns to Claude Code        │
│  └──────────────────────┘                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Claude Code updates work     │
              │  item with TeamsChannelMessageId │
              └───────────────────────────────┘
```

---

## Error Handling

The flow should handle errors gracefully. Add a **Scope** around the Teams action with a **Configure run after** for failure:

### Add Error Handling

1. Add a **Scope** action, move the Teams post inside it
2. Add a parallel branch after the Scope
3. Configure it to run only on failure
4. Add a Response action returning error:

```json
{
  "success": false,
  "error": "Failed to post Teams message",
  "details": "@{result('Scope')?['error']}"
}
```

---

## Security Considerations

### Restrict Flow Access

The HTTP trigger URL is a secret - anyone with it can post to your Teams channel.

**Options to secure:**

1. **IP Restrictions** (Power Automate Premium)
   - Limit to known IP ranges

2. **API Key in Header**
   - Add a condition checking for a secret header:
   ```
   @equals(triggerOutputs()?['headers']?['X-API-Key'], 'your-secret-key')
   ```

3. **Azure AD Authentication** (Premium)
   - Require Azure AD token

For internal use, the URL obscurity is often sufficient, but rotate the URL periodically.

---

## Troubleshooting

### Flow Not Triggering

- Verify the URL is correct (regenerate if needed)
- Check Content-Type header is `application/json`
- Validate JSON payload format

### Teams Message Not Posting

- Verify the Flow bot has access to the channel
- Check Team/Channel selection in the action
- Review flow run history for errors

### Message ID Not Returned

- Ensure the Response action references the correct output
- Check the Teams action output in flow run details
- Verify the action name matches in the expression

### Response Timeout

Power Automate has a 30-second timeout for sync responses. If your flow is slow:

1. Use **async pattern**: Return 202 Accepted immediately, process async
2. Or simplify the flow (remove unnecessary actions)

---

## Maintenance

### Monitoring

- Check flow run history periodically
- Set up alerts for failed runs
- Monitor Teams channel for test messages

### Updating the Flow

1. Make changes in Power Automate
2. Test with curl before updating commands
3. The HTTP URL remains the same unless you delete/recreate the trigger

### URL Rotation

If you need to rotate the URL (security):

1. Delete the HTTP trigger
2. Add a new HTTP trigger
3. Update configuration with new URL

---

## Next Steps

After setting up the flow:

1. Update the commands (`create-techops-bug.md`, `create-feature-request.md`) to:
   - Call the flow URL instead of webhook
   - Parse the response to get `messageId`
   - Update the work item with `Custom.TeamsChannelMessageId`

2. Test end-to-end:
   - Create a bug via `/create-bug`
   - Verify Teams message appears
   - Verify work item has `TeamsChannelMessageId` populated
