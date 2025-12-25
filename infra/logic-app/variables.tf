variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create resources in"
  type        = string
  default     = "uk-shd-techops-teams-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "UK South"
}

variable "logic_app_name" {
  description = "Name of the Logic App"
  type        = string
  default     = "uk-shd-techops-teams-logic"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "TechOps Teams Notifications"
    Repository  = "techops-claudecode-pack"
  }
}

variable "create_resource_group" {
  description = "Whether to create the resource group or use existing"
  type        = bool
  default     = true
}
