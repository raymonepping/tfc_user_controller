########################################
# Per user memberships and access
########################################

resource "tfe_team_organization_members" "personal_team_members" {
  # Only in per user mode
  for_each = var.assignment_per_user ? var.usernames : {}

  team_id                     = var.personal_team_ids[each.key]
  organization_membership_ids = [var.membership_ids[each.key]]
}

resource "tfe_team_project_access" "personal_access" {
  # Only in per user mode
  for_each = var.assignment_per_user ? var.usernames : {}

  team_id    = var.personal_team_ids[each.key]
  project_id = var.user_project_ids[each.key]
  access     = "maintain"
}

resource "tfe_team_project_access" "contributors_access" {
  # Per user mode + common access enabled
  for_each = (var.assignment_per_user && var.enable_common_access) ? var.usernames : {}

  team_id    = var.common_team_id
  project_id = var.user_project_ids[each.key]
  access     = "maintain"
}

########################################
# Shared memberships and access
########################################

resource "tfe_team_organization_members" "shared_members" {
  # Only in shared mode
  count   = var.assignment_per_user ? 0 : 1
  team_id = var.shared_team_id

  organization_membership_ids = [
    for e in var.effective_emails : var.membership_ids[e]
  ]
}

resource "tfe_team_project_access" "shared_access" {
  # Only in shared mode
  count      = var.assignment_per_user ? 0 : 1
  team_id    = var.shared_team_id
  project_id = var.shared_project_id
  access     = "maintain"
}

resource "tfe_team_project_access" "shared_contributors" {
  # Shared mode + common access enabled
  count      = (var.assignment_per_user || !var.enable_common_access) ? 0 : 1
  team_id    = var.common_team_id
  project_id = var.shared_project_id
  access     = "maintain"
}
