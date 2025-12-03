##############################################################################
# Scenario 5: Per user sandboxes, locked mode
#
# - Reuse users and IDs from locked_users.auto.tfvars
# - Do not create or destroy organization memberships
# - Still manage projects, teams, and RBAC
##############################################################################

# High level scenario
profile         = "per_user"
assignment_mode = "per_user"

# Email source based on the locked users map
email_source = "locked"
using_locked = true

# Per user naming prefixes (must match Scenario 4)
projects_prefix      = "perfect_project"
personal_team_prefix = "perfect_team"

# Common team still has access to all projects (optional)
enable_common_access = true
common_team_name     = "Contributors"

# Safe first run: set to true if you just want to see the topology
# and ensure no RBAC changes. Once happy, flip to false to apply.
rbac_dry_run = true
