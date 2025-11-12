# 🧩 Terraform Cloud User Controller

Automate the onboarding of tens or hundreds of users into Terraform Cloud — safely, repeatably, and with one command.

Built for workshops, demos, and real-world environments where you want to **create users, assign them to teams and projects, and never destroy what already works**.

---

## 🚀 Features

✅ **Bootstrap new users** from a simple JSON file  
✅ **Automatically create** per-user projects and teams  
✅ **Supports shared mode** (one team/project for everyone)  
✅ **Locks users** so Terraform never deletes them by accident  
✅ **Add or remove users** safely across reruns  
✅ **Converts JSON → HCL** with an included Bash script  
✅ **Clean, modular, and ready for workshops**

---

## 🧭 Repository Overview

```

tfc_user_controller/
├── main.tf                     # Core logic for user, project, and team management
├── variables.tf                # All configurable variables and mode toggles
├── outputs.tf                  # Exposes IDs and names for downstream use
├── versions.tf                 # Provider and Terraform version pins
├── bootstrap.json              # Input list of user emails
├── locked_users.auto.tfvars    # Generated HCL map of locked users
├── assignment_mode.auto.tfvars # Choose between per-user or shared mode
├── scripts/
│   └── generate_tfvars_from_json.sh  # Converts JSON credentials to HCL
└── .env.example                # Environment variables for Terraform Cloud

````

---

## ⚙️ Prerequisites

- **Terraform CLI** ≥ 1.7  
- **Terraform Cloud/Enterprise account**  
- **TFE API Token** with organization admin rights  
- **Bash** and **jq** installed  
- Internet access to Terraform Cloud API  

---

## 🌍 Environment Setup

Create a `.env` file in the project root:

```bash
# Terraform Enterprise Variables
TFE_TOKEN=your-tfe-api-token
TFE_HOST=app.terraform.io
````

Then load it before running Terraform:

```bash
source .env
```

---

## 🧩 Modes of Operation

### Option A — Per-User Mode (Default)

Each user gets:

* `project_<username>`
* `team_<username>`

```hcl
assignment_mode = "per_user"
```

### Option B — Shared Mode

All users join one project and one team — great for labs or hackathons.

```hcl
assignment_mode     = "shared"
shared_project_name = "project_chicago"
shared_team_name    = "team_bulls"
```

👉 These live in `assignment_mode.auto.tfvars`, **not** in your locked users file.

---

## 🧰 The Bootstrap Flow

### Step 1 — Define Users

Create a simple `bootstrap.json` file:

```json
{
  "emails": [
    "raymon@hashicorp.com",
    "cojan@hashicorp.com"
  ]
}
```

### Step 2 — Initialize Terraform

```bash
terraform init
```

### Step 3 — Bootstrap Users

```bash
terraform plan && terraform apply -auto-approve
```

This will:

* Create org memberships for all listed users
* Create per-user or shared projects and teams
* Assign access permissions

Terraform also writes a machine-readable credentials file:

```
credentials.auto.tfvars.json
```

### Step 4 — Convert JSON → HCL

```bash
./scripts/generate_tfvars_from_json.sh credentials.auto.tfvars.json
```

This creates:

```
locked_users.auto.tfvars
```

From now on, Terraform will use this HCL map for steady-state user management.

### Step 5 — Add More Users

Append to `bootstrap.json` and reapply Terraform:

```bash
terraform apply -auto-approve
```

Run the conversion again to refresh the locked file:

```bash
./scripts/generate_tfvars_from_json.sh credentials.auto.tfvars.json
```

Terraform will now ignore previously locked users and only add the new ones.

---

## 🧼 Optional Cleanup

To remove temporary files automatically:

```bash
./scripts/generate_tfvars_from_json.sh credentials.auto.tfvars.json --cleanup
```

This deletes the JSON after successful HCL conversion.

---

## 🧩 Removing or Resetting Users

* **Remove a user** from `locked_users.auto.tfvars` → Terraform will plan to destroy their project/team.
* **Empty the file completely** → Terraform will plan to remove *all* previously locked users (subject to any `prevent_destroy` lifecycle rules).

Safety first:

* By default, `tfe_organization_membership` uses `prevent_destroy = true` to avoid accidental removal.
* You can disable it when you intentionally want a full cleanup.

---

## 🧱 Example Command Sequence

```bash
# 1️⃣ Initialize
terraform init

# 2️⃣ Bootstrap users
terraform apply -auto-approve

# 3️⃣ Convert to locked file
./scripts/generate_tfvars_from_json.sh credentials.auto.tfvars.json

# 4️⃣ Add more users and rerun
terraform apply -auto-approve
./scripts/generate_tfvars_from_json.sh credentials.auto.tfvars.json
```

---

## 🧠 How It Works

| Phase         | Description                                                  |
| ------------- | ------------------------------------------------------------ |
| **Bootstrap** | Reads `bootstrap.json` → creates users, projects, and teams. |
| **Lock**      | Converts credentials JSON → HCL → prevents deletions.        |
| **Expand**    | Add new users → Terraform adds only what’s new.              |
| **Re-lock**   | Refresh HCL and maintain idempotence.                        |

You can switch between per-user and shared modes at any time — just update the `assignment_mode.auto.tfvars` file before bootstrapping.

---

## 🪄 Script Details

Script: [`scripts/generate_tfvars_from_json.sh`](https://github.com/raymonepping/tfc_user_controller/blob/main/scripts/generate_tfvars_from_json.sh)

Converts:

```json
{
  "users": {
    "raymon@hashicorp.com": {
      "username": "raymon",
      "membership_id": "ou-xyz123",
      "user_id": ""
    }
  }
}
```

To:

```hcl
users = {
  "raymon@hashicorp.com" = {
    username      = "raymon"
    membership_id = "ou-xyz123"
    user_id       = ""
  }
}
```

---

## 🧩 Folder Cleanliness

This repository intentionally **ignores `.tf` backups, state files, and temp files** via `.gitignore`.
Your working directory stays clean between runs — just keep the essential `bootstrap.json` and locked files.

---

## 🤝 Credits

**Origin:** Cojan’s Terraform prototype for user/team creation<br>
**Expanded by:** Raymon Epping<br>
**Goal:** Build a reusable, workshop-friendly pipeline for managing Terraform Cloud users safely and at scale.<br>

---

## 🧠 Born from How I Use AI as My DevOps Copilot

🤖 Powered by Sally — my AI DevOps copilot
🚀 Because automation should automate itself.
