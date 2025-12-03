##############################################################################
# Controller profiles
#
# High level intent bundles for typical TFC user onboarding scenarios.
# Most users only set var.profile and let this map drive defaults.
##############################################################################

variable "profile" {
  type        = string
  description = "High level controller profile"
  default     = "shared_existing_project_new_team"

  validation {
    condition = contains([
      "shared_existing_project_existing_team",
      "shared_existing_project_new_team",
      "shared_new_project_new_team",
      "per_user"
    ], var.profile)
    error_message = "profile must be one of: shared_existing_project_existing_team, shared_existing_project_new_team, shared_new_project_new_team, per_user."
  }
}

locals {
  controller_profiles = {
    # (1) existing project, existing team
    shared_existing_project_existing_team = {
      assignment_mode      = "shared"
      shared_project_mode  = "existing"
      shared_team_mode     = "existing"
      using_locked         = false
      enable_common_access = false
      email_source         = "bootstrap"
    }

    # (2) existing project, new team
    shared_existing_project_new_team = {
      assignment_mode      = "shared"
      shared_project_mode  = "existing"
      shared_team_mode     = "create"
      using_locked         = false
      enable_common_access = false
      email_source         = "bootstrap"
    }

    # (3) new project, new team
    shared_new_project_new_team = {
      assignment_mode      = "shared"
      shared_project_mode  = "create"
      shared_team_mode     = "create"
      using_locked         = false
      enable_common_access = false
      email_source         = "bootstrap"
    }

    # (4) per user project and team
    per_user = {
      assignment_mode      = "per_user"
      shared_project_mode  = "create"
      shared_team_mode     = "create"
      using_locked         = false
      enable_common_access = true
      email_source         = "bootstrap"
    }
  }

  # Selected profile settings
  profile_settings = lookup(
    local.controller_profiles,
    var.profile,
    local.controller_profiles.shared_existing_project_new_team
  )

}
