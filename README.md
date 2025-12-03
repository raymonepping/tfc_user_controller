````markdown
# 🧩 Terraform Cloud User Controller

Automate the onboarding of tens or hundreds of users into Terraform Cloud / HCP Terraform in a way that is **safe, repeatable, and scenario driven**.

Built for workshops, demos, and real environments where you want to:

- Create or reuse users, teams, and projects  
- Switch between shared and per user layouts  
- Lock users so you never lose them  
- Validate RBAC topology without changing anything

---

## 🚀 What this controller does

✅ **Bootstrap users** from `bootstrap.json`, inline lists, or a locked map  
✅ **Create or reuse** shared projects and teams  
✅ **Create per user sandboxes** (project + team per user)  
✅ **Support locked users** so Terraform never deletes them by accident  
✅ **Run RBAC dry runs** to inspect topology without changes  
✅ **Pull users from TFC** and convert JSON to HCL with included scripts  
✅ **Expose a `topology` output** that describes the full wiring  
✅ **Clean, modular structure** with separate users, projects, teams, and RBAC modules

---

## 🧭 Repository overview

```text
tfc_user_controller/
├── backend.tf                  # Remote backend (TFC workspace)
├── data.tf                     # Organization and workspace data sources
├── main.tf                     # Root orchestration, module wiring, topology
├── variables.tf                # Global variables and toggles
├── profiles.tf                 # High level profiles (scenarios)
├── outputs.tf                  # Topology and helper outputs
├── versions.tf                 # Provider and Terraform version pins
├── bootstrap.json              # Input list of user emails (bootstrap mode)
├── locked_users.auto.tfvars    # HCL map of locked users (Scenario 5)
├── assignment_mode.auto.tfvars # Legacy override, normally not needed anymore
├── rbac.auto.tfvars.json       # Optional RBAC presets
├── terraform.auto.tfvars       # Active scenario configuration
├── terraform.auto.tfvars.s1.bak  # Scenario 1 example
├── terraform.auto.tfvars.s2.bak  # Scenario 2 example
├── terraform.auto.tfvars.s3.bak  # Scenario 3 example
├── terraform.auto.tfvars.s4.bak  # Scenario 4 example
├── terraform.auto.tfvars.s5.bak  # Scenario 5 example
├── terraform.auto.tfvars.s6.bak  # Scenario 6 example
├── modules/
│   ├── users/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── projects/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── teams/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── rbac/
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── documentation/
│   ├── LOADING_USERS.md        # Detailed user loading strategies
│   └── SCRIPTS.md              # Script reference
├── scripts/
│   ├── output/
│   │   ├── credentials_from_tfc.json
│   │   ├── drift_tfe_team_personal__*.json
│   │   ├── live_diff_tfe_team_personal__*.json
│   │   └── rights_*.json
│   ├── generate_tfvars_from_json.sh*
│   ├── pull_credentials_from_tfc.sh*
│   ├── start_terraform_agent.sh*
│   ├── tfc_diff_live_object.sh*
│   ├── tfc_diff_object.sh*
│   ├── tfc_drift.sh*
│   └── tfc_rights_extract.sh*
├── LICENSE
└── README.md
````

---

## ⚙️ Prerequisites

* **Terraform CLI** ≥ 1.7
* **Terraform Cloud / HCP Terraform organization**
* **TFE API token** with rights to manage teams, projects, and memberships
* **Bash** and **jq** for the helper scripts
* Internet access to Terraform Cloud / HCP Terraform

Some scripts expect environment variables such as `TFE_TOKEN` and `TFE_HOST`. 
See `documentation/LOADING_USERS.md` and `documentation/SCRIPTS.md` for details.

---

## 🌍 Environment setup

Typical local flow:

```bash
# Initialize the backend and providers
terraform init

# Select or edit your desired scenario in terraform.auto.tfvars
# Then run:
terraform plan
terraform apply
```

The backend (organization and workspace) is configured in `backend.tf`.
Organization and workspace metadata are pulled via `data.tf`.

---

## 🧩 Core concepts

### Profiles

Profiles in `profiles.tf` capture the high level intent. They combine multiple low level flags into one scenario label.

Supported profiles:

* `shared_existing_project_existing_team`
* `shared_existing_project_new_team`
* `shared_new_project_new_team`
* `per_user`

You select a profile in `terraform.auto.tfvars`:

```hcl
profile = "per_user"
```

You can override individual knobs (like `assignment_mode`) in the same file if you want more control.

---

### Email sources

You tell the controller where to get its user list via `email_source`:

```hcl
variable "email_source" {
  type        = string
  description = "Where to load emails from: bootstrap.json, variable list, or locked users"
  default     = ""
}
```

Supported values:

1. `bootstrap`
   Emails come from `bootstrap.json`:

   ```json
   {
     "emails": [
       "alice@example.com",
       "bob@example.com"
     ]
   }
   ```

2. `variable`
   Emails are passed inline:

   ```hcl
   email_source = "variable"
   emails = [
     "alice@example.com",
     "bob@example.com"
   ]
   ```

3. `locked`
   Emails and IDs come from the `users` map (locked mode):

   ```hcl
   email_source = "locked"
   using_locked = true

   users = {
     "alice@example.com" = {
       username      = "alice"
       membership_id = "om-123"
       user_id       = "user-abc"
     }
   }
   ```

---

### Locked users

Locked users are stored in `locked_users.auto.tfvars`:

* `scripts/pull_credentials_from_tfc.sh` pulls credentials from TFC into JSON
* `scripts/generate_tfvars_from_json.sh ./scripts/output/credentials_from_tfc.json` converts that JSON into HCL

Example locked file:

```hcl
users = {
  "raymon.epping@ibm.com" = {
    username      = "raymon_epping"
    membership_id = "ou-QerzN71cdBCWGhhf"
    user_id       = ""
  }
}
```

In locked mode:

* Emails come from this `users` map
* Membership IDs and user IDs are trusted from here
* Membership resources are protected with `prevent_destroy = true`

See `documentation/LOADING_USERS.md` for a deep dive.

---

## 🧱 The six scenarios

The controller supports six practical scenarios.

```table
| Scenario | Description                                  | Profile                                 | assignment_mode | email_source | locked | rbac_dry_run |
| -------- | -------------------------------------------- | --------------------------------------- | --------------- | ------------ | ------ | ------------ |
| 1        | Existing project, existing team              | `shared_existing_project_existing_team` | shared          | bootstrap    | no     | false        |
| 2        | Existing project, new shared team            | `shared_existing_project_new_team`      | shared          | bootstrap    | no     | false        |
| 3        | New shared project, new shared team          | `shared_new_project_new_team`           | shared          | bootstrap    | no     | false        |
| 4        | Per user sandboxes (project + team per user) | `per_user`                              | per_user        | bootstrap    | no     | false        |
| 5        | Per user sandboxes with locked users         | `per_user`                              | per_user        | locked       | yes    | true/false   |
| 6        | RBAC validation and topology only            | any of the above                        | varies          | varies       | varies | true         |
```

You have ready made `terraform.auto.tfvars.sX.bak` example files for each scenario:

* `terraform.auto.tfvars.s1` → Scenario 1
* `terraform.auto.tfvars.s2` → Scenario 2
* `terraform.auto.tfvars.s3` → Scenario 3
* `terraform.auto.tfvars.s4` → Scenario 4
* `terraform.auto.tfvars.s5` → Scenario 5
* `terraform.auto.tfvars.s6` → Example RBAC validation config

Copy the desired `.bak` to `terraform.auto.tfvars`, adjust names and emails, then run `terraform plan`.

---

## 🧮 Scenario examples

### Scenario 1

Existing project and existing team

Users from `bootstrap.json` are added to:

* Existing project `Default Project`
* Existing team `Contributors`

```hcl
##############################################################################
# Scenario 1: Existing project + existing team
##############################################################################

profile = "shared_existing_project_existing_team"

shared_project_name = "Default Project"
shared_team_name    = "Contributors"

email_source = "bootstrap"

enable_common_access = false
rbac_dry_run         = false
```

---

### Scenario 2

Existing project and new shared team

Users are added to a new shared team that is attached to an existing project.

```hcl
##############################################################################
# Scenario 2: Existing project + new shared team
##############################################################################

profile = "shared_existing_project_new_team"

shared_project_name = "Default Project"
shared_team_name    = "terrible_team"

email_source = "bootstrap"

enable_common_access = false
rbac_dry_run         = false
```

---

### Scenario 3

New shared project and new shared team

Terraform creates a new project and shared team.

```hcl
##############################################################################
# Scenario 3: New shared project + new shared team
##############################################################################

profile = "shared_new_project_new_team"

shared_project_name = "Workshop_Default"
shared_team_name    = "Workshop_Default_Team"

email_source = "bootstrap"

enable_common_access = false
rbac_dry_run         = false
```

---

### Scenario 4

Per user sandboxes

Each user gets a dedicated project and team.

```hcl
##############################################################################
# Scenario 4: Per user sandboxes (per user project + team)
##############################################################################

profile         = "per_user"
assignment_mode = "per_user"

projects_prefix      = "perfect_project"
personal_team_prefix = "perfect_team"

email_source = "bootstrap"

enable_common_access = true
common_team_name     = "Contributors"

rbac_dry_run = false
```

---

### Scenario 5

Per user sandboxes with locked users

Same layout as Scenario 4, but based on locked users loaded from TFC and converted to HCL.

`locked_users.auto.tfvars`:

```hcl
users = {
  "raymon.epping@ibm.com" = {
    username      = "raymon_epping"
    membership_id = "ou-QerzN71cdBCWGhhf"
    user_id       = ""
  }
}
```

`terraform.auto.tfvars`:

```hcl
##############################################################################
# Scenario 5: Per user sandboxes, locked mode
##############################################################################

profile         = "per_user"
assignment_mode = "per_user"

email_source = "locked"
using_locked = true

projects_prefix      = "perfect_project"
personal_team_prefix = "perfect_team"

enable_common_access = true
common_team_name     = "Contributors"

# Start in validation mode
rbac_dry_run = true
```

Once the topology looks correct, set `rbac_dry_run = false` to apply RBAC while keeping memberships protected.

---

### Scenario 6

RBAC validation and topology only

Scenario 6 is a mode that you layer on top of any scenario by setting:

```hcl
rbac_dry_run = true
```

Typical flow:

```bash
terraform plan
terraform output -json topology
```

This lets you inspect:

* Which users map to which usernames
* Which teams and projects exist
* How RBAC would be wired

All without changing team memberships or project access.

---

## 📡 Topology output

The controller exposes a synthetic `topology` output.

Example:

```bash
terraform output -json topology
```

Example structure:

```json
{
  "assignment_mode": "per_user",
  "email_source": "locked",
  "rbac_dry_run": true,
  "shared": {
    "common_team": "team-tbk4UtUPJAjuFJM9",
    "project_id": null,
    "team_id": null
  },
  "users": {
    "raymon.epping@ibm.com": {
      "username": "raymon_epping",
      "membership_id": "ou-QerzN71cdBCWGhhf",
      "user_id": "",
      "personal_team": "team-XGWgZBvm5wkR9UA2",
      "personal_proj": "prj-BGiGpqxFZeRNhU3p"
    }
  }
}
```

A few useful jq helpers:

List users with their team and project ids:

```bash
terraform output -json topology \
  | jq '.users | to_entries[] | {email: .key, username: .value.username, team: .value.personal_team, project: .value.personal_proj}'
```

List all membership ids:

```bash
terraform output -json topology \
  | jq '.users | to_entries[] | {email: .key, membership_id: .value.membership_id}'
```

Inspect the shared topology:

```bash
terraform output -json topology \
  | jq '.shared'
```

---

## 🔐 Safety and deletion protection

User safety is handled in two layers:

1. **Locked mode**

   * `email_source = "locked"`
   * `using_locked = true`
   * Source of truth is the `users` map in `locked_users.auto.tfvars`

2. **Membership `prevent_destroy`**
   In `modules/users/main.tf`:

   ```hcl
   lifecycle {
     ignore_changes  = [email]
     prevent_destroy = true
   }
   ```

   This guarantees:

   * Terraform will not destroy organization memberships.
   * To intentionally delete memberships you must temporarily change this line and be explicit about it.

This makes the controller safe for workshops and shared environments where accidentally removing users would be painful.

---

## 🧰 Scripts

The `scripts/` folder contains helper tooling for:

* Pulling existing user credentials from TFC
* Comparing configuration vs state and live data
* Converting JSON credentials to HCL locked maps
* Inspecting rights and drift

Key ones for the locked user flow:

* `scripts/pull_credentials_from_tfc.sh`
  Pulls credentials from the TFC workspace into `scripts/output/credentials_from_tfc.json`.

* `scripts/generate_tfvars_from_json.sh ./scripts/output/credentials_from_tfc.json`
  Converts JSON into `locked_users.auto.tfvars`.

Full details in:

* `documentation/LOADING_USERS.md`
* `documentation/SCRIPTS.md`

---

## 🧠 Born from How I Use AI as My DevOps Copilot

🤖 Powered by Sally my AI DevOps copilot
🚀 Because automation should automate itself.

---

## 🧾 License

[GPLv3](LICENSE) © Raymon Epping

```
