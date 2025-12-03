########################################
# Common team (by name or ID override)
########################################

data "tfe_team" "common" {
  count        = var.enable_common_access && var.existing_team_id == "" ? 1 : 0
  name         = var.common_team_name
  organization = var.tfe_organization
}

locals {
  common_team_id = var.enable_common_access ? (
    var.existing_team_id != "" ? var.existing_team_id : data.tfe_team.common[0].id
  ) : null
}

########################################
# Per user teams
########################################

resource "tfe_team" "personal" {
  for_each     = var.assignment_per_user ? var.usernames : {}
  organization = var.tfe_organization
  name         = "${var.personal_team_prefix}_${each.value}"

  organization_access {
    read_workspaces            = var.organization_access.read_workspaces
    read_projects              = var.organization_access.read_projects
    manage_workspaces          = var.organization_access.manage_workspaces
    manage_projects            = var.organization_access.manage_projects
    manage_agent_pools         = var.organization_access.manage_agent_pools
    manage_run_tasks           = var.organization_access.manage_run_tasks
    manage_policies            = var.organization_access.manage_policies
    manage_policy_overrides    = var.organization_access.manage_policy_overrides
    manage_vcs_settings        = var.organization_access.manage_vcs_settings
    manage_providers           = var.organization_access.manage_providers
    manage_modules             = var.organization_access.manage_modules
    manage_membership          = var.organization_access.manage_membership
    manage_teams               = var.organization_access.manage_teams
    manage_organization_access = var.organization_access.manage_organization_access
    access_secret_teams        = var.organization_access.access_secret_teams
  }
}

########################################
# Shared team
########################################

locals {
  shared_using_existing = var.shared_team_mode == "existing"
}

resource "tfe_team" "shared" {
  count        = var.assignment_per_user || local.shared_using_existing ? 0 : 1
  organization = var.tfe_organization
  name         = var.shared_team_name

  organization_access {
    read_workspaces            = var.organization_access.read_workspaces
    read_projects              = var.organization_access.read_projects
    manage_workspaces          = var.organization_access.manage_workspaces
    manage_projects            = var.organization_access.manage_projects
    manage_agent_pools         = var.organization_access.manage_agent_pools
    manage_run_tasks           = var.organization_access.manage_run_tasks
    manage_policies            = var.organization_access.manage_policies
    manage_policy_overrides    = var.organization_access.manage_policy_overrides
    manage_vcs_settings        = var.organization_access.manage_vcs_settings
    manage_providers           = var.organization_access.manage_providers
    manage_modules             = var.organization_access.manage_modules
    manage_membership          = var.organization_access.manage_membership
    manage_teams               = var.organization_access.manage_teams
    manage_organization_access = var.organization_access.manage_organization_access
    access_secret_teams        = var.organization_access.access_secret_teams
  }
}

########################################
# Shared team (existing mode)
########################################

data "tfe_team" "shared" {
  count        = var.assignment_per_user || !local.shared_using_existing ? 0 : 1
  name         = var.shared_team_name
  organization = var.tfe_organization
}

locals {
  personal_team_ids = {
    for email, username in var.usernames :
    email => try(tfe_team.personal[email].id, null)
  }

  shared_team_id = var.assignment_per_user ? null : tfe_team.shared[0].id
}
