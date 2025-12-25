# Azure Logic App - Teams Notifier

Terraform configuration for a shared Azure Logic App that posts messages to Microsoft Teams and returns the message ID.

## Features

- HTTP trigger accepts `teamId` and `channelId` as parameters (supports multiple channels)
- Posts formatted HTML messages to Teams
- Returns `messageId` and `messageLink` for linking work items to discussions
- Managed Identity authentication
- Error handling with meaningful responses

## Prerequisites

- Azure subscription
- Terraform >= 1.5.0
- Azure CLI (`az login`) or Service Principal credentials
- Permissions to create Logic Apps and API Connections

## Authentication

Configure Azure authentication using one of these methods:

**Option 1: Azure CLI (Development)**
```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

**Option 2: Service Principal (CI/CD)**
```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
```

## Deployment

```bash
cd infra/logic-app

terraform init

terraform plan -out=tfplan

terraform apply tfplan
```

### Custom Variables

```bash
terraform apply \
  -var="resource_group_name=rg-my-custom-name" \
  -var="location=West Europe" \
  -var="logic_app_name=logic-my-teams-notifier"
```

### Use Existing Resource Group

```bash
terraform apply \
  -var="create_resource_group=false" \
  -var="resource_group_name=my-existing-rg"
```

## Post-Deployment: Authorize Teams Connection

After deploying, you must authorize the Teams API connection:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Resource Groups** → your resource group
3. Open the **API Connection** resource (e.g., `logic-techops-teams-notifier-teams-conn`)
4. Click **Edit API connection** in the left menu
5. Click **Authorize** and sign in with a Teams-enabled account
6. Click **Save**

## Get the Trigger URL

After deployment and authorization:

```bash
az logic workflow show \
  --resource-group rg-techops-shared \
  --name logic-techops-teams-notifier \
  --query "accessEndpoint" -o tsv
```

Or from Azure Portal:
1. Open the Logic App
2. Go to **Overview** → **Workflow URL** (or check the HTTP trigger)

The full trigger URL will look like:
```
https://prod-XX.uksouth.logic.azure.com:443/workflows/XXXX/triggers/http_request/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fhttp_request%2Frun&sv=1.0&sig=XXXX
```

## Usage

The Logic App supports two actions via a single endpoint:
- `post` (default) - Create a new message in a channel
- `reply` - Reply to an existing message thread

### Action: Post New Message

```bash
curl -X POST "YOUR_LOGIC_APP_TRIGGER_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "post",
    "teamId": "your-team-id-guid",
    "channelId": "19:xxx@thread.tacv2",
    "title": "Bug Detected",
    "summary": "Feature flags not displaying for sites",
    "themeColor": "FF6B6B",
    "cardType": "bug",
    "facts": [
      {"name": "Environment", "value": "Production"},
      {"name": "Severity", "value": "High"}
    ],
    "description": "Full description of the issue...",
    "adoUrl": "https://dev.azure.com/org/project/_workitems/edit/12345",
    "workItemId": "12345"
  }'
```

**Response (200):**
```json
{
  "success": true,
  "action": "post",
  "messageId": "1703123456789",
  "messageLink": "https://teams.microsoft.com/l/message/...",
  "teamId": "your-team-id-guid",
  "channelId": "19:xxx@thread.tacv2",
  "workItemId": "12345"
}
```

### Action: Reply to Thread

Use this to mirror ADO work item comments to the Teams thread:

```bash
curl -X POST "YOUR_LOGIC_APP_TRIGGER_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "reply",
    "teamId": "your-team-id-guid",
    "channelId": "19:xxx@thread.tacv2",
    "messageId": "1703123456789",
    "author": "Corbin Taylor",
    "content": "Bug picked up for investigation and fix via Claude Code /pickup-bug command",
    "adoUrl": "https://dev.azure.com/org/project/_workitems/edit/12345",
    "workItemId": "12345"
  }'
```

**Response (200):**
```json
{
  "success": true,
  "action": "reply",
  "replyId": "1703123456790",
  "messageId": "1703123456789",
  "teamId": "your-team-id-guid",
  "channelId": "19:xxx@thread.tacv2",
  "workItemId": "12345"
}
```

### Common Use Cases for Reply

| Event | Example Content |
|-------|-----------------|
| Bug picked up | "Bug picked up by {user} for investigation via Claude Code /pickup-bug command" |
| Status change | "Status changed from New to Active by {user}" |
| Comment added | "{comment text}" |
| Assignment | "Assigned to {user}" |
| Bug resolved | "Bug resolved by {user}. Fix: {fix description}" |
| PR linked | "Pull request created: {pr_title} - {pr_url}" |

### Error Response (500)

```json
{
  "success": false,
  "action": "post|reply",
  "error": "Failed to post/reply to Teams message",
  "details": { ... }
}
```

## Finding Team ID and Channel ID

### Via Microsoft Teams

1. Open Teams in browser or desktop app
2. Right-click on the channel → **Get link to channel**
3. The URL contains both IDs:
   ```
   https://teams.microsoft.com/l/channel/19%3Axxx%40thread.tacv2/General?groupId=TEAM-ID-HERE&tenantId=...
   ```
   - `groupId` = Team ID
   - The encoded part before `General` = Channel ID (URL decode `%3A` → `:`, `%40` → `@`)

### Via Microsoft Graph Explorer

1. Go to [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. Sign in with your Microsoft account
3. Query: `GET https://graph.microsoft.com/v1.0/me/joinedTeams`
4. For channels: `GET https://graph.microsoft.com/v1.0/teams/{team-id}/channels`

## Configuration for Consuming Repos

Set these environment variables in consuming repos:

```bash
export TEAMS_FLOW_URL="https://prod-XX.uksouth.logic.azure.com:443/workflows/..."
export TEAMS_TEAM_ID="your-team-id-guid"
export TEAMS_CHANNEL_ID="19:xxx@thread.tacv2"
```

Or add to `.claude/settings.json`:

```json
{
  "env": {
    "TEAMS_FLOW_URL": "https://prod-XX.uksouth.logic.azure.com:443/workflows/...",
    "TEAMS_TEAM_ID": "your-team-id-guid",
    "TEAMS_CHANNEL_ID": "19:xxx@thread.tacv2"
  }
}
```

## Inputs

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Resource group name | `rg-techops-shared` |
| `location` | Azure region | `UK South` |
| `logic_app_name` | Logic App name | `logic-techops-teams-notifier` |
| `create_resource_group` | Create RG or use existing | `true` |
| `tags` | Resource tags | See variables.tf |

## Outputs

| Output | Description |
|--------|-------------|
| `logic_app_id` | Logic App resource ID |
| `logic_app_name` | Logic App name |
| `logic_app_access_endpoint` | Base access endpoint URL |
| `logic_app_identity_principal_id` | Managed Identity principal ID |
| `resource_group_name` | Resource group name |
| `teams_connection_id` | Teams API connection ID |

## Troubleshooting

### "Authorization failed" when posting

The Teams API connection needs to be authorized:
1. Go to Azure Portal → API Connections → Edit → Authorize

### "Channel not found" error

Verify the Team ID and Channel ID are correct. Use Graph Explorer to validate.

### Logic App not triggering

1. Check the Logic App is enabled (Overview → Status)
2. Verify the trigger URL is correct
3. Check Run History for errors

### Message not appearing in Teams

1. Check the Logic App Run History for the specific run
2. Look at the "Post_message_to_Teams" action output
3. Verify the authorized user has permission to post to the channel

## Security Notes

- The Logic App trigger URL contains a SAS signature - treat it as a secret
- The Teams connection uses delegated permissions from the authorizing user
- Consider using Managed Identity with Graph API for service-to-service auth in production

## Clean Up

```bash
terraform destroy
```
