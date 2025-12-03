##############################################################################
# Scenario 4: Per user sandboxes (per user project + team)
#
# For each email:
#   - project: "workshop_project_<username>"
#   - team:    "workshop_team_<username>"
#   - team has maintain on that project
# Optional:
#   - common team "Contributors" gets access to all projects
##############################################################################

# High level scenario
profile = "per_user"

# Per user naming prefixes
projects_prefix      = "perfect_project"
personal_team_prefix = "perfect_team"

# Email source from bootstrap.json
# Example bootstrap.json:
# {
#   "emails": [
#     "raymon.epping@ibm.com",
#     "alice@example.com",
#     "bob@example.com"
#   ]
# }
email_source = "bootstrap"

# Give a common team access to all user projects (optional)
# This expects an existing team named "Contributors" in the org
enable_common_access = true
common_team_name     = "Contributors"

# Apply RBAC wiring (teams <> projects)
rbac_dry_run = false
