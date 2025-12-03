variable "assignment_per_user" {
  type = bool
}

variable "enable_common_access" {
  type = bool
}

variable "effective_emails" {
  type = set(string)
}

variable "membership_ids" {
  type = map(string)
}

variable "usernames" {
  type = map(string)
}

variable "personal_team_ids" {
  type = map(string)
}

variable "shared_team_id" {
  type     = string
  nullable = true
}

variable "common_team_id" {
  type     = string
  nullable = true
}

variable "user_project_ids" {
  type = map(string)
}

variable "shared_project_id" {
  type     = string
  nullable = true
}

variable "rbac_dry_run" {
  type        = bool
  description = "If true, do not create any RBAC bindings in TFE"
}
