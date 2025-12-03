########################################
# Core org and workspace context
########################################

variable "tfe_organization" {
  type    = string
  default = "HUGGING_NL"
}

# Optional: in case you ever want to reuse this controller from other orgs
# you can override via a Terraform Cloud variable or tfvars.

data "tfe_organization" "this" {
  name = var.tfe_organization
}

# Current workspace (where this code runs). Useful if you ever want to
# auto-attach RBAC back to this workspace or introspect it.
data "tfe_workspace" "controller" {
  name         = "tfc_user_controller"
  organization = data.tfe_organization.this.name
}

locals {
  org_name = data.tfe_organization.this.name
  org_id   = data.tfe_organization.this.id

  controller_workspace_name = data.tfe_workspace.controller.name
  controller_workspace_id   = data.tfe_workspace.controller.id
}
