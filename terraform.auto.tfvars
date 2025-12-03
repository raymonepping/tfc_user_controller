##############################################################################
# Scenario 2: Existing project + new shared team
#
# Users from var.emails are added to:
#   - existing project: "Default Project"
#   - new team:         "terrible_team"
##############################################################################

# High level scenario
profile = "shared_existing_project_new_team"

# Existing TFC project name
shared_project_name = "Default Project"

# New shared team that will be created for this cohort
shared_team_name = "terrible_team"

# Email source comes from bootstrap.json
email_source = "bootstrap"

# Use org level "Contributors" team only, no extra common access logic
enable_common_access = false

# Actually apply RBAC changes
rbac_dry_run = false
