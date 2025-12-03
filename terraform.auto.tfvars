##############################################################################
# Scenario 1: Existing project + existing team
#
# Users from bootstrap.json are added to:
#   - existing project: "Default Project"
#   - existing team:    "Contributors"
##############################################################################

# High level scenario
profile = "shared_existing_project_existing_team"

# Existing TFC project and team
shared_project_name = "Default Project"
shared_team_name    = "terrible_team"

# Email source comes from bootstrap.json
email_source = "bootstrap"

# Use org level "Contributors" team only, no extra common access logic
enable_common_access = false

# Actually apply RBAC changes
rbac_dry_run = false
