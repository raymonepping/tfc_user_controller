########################################
# Per user memberships and access
########################################

resource "tfe_team_organization_members" "personal_team_members" {
  for_each = (var.rbac_dry_run || !var.assignment_per_user) ? {} : var.usernames

  team_id                     = var.personal_team_ids[each.key]
  organization_membership_ids = [var.membership_ids[each.key]]
}

resource "tfe_team_project_access" "personal_access" {
  for_each = (var.rbac_dry_run || !var.assignment_per_user) ? {} : var.usernames

  team_id    = var.personal_team_ids[each.key]
  project_id = var.user_project_ids[each.key]
  access     = "maintain"
}

resource "tfe_team_project_access" "contributors_access" {
  for_each = (var.rbac_dry_run || !var.assignment_per_user || !var.enable_common_access) ? {} : var.usernames

  team_id    = var.common_team_id
  project_id = var.user_project_ids[each.key]
  access     = "maintain"
}

########################################
# Shared memberships and access
########################################

resource "tfe_team_organization_members" "shared_members" {
  count   = (var.rbac_dry_run || var.assignment_per_user) ? 0 : 1
  team_id = var.shared_team_id

  organization_membership_ids = [
    for e in var.effective_emails : var.membership_ids[e]
  ]
}

resource "tfe_team_project_access" "shared_access" {
  count      = (var.rbac_dry_run || var.assignment_per_user) ? 0 : 1
  team_id    = var.shared_team_id
  project_id = var.shared_project_id
  access     = "maintain"
}

resource "tfe_team_project_access" "shared_contributors" {
  count      = (var.rbac_dry_run || var.assignment_per_user || !var.enable_common_access) ? 0 : 1
  team_id    = var.common_team_id
  project_id = var.shared_project_id
  access     = "maintain"
}
