##############################################################################
# Scenario 3: New shared project + new shared team
#
# Terraform will:
#   - create shared project: "Workshop_Default"
#   - create shared team:    "Workshop_Default_Team"
#   - add all emails to that team
#   - give the team "maintain" on the project
##############################################################################

# High level scenario
profile = "shared_new_project_new_team"

# New shared project and team to create
shared_project_name = "Amazing_Project"
shared_team_name    = "Terrible_Team"

# Emails from bootstrap.json
email_source = "bootstrap"

# For now, no extra common team
enable_common_access = false

# Apply RBAC bindings
rbac_dry_run = true
