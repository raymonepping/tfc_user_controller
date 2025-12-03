variable "tfe_organization" {
  type = string
}

variable "assignment_per_user" {
  type = bool
}

variable "shared_mode" {
  type        = string
  description = "How to handle the shared project: create or existing"
  default     = "create"

  validation {
    condition     = contains(["create", "existing"], var.shared_mode)
    error_message = "shared_mode must be either \"create\" or \"existing\"."
  }
}

variable "projects_prefix" {
  type = string
}

variable "shared_project_name" {
  type = string
}

variable "usernames" {
  type = map(string)
}
