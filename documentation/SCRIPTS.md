# 🧩 Terraform Cloud User Controller Scripts

This folder contains the helper scripts that make the Terraform Cloud User Controller practical for workshops, demos, and real environments.

Think of it like this:

- Terraform manages users, teams, projects, and RBAC.
- These scripts keep everything repeatable, observable, and fun.  
- `tfc_uc.sh` is your main driver. The rest are focused tools.

---

## 1. Script Index

```bash

| Script                                | Location             | Purpose                                                |
| ------------------------------------- | -------------------- | ------------------------------------------------------ |
| `tfc_uc.sh`                           | `scripts/`           | Scenario selector and controller wrapper               |
| `pull_credentials_from_tfc.sh`        | `scripts/`           | Pull `credentials_json` from TFC and update locks      |
| `generate_tfvars_from_json.sh`        | `scripts/`           | Convert JSON credentials to `locked_users.auto.tfvars` |
| `start_terraform_agent.sh`            | `scripts/`           | Start a Terraform Agent container for demos            |
| `tfc_diff_object.sh`                  | `scripts/`           | Compare config vs state for a single TFC object        |
| `tfc_diff_live_object.sh`             | `scripts/`           | Compare config vs live TFC using refresh-only plan     |
| `tfc_drift.sh`                        | `scripts/`           | Run a full drift triage workflow                       |
| `tfc_rights_extract.sh`               | `scripts/`           | Extract organization access rights for a team or user  |

```

Scenarios live in:

```bash
scenarios/
  terraform.auto.tfvars.s1
  terraform.auto.tfvars.s2
  terraform.auto.tfvars.s3
  terraform.auto.tfvars.s4
  terraform.auto.tfvars.s5
  terraform.auto.tfvars.s6
````

Each scenario file encodes one of the six supported controller modes.

---

## 2. `tfc_uc.sh`  Terraform Cloud User Controller wrapper

**File:** `scripts/tfc_uc.sh`
**Role:** Main entry point to drive the controller.

### 2.1 What it does

1. Activates a scenario by copying:

   ```text
   scenarios/terraform.auto.tfvars.sN -> terraform.auto.tfvars
   ```

2. Optionally pulls users from Terraform Cloud and regenerates `locked_users.auto.tfvars` using:

   * `scripts/pull_credentials_from_tfc.sh`
   * `scripts/generate_tfvars_from_json.sh`

3. Runs in one of four modes:

   * `scenario`
     Only switch scenario and optionally refresh locks. No Terraform, no git.
   * `local`
     Run `terraform init` and `terraform plan` or `terraform apply` locally.
   * `git`
     Commit changes so the Terraform Cloud git workspace picks up the new scenario.
   * `actual`
     Inspect `terraform.auto.tfvars` and print the currently active scenario.

### 2.2 Scenarios

The wrapper knows about six scenarios:

1. Existing project, existing team
2. Existing project, new shared team
3. New shared project, new shared team
4. Per user sandboxes, project and team per user
5. Per user sandboxes, locked users
6. RBAC validation and topology only, typically with locked users

Each scenario file starts with a header line like:

```text
# Scenario 3: New shared project + new shared team
```

### 2.3 Common usage examples

**Only activate a scenario, no Terraform, no git**

```bash
./scripts/tfc_uc.sh --scenario 1
# or
./scripts/tfc_uc.sh -s 1 --mode scenario
```

**Scenario 5, refresh locked users from TFC, local plan**

```bash
./scripts/tfc_uc.sh -s 5 \
  --load-users tfc \
  --mode local \
  --auto-apply false
```

**Scenario 5, refresh locked users, commit to git**

```bash
./scripts/tfc_uc.sh -s 5 \
  --load-users tfc \
  --mode git
```

This uses:

* `commit_gh` from your `$PATH` if available, or
* falls back to `./scripts/commit_gh.sh` if that exists and is executable.

Terraform Cloud then runs the plan in the git based workspace.

**Only inspect the currently active scenario**

```bash
./scripts/tfc_uc.sh --mode actual
```

Sample output:

```text
🔍 Active scenario inspection (mode=actual)
   terraform.auto.tfvars header : # Scenario 3: New shared project + new shared team
   Detected scenario number     : 3
   Detected scenario desc       : shared: new shared project + new shared team
   Matching scenario file       : scenarios/terraform.auto.tfvars.s3 (present)

   No files were changed.
   No terraform commands were run.
   No git commits were made.

   Not a single rubber duck was sacrificed for debugging. 🦆
```

This is the safe, read only way to check what the controller is about to do.

---

## 3. `pull_credentials_from_tfc.sh`

**File:** `scripts/pull_credentials_from_tfc.sh`
**Role:** Fetch `credentials_json` from Terraform and regenerate the locked tfvars file.

### 3.1 What it does

1. Runs:

   ```bash
   terraform output -json credentials_json
   ```

2. Writes the result to:

   ```text
   ./scripts/output/credentials_from_tfc.json
   ```

3. Calls:

   ```bash
   ./scripts/generate_tfvars_from_json.sh ./scripts/output/credentials_from_tfc.json
   ```

   to regenerate `locked_users.auto.tfvars` in the repo root.

### 3.2 Usage

Normally called through `tfc_uc.sh` when `--load-users tfc` is set.
You can also run it directly:

```bash
./scripts/pull_credentials_from_tfc.sh
# or with a custom output directory
./scripts/pull_credentials_from_tfc.sh ./tmp/output
```

---

## 4. `generate_tfvars_from_json.sh`

**File:** `scripts/generate_tfvars_from_json.sh`
**Role:** Convert JSON files into `locked_users.auto.tfvars` for steady state runs.

### 4.1 Supported inputs

* `bootstrap.json` that contains:

  ```json
  {
    "emails": [
      "alice@example.com",
      "bob@example.com"
    ]
  }
  ```

  In this mode the script can drive a bootstrap apply and then convert the generated credentials.

* `credentials.auto.tfvars.json` or any JSON that contains a `users` map:

  ```json
  {
    "users": {
      "alice@example.com": {
        "username": "alice",
        "membership_id": "ou-abc123",
        "user_id": ""
      }
    }
  }
  ```

### 4.2 Output

The script writes:

```hcl
users = {
  "alice@example.com" = {
    username      = "alice"
    membership_id = "ou-abc123"
    user_id       = ""
  }
}
```

to:

```text
locked_users.auto.tfvars
```

in the repo root.

### 4.3 Usage

Convert an existing JSON credentials file:

```bash
./scripts/generate_tfvars_from_json.sh scripts/output/credentials_from_tfc.json
```

Optionally clean up the source JSON after conversion:

```bash
./scripts/generate_tfvars_from_json.sh scripts/output/credentials_from_tfc.json --cleanup
```

---

## 5. `start_terraform_agent.sh`

**File:** `scripts/start_terraform_agent.sh`
**Role:** Start a Terraform Agent container for lab scenarios.

Typical behavior:

* Runs a Docker container with the Terraform Agent image.
* Configures it with your TFC organization and agent token.
* Prints the agent name and connection status.

Example:

```bash
./scripts/start_terraform_agent.sh
```

Use this when you want to demonstrate agent based execution with the same user controller setup.

---

## 6. Drift and diff helpers

These scripts are optional but helpful when you want to explain or debug the controller behavior in workshops.

### 6.1 `tfc_diff_object.sh`

**Role:** Compare desired configuration vs Terraform Cloud state for a single object.

Typical pattern:

```bash
./scripts/tfc_diff_object.sh tfe_team.personal raymon_epping_ibm_com
```

It retrieves the configuration and state representation, writes JSON into `scripts/output`, and shows a summary of differences.

### 6.2 `tfc_diff_live_object.sh`

**Role:** Compare configuration vs live remote data using a refresh only plan.

Usage example:

```bash
./scripts/tfc_diff_live_object.sh tfe_team.personal raymon_epping_ibm_com
```

This is useful to show where live TFC diverges from the last applied state.

### 6.3 `tfc_drift.sh`

**Role:** Run a complete drift triage flow.

Conceptually:

* Run a refresh only plan.
* Capture which resources are out of sync.
* Write structured results to `scripts/output`.
* Help you decide if you want to reconcile or leave them as is.

Usage:

```bash
./scripts/tfc_drift.sh
```

---

## 7. `tfc_rights_extract.sh`

**File:** `scripts/tfc_rights_extract.sh`
**Role:** Extract organization access levels for teams or users.

You can use this in demos to show exactly what rights a workshop team has.

Example:

```bash
./scripts/tfc_rights_extract.sh team Contributors
```

The script writes a JSON summary into `scripts/output/rights_<name>.json`.

---

## 8. Typical flows

### 8.1 Onboard a new workshop cohort

1. Prepare `bootstrap.json` with the attendee emails.

2. Select the scenario you want, for example per user sandboxes:

   ```bash
   ./scripts/tfc_uc.sh -s 4 --mode scenario
   ```

3. If you start from a clean environment and want fresh locked users:

   ```bash
   ./scripts/tfc_uc.sh -s 4 --load-users tfc --mode local
   ```

4. Once everything looks good, switch to git mode so TFC runs all future changes:

   ```bash
   ./scripts/tfc_uc.sh -s 4 --load-users tfc --mode git
   ```

### 8.2 Inspect without touching anything

When in doubt, or live on stage:

```bash
./scripts/tfc_uc.sh --mode actual
```

You see which scenario is active and which scenario file it maps to. 
Terraform and git stay untouched.
The rubber 🦆 stays safe.

---

That is it. The controller logic lives in the Terraform modules.
These scripts are the 🍒 on the 🍰.
that make it enjoyable to drive in front of a room.
