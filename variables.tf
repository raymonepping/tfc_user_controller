variable "assignment_mode" {
  description = "Per user: personal team+project per user. Shared: one team+project for all."
  type        = string
  default     = ""
  validation {
    condition     = var.assignment_mode == "" || contains(["per_user", "shared"], var.assignment_mode)
    error_message = "assignment_mode must be empty or one of \"per_user\" or \"shared\"."
  }
}

variable "shared_project_name" {
  type        = string
  default     = "project_chicago"
  description = "Only used when assignment_mode = shared"
}

variable "shared_team_name" {
  type        = string
  default     = "team_bulls"
  description = "Only used when assignment_mode = shared"
}

variable "common_team_name" {
  type    = string
  default = "Contributors"
}

variable "existing_team_id" {
  description = "Optional: If set, we skip lookup by name and use this team ID directly."
  type        = string
  default     = ""
}

variable "projects_prefix" {
  type    = string
  default = "project"
}

variable "personal_team_prefix" {
  type    = string
  default = "team"
}

variable "enable_common_access" {
  description = "Grant the common team access to each per user project."
  type        = bool
  default     = true
}

variable "write_credentials_file" {
  description = "When bootstrapping, write credentials.auto.tfvars.json with resolved IDs."
  type        = bool
  default     = true
}

# Locked/steady-state input. Key = email (lowercase), value contains IDs & username.
# When this map is non-empty, memberships are NOT created; values are reused.
variable "users" {
  type = map(object({
    username      = string
    membership_id = string
    user_id       = optional(string) # can be empty/omitted
  }))
  default = {}
}

variable "using_locked" {
  type        = bool
  description = "Whether to use locked tfvars with user IDs"
  default     = false
}

variable "organization_access" {
  description = "Global organization-wide access settings applied to all workshop teams"
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

variable "shared_project_mode" {
  type        = string
  description = "How to handle the shared project: create or existing"
  default     = ""
  validation {
    condition     = var.shared_project_mode == "" || contains(["create", "existing"], var.shared_project_mode)
    error_message = "shared_project_mode must be empty, \"create\" or \"existing\"."
  }
}

# Backwards compatible alias for older tfvars using shared_mode
variable "shared_mode" {
  type        = string
  description = "Legacy alias for shared_project_mode"
  default     = ""

  validation {
    condition     = var.shared_mode == "" || contains(["create", "existing"], var.shared_mode)
    error_message = "shared_mode must be empty or one of \"create\", \"existing\"."
  }
}



variable "shared_team_mode" {
  type        = string
  description = "How to handle the shared team: create or existing"
  default     = ""
  validation {
    condition     = var.shared_team_mode == "" || contains(["create", "existing"], var.shared_team_mode)
    error_message = "shared_team_mode must be empty, \"create\" or \"existing\"."
  }
}

variable "email_source" {
  type        = string
  description = "Where to load emails from: bootstrap.json, variable list, or locked users"
  default     = ""
  validation {
    condition     = var.email_source == "" || contains(["bootstrap", "variable", "locked"], var.email_source)
    error_message = "email_source must be empty, \"bootstrap\", \"variable\", or \"locked\"."
  }
}

variable "emails" {
  type        = list(string)
  description = "List of user email addresses to bootstrap (used when email_source = variable)"
  default     = []
}

variable "rbac_dry_run" {
  type        = bool
  description = "If true, compute topology but do not create any RBAC bindings in TFE"
  default     = false
}
