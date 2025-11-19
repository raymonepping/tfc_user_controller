########################################
# Derived data
########################################

output "usernames" {
  description = "Derived usernames per email"
  value       = local.usernames
}

output "project_names" {
  description = "Per-user projects created"
  value       = { for e, p in tfe_project.user_project : e => p.name }
}

output "contributors_team_id" {
  description = "Contributors/common team id (null if disabled)"
  value       = local.common_team_id
}

output "granted_access_level" {
  description = "Access level applied to all workshop projects"
  value       = "maintain"
}

########################################
# New — credentials output for TFC pull
########################################
# This mirrors the old credentials.auto.tfvars.json file,
# but works across Terraform Cloud runners.
########################################

output "credentials_json" {
  description = "Resolved workshop user metadata for locked mode (email → username, membership_id, user_id)"
  value = {
    users = local.users_to_persist
  }
}

########################################
# Optional — assignment mode visibility
########################################

output "assignment_mode_effective" {
  description = "Whether per-user mode or shared mode was used"
  value       = var.assignment_mode
}

########################################
# Optional — list of effective emails
########################################

output "effective_emails" {
  description = "Emails Terraform actually processed in this run"
  value       = local.effective_emails
}
