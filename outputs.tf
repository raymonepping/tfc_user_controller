########################################
# Derived data
########################################

output "usernames" {
  description = "Derived usernames per email"
  value       = module.users.usernames
}

output "project_names" {
  description = "Per user projects created"
  value       = module.projects.user_project_names
}

output "contributors_team_id" {
  description = "Contributors or common team id (null if disabled)"
  value       = module.teams.common_team_id
}

output "granted_access_level" {
  description = "Access level applied to all workshop projects"
  value       = "maintain"
}

output "credentials_json" {
  description = "Resolved workshop user metadata (email → username, membership_id, user_id)"
  value = {
    users = module.users.users_to_persist
  }
}

########################################
# Optional – assignment mode visibility
########################################

output "assignment_mode_effective" {
  description = "Whether per user mode or shared mode was used"
  value       = var.assignment_mode
}

########################################
# Optional – list of effective emails
########################################

output "effective_emails" {
  description = "Emails Terraform actually processed in this run"
  value       = module.users.effective_emails
}

output "topology" {
  description = "Full mapping of emails, memberships, teams, and projects"
  value = {
    assignment_mode = local.effective_assignment_mode
    email_source    = local.effective_email_source
    rbac_dry_run    = var.rbac_dry_run
    shared = {
      project_id  = module.projects.shared_project_id
      team_id     = module.teams.shared_team_id
      common_team = module.teams.common_team_id
    }
    users = {
      for email in module.users.effective_emails : email => {
        username      = module.users.usernames[email]
        membership_id = module.users.membership_ids[email]
        user_id       = module.users.user_ids[email]
        personal_team = module.teams.personal_team_ids[email]
        personal_proj = module.projects.user_project_ids[email]
      }
    }
  }
}
