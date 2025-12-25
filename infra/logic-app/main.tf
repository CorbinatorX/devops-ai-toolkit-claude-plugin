resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  location            = var.create_resource_group ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location
}

data "azurerm_managed_api" "teams" {
  name     = "teams"
  location = local.location
}

resource "azurerm_api_connection" "teams" {
  name                = "${var.logic_app_name}-apic"
  resource_group_name = local.resource_group_name
  managed_api_id      = data.azurerm_managed_api.teams.id
  display_name        = "Teams API Connection"
  tags                = var.tags

  lifecycle {
    ignore_changes = [parameter_values]
  }
}

resource "azurerm_logic_app_workflow" "teams_notifier" {
  name                = var.logic_app_name
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  workflow_parameters = {
    "$connections" = jsonencode({
      type         = "Object"
      defaultValue = {}
    })
  }

  parameters = {
    "$connections" = jsonencode({
      teams = {
        connectionId   = azurerm_api_connection.teams.id
        connectionName = azurerm_api_connection.teams.name
        id             = data.azurerm_managed_api.teams.id
      }
    })
  }
}

resource "azurerm_resource_group_template_deployment" "logic_app_definition" {
  name                = "${var.logic_app_name}-workflow"
  resource_group_name = local.resource_group_name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema"        = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    "contentVersion" = "1.0.0.0"
    "resources" = [{
      "type"       = "Microsoft.Logic/workflows"
      "apiVersion" = "2019-05-01"
      "name"       = azurerm_logic_app_workflow.teams_notifier.name
      "location"   = local.location
      "tags"       = var.tags
      "identity" = {
        "type" = "SystemAssigned"
      }
      "properties" = {
        "state" = "Enabled"
        "definition" = {
          "$schema"        = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
          "contentVersion" = "1.0.0.0"

          "parameters" = {
            "$connections" = {
              "defaultValue" = {}
              "type"         = "Object"
            }
          }

          "triggers" = {
            "http_request" = {
              "type" = "Request"
              "kind" = "Http"
              "inputs" = {
                "schema" = {
                  "type" = "object"
                  "properties" = {
                    "action" = {
                      "type"        = "string"
                      "description" = "Action type: 'post' for new message, 'reply' for thread reply"
                      "enum"        = ["post", "reply"]
                    }
                    "teamId" = {
                      "type"        = "string"
                      "description" = "Microsoft Teams Team ID"
                    }
                    "channelId" = {
                      "type"        = "string"
                      "description" = "Microsoft Teams Channel ID"
                    }
                    "messageId" = {
                      "type"        = "string"
                      "description" = "Teams message ID to reply to (required for action=reply)"
                    }
                    "title" = {
                      "type"        = "string"
                      "description" = "Card title (e.g., Bug Detected, Feature Request)"
                    }
                    "summary" = {
                      "type"        = "string"
                      "description" = "Brief summary"
                    }
                    "themeColor" = {
                      "type"        = "string"
                      "description" = "Card theme color hex (e.g., FF6B6B for bugs)"
                    }
                    "cardType" = {
                      "type"        = "string"
                      "description" = "Type of card: bug, feature, incident"
                    }
                    "facts" = {
                      "type"        = "array"
                      "description" = "Array of fact objects with name and value"
                      "items" = {
                        "type" = "object"
                        "properties" = {
                          "name"  = { "type" = "string" }
                          "value" = { "type" = "string" }
                        }
                      }
                    }
                    "description" = {
                      "type"        = "string"
                      "description" = "Full description text"
                    }
                    "content" = {
                      "type"        = "string"
                      "description" = "Plain text or HTML content for reply (used when action=reply)"
                    }
                    "author" = {
                      "type"        = "string"
                      "description" = "Author name for the comment/reply"
                    }
                    "adoUrl" = {
                      "type"        = "string"
                      "description" = "Azure DevOps work item URL"
                    }
                    "workItemId" = {
                      "type"        = "string"
                      "description" = "Azure DevOps work item ID"
                    }
                  }
                  "required" = ["teamId", "channelId"]
                }
              }
            }
          }

          "actions" = {
            "Check_Action_Type" = {
              "type"     = "If"
              "runAfter" = {}
              "expression" = {
                "and" = [{
                  "equals" = ["@coalesce(triggerBody()?['action'], 'post')", "reply"]
                }]
              }
              "actions" = {
                "Reply_to_Teams_Message" = {
                  "type" = "ApiConnection"
                  "inputs" = {
                    "host" = {
                      "connection" = {
                        "name" = "@parameters('$connections')['teams']['connectionId']"
                      }
                    }
                    "method" = "post"
                    "path"   = "/beta/teams/@{encodeURIComponent(triggerBody()?['teamId'])}/channels/@{encodeURIComponent(triggerBody()?['channelId'])}/messages/@{encodeURIComponent(triggerBody()?['messageId'])}/replies"
                    "body" = {
                      "body" = {
                        "contentType" = "html"
                        "content"     = "<p><strong>@{coalesce(triggerBody()?['author'], 'Azure DevOps')}</strong></p><p>@{triggerBody()?['content']}</p>@{if(not(empty(triggerBody()?['adoUrl'])), concat('<p><a href=\"', triggerBody()?['adoUrl'], '\">View in Azure DevOps</a></p>'), '')}"
                      }
                    }
                  }
                }
                "Reply_Success_Response" = {
                  "type" = "Response"
                  "kind" = "Http"
                  "runAfter" = {
                    "Reply_to_Teams_Message" = ["Succeeded"]
                  }
                  "inputs" = {
                    "statusCode" = 200
                    "headers" = {
                      "Content-Type" = "application/json"
                    }
                    "body" = {
                      "success"    = true
                      "action"     = "reply"
                      "replyId"    = "@{body('Reply_to_Teams_Message')?['id']}"
                      "messageId"  = "@{triggerBody()?['messageId']}"
                      "teamId"     = "@{triggerBody()?['teamId']}"
                      "channelId"  = "@{triggerBody()?['channelId']}"
                      "workItemId" = "@{triggerBody()?['workItemId']}"
                    }
                  }
                }
                "Reply_Error_Response" = {
                  "type" = "Response"
                  "kind" = "Http"
                  "runAfter" = {
                    "Reply_to_Teams_Message" = ["Failed", "TimedOut"]
                  }
                  "inputs" = {
                    "statusCode" = 500
                    "headers" = {
                      "Content-Type" = "application/json"
                    }
                    "body" = {
                      "success" = false
                      "action"  = "reply"
                      "error"   = "Failed to reply to Teams message"
                      "details" = "@{body('Reply_to_Teams_Message')}"
                    }
                  }
                }
              }
              "else" = {
                "actions" = {
                  "Transform_Facts_to_Card" = {
                    "type" = "Select"
                    "inputs" = {
                      "from" = "@coalesce(triggerBody()?['facts'], json('[]'))"
                      "select" = {
                        "title" = "@{item()?['name']}"
                        "value" = "@{item()?['value']}"
                      }
                    }
                  }
                  "Build_Adaptive_Card" = {
                    "type" = "Compose"
                    "runAfter" = {
                      "Transform_Facts_to_Card" = ["Succeeded"]
                    }
                    "inputs" = {
                      "type"    = "AdaptiveCard"
                      "version" = "1.4"
                      "$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
                      "msteams" = {
                        "width" = "Full"
                      }
                      "body" = [
                        {
                          "type"   = "TextBlock"
                          "text"   = "@{if(equals(triggerBody()?['cardType'], 'bug'), '🐞 Bug Detected', if(equals(triggerBody()?['cardType'], 'feature'), '💡 Feature Request', if(equals(triggerBody()?['cardType'], 'incident'), '🚨 Incident Detected', if(equals(triggerBody()?['cardType'], 'tech-debt'), '🔧 Technical Debt', coalesce(triggerBody()?['title'], 'Notification')))))}"
                          "size"   = "Medium"
                          "weight" = "Bolder"
                          "wrap"   = true
                        },
                        {
                          "type"   = "TextBlock"
                          "text"   = "@{triggerBody()?['summary']}"
                          "size"   = "Large"
                          "weight" = "Bolder"
                          "wrap"   = true
                        },
                        {
                          "type"    = "TextBlock"
                          "text"    = "🧵 **Discussion:** Use this thread for updates or to attach screenshots/logs."
                          "wrap"    = true
                          "spacing" = "Medium"
                        },
                        {
                          "type"    = "TextBlock"
                          "text"    = "@{triggerBody()?['description']}"
                          "wrap"    = true
                          "spacing" = "Medium"
                        },
                        {
                          "type"      = "FactSet"
                          "facts"     = "@body('Transform_Facts_to_Card')"
                          "separator" = true
                        }
                      ]
                      "actions" = [
                        {
                          "type"  = "Action.OpenUrl"
                          "title" = "🔗 View in Azure DevOps"
                          "url"   = "@{triggerBody()?['adoUrl']}"
                        }
                      ]
                    }
                  }
                  "Post_message_to_Teams" = {
                    "type" = "ApiConnection"
                    "runAfter" = {
                      "Build_Adaptive_Card" = ["Succeeded"]
                    }
                    "inputs" = {
                      "host" = {
                        "connection" = {
                          "name" = "@parameters('$connections')['teams']['connectionId']"
                        }
                      }
                      "method" = "post"
                      "path"   = "/beta/teams/@{encodeURIComponent(triggerBody()?['teamId'])}/channels/@{encodeURIComponent(triggerBody()?['channelId'])}/messages"
                      "body" = {
                        "body" = {
                          "contentType" = "html"
                          "content"     = "<attachment id=\"adaptiveCard\"></attachment>"
                        }
                        "attachments" = [
                          {
                            "id"          = "adaptiveCard"
                            "contentType" = "application/vnd.microsoft.card.adaptive"
                            "contentUrl"  = null
                            "content"     = "@{string(outputs('Build_Adaptive_Card'))}"
                          }
                        ]
                      }
                    }
                  }
                  "Post_Success_Response" = {
                    "type" = "Response"
                    "kind" = "Http"
                    "runAfter" = {
                      "Post_message_to_Teams" = ["Succeeded"]
                    }
                    "inputs" = {
                      "statusCode" = 200
                      "headers" = {
                        "Content-Type" = "application/json"
                      }
                      "body" = {
                        "success"     = true
                        "action"      = "post"
                        "messageId"   = "@{body('Post_message_to_Teams')?['id']}"
                        "messageLink" = "@{body('Post_message_to_Teams')?['webUrl']}"
                        "teamId"      = "@{triggerBody()?['teamId']}"
                        "channelId"   = "@{triggerBody()?['channelId']}"
                        "workItemId"  = "@{triggerBody()?['workItemId']}"
                      }
                    }
                  }
                  "Post_Error_Response" = {
                    "type" = "Response"
                    "kind" = "Http"
                    "runAfter" = {
                      "Post_message_to_Teams" = ["Failed", "TimedOut"]
                    }
                    "inputs" = {
                      "statusCode" = 500
                      "headers" = {
                        "Content-Type" = "application/json"
                      }
                      "body" = {
                        "success" = false
                        "action"  = "post"
                        "error"   = "Failed to post message to Teams"
                        "details" = "@{body('Post_message_to_Teams')}"
                      }
                    }
                  }
                }
              }
            }
          }

          "outputs" = {}
        }

        "parameters" = {
          "$connections" = {
            "value" = {
              "teams" = {
                "connectionId"   = azurerm_api_connection.teams.id
                "connectionName" = azurerm_api_connection.teams.name
                "id"             = data.azurerm_managed_api.teams.id
              }
            }
          }
        }
      }
    }]
  })

  depends_on = [
    azurerm_logic_app_workflow.teams_notifier,
    azurerm_api_connection.teams
  ]
}
