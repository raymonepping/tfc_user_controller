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

locals {
  org_name = data.tfe_organization.this.name
}
