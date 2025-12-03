variable "tfe_organization" {
  type = string
}

variable "assignment_per_user" {
  type = bool
}

variable "personal_team_prefix" {
  type = string
}

variable "shared_team_name" {
  type = string
}

variable "common_team_name" {
  type = string
}

variable "enable_common_access" {
  type = bool
}

variable "existing_team_id" {
  type    = string
  default = ""
}

variable "organization_access" {
  description = "Global organization wide access settings applied to all workshop teams"
  type = object({
    read_workspaces            = bool
    read_projects              = bool
    manage_workspaces          = bool
    manage_projects            = bool
    manage_agent_pools         = bool
    manage_run_tasks           = bool
    manage_policies            = bool
    manage_policy_overrides    = bool
    manage_vcs_settings        = bool
    manage_providers           = bool
    manage_modules             = bool
    manage_membership          = bool
    manage_teams               = bool
    manage_organization_access = bool
    access_secret_teams        = bool
  })
}

variable "usernames" {
  type = map(string)
}

variable "shared_team_mode" {
  type        = string
  description = "How to handle the shared team: create or existing"
}
