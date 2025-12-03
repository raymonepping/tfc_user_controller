variable "tfe_organization" {
  type = string
}

variable "email_source" {
  type        = string
  description = "Where to load emails from: bootstrap, variable, or locked"
}

variable "emails" {
  type        = list(string)
  description = "Email list used when email_source = variable"
  default     = []
}

variable "using_locked" {
  type        = bool
  description = "Legacy flag for locked mode. If email_source = locked, this is forced true."
  default     = false
}

variable "users" {
  type = map(object({
    username      = string
    membership_id = string
    user_id       = optional(string)
  }))
  default = {}
}

variable "bootstrap_file" {
  type        = string
  description = "Path to bootstrap.json with emails[]"
}

variable "write_credentials_file" {
  type        = bool
  description = "Write credentials.auto.tfvars.json with resolved IDs"
}

variable "protect_memberships" {
  type        = bool
  description = "If true, prevent_destroy on org memberships to avoid accidental deletion"
  default     = true
}
