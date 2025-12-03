locals {
  shared_using_existing = var.shared_mode == "existing"
}

########################################
# Per user projects
########################################

resource "tfe_project" "user_project" {
  for_each     = var.assignment_per_user ? var.usernames : {}
  organization = var.tfe_organization
  name         = "${var.projects_prefix}_${each.value}"
}

########################################
# Shared project (create mode)
########################################

resource "tfe_project" "shared" {
  count        = var.assignment_per_user || local.shared_using_existing ? 0 : 1
  organization = var.tfe_organization
  name         = var.shared_project_name
}

########################################
# Shared project (existing mode)
########################################

data "tfe_project" "shared" {
  count        = var.assignment_per_user || !local.shared_using_existing ? 0 : 1
  name         = var.shared_project_name
  organization = var.tfe_organization
}

locals {
  user_project_ids = {
    for email, username in var.usernames :
    email => try(tfe_project.user_project[email].id, null)
  }

  user_project_names = {
    for email, username in var.usernames :
    email => try(tfe_project.user_project[email].name, null)
  }

  shared_project_id = var.assignment_per_user ? null : (
    local.shared_using_existing
    ? data.tfe_project.shared[0].id
    : tfe_project.shared[0].id
  )
}
