provider "tfe" {}

########################################
# Effective settings from profile + overrides
########################################

########################################
# Effective settings from profile plus overrides
########################################

locals {
  effective_assignment_mode = var.assignment_mode != ""
    ? var.assignment_mode
    : local.profile_settings.assignment_mode

  effective_shared_project_mode = var.shared_project_mode != ""
    ? var.shared_project_mode
    : local.profile_settings.shared_project_mode

  effective_shared_team_mode = var.shared_team_mode != ""
    ? var.shared_team_mode
    : local.profile_settings.shared_team_mode

  effective_using_locked = var.using_locked != local.profile_settings.using_locked
    ? var.using_locked
    : local.profile_settings.using_locked

  effective_enable_common_access = var.enable_common_access != local.profile_settings.enable_common_access
    ? var.enable_common_access
    : local.profile_settings.enable_common_access

  effective_email_source = var.email_source != ""
    ? var.email_source
    : local.profile_settings.email_source

  assignment_per_user = local.effective_assignment_mode == "per_user"
}

locals {
  # true  -> create per-user projects and teams
  # false -> use one shared project and shared team
  assignment_per_user = local.effective_assignment_mode == "per_user"
}

module "users" {
  source = "./modules/users"

  tfe_organization       = local.org_name

  email_source           = local.effective_email_source
  emails                 = var.emails

  using_locked           = local.effective_using_locked
  users                  = var.users

  bootstrap_file         = "${path.module}/bootstrap.json"
  write_credentials_file = var.write_credentials_file
}

module "teams" {
  source = "./modules/teams"

  tfe_organization     = local.org_name
  assignment_per_user  = local.assignment_per_user
  personal_team_prefix = var.personal_team_prefix
  shared_team_name     = var.shared_team_name
  common_team_name     = var.common_team_name

  shared_team_mode     = local.effective_shared_team_mode

  enable_common_access = local.effective_enable_common_access
  existing_team_id     = var.existing_team_id
  organization_access  = var.organization_access

  usernames            = module.users.usernames
}

module "projects" {
  source = "./modules/projects"

  tfe_organization    = local.org_name
  assignment_per_user = local.assignment_per_user
  shared_mode         = local.effective_shared_project_mode
  projects_prefix     = var.projects_prefix
  shared_project_name = var.shared_project_name
  usernames           = module.users.usernames
}

module "rbac" {
  source = "./modules/rbac"

  assignment_per_user  = local.assignment_per_user
  enable_common_access = local.effective_enable_common_access
  rbac_dry_run         = var.rbac_dry_run
  effective_emails = module.users.effective_emails
  membership_ids   = module.users.membership_ids
  usernames        = module.users.usernames
  personal_team_ids = module.teams.personal_team_ids
  shared_team_id    = module.teams.shared_team_id
  common_team_id    = module.teams.common_team_id
  user_project_ids  = module.projects.user_project_ids
  shared_project_id = module.projects.shared_project_id
}
