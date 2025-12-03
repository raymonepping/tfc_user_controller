#!/usr/bin/env bash
set -euo pipefail

# tfc_uc.sh
#
# Wrapper for the Terraform Cloud User Controller.
#
# Responsibilities:
#   1) Select and activate a scenario (1 to 6) by copying:
#        scenarios/terraform.auto.tfvars.sN -> terraform.auto.tfvars
#   2) Optionally pull users from TFC and regenerate locked_users.auto.tfvars
#        via scripts/pull_credentials_from_tfc.sh
#   3) Optionally:
#        - run terraform init / plan / apply locally (mode=local)
#        - or commit changes to git and let TFC run the plan (mode=git)
#
# Default behavior (mode=scenario):
#   - Only update terraform.auto.tfvars and optionally locked_users.auto.tfvars.
#   - No Terraform commands.
#   - No git commits.
#
# Usage examples:
#   ./scripts/tfc_uc.sh --scenario 4
#   ./scripts/tfc_uc.sh -s 5 --load-users tfc --mode local --auto-apply true
#   ./scripts/tfc_uc.sh -s 5 --load-users tfc --mode git
#
# Scenarios:
#   1: Existing project, existing team
#   2: Existing project, new shared team
#   3: New shared project, new shared team
#   4: Per user sandboxes (per user project and team)
#   5: Per user sandboxes, locked users
#   6: RBAC validation and topology only (typically uses locked mode)

SCRIPT_NAME="$(basename "$0")"

SCENARIO=""
LOAD_USERS="none"      # valid: none, tfc
AUTO_APPLY="false"     # valid: true, false (only relevant for mode=local)
OUT_DIR="./scripts/output"
MODE="scenario"        # valid: scenario, local, git

print_help() {
  cat <<EOF
${SCRIPT_NAME} - Terraform Cloud User Controller wrapper

Usage:
  ./scripts/${SCRIPT_NAME} --scenario <1-6> [options]

Required:
  -s, --scenario <1-6>      Scenario number to activate:
                              1: Existing project, existing team
                              2: Existing project, new shared team
                              3: New shared project, new shared team
                              4: Per user sandboxes
                              5: Per user sandboxes, locked users
                              6: RBAC validation and topology only

Options:
      --load-users <mode>   User loading mode:
                              none  (default) do not touch locked users
                              tfc   run pull_credentials_from_tfc.sh and regenerate locked_users.auto_tfvars
      --auto-apply <bool>   (mode=local only)
                            If true, run "terraform apply -auto-approve"
                            If false (default), run "terraform plan" only
      --out-dir <path>      Output directory for TFC credentials JSON
                            Default: ./scripts/output
      --mode <scenario|local|git>
                            Execution mode:
                              scenario (default) activate scenario and optionally refresh users, no Terraform, no git
                              local    run terraform init / plan or apply locally
                              git      update files and run commit_gh or scripts/commit_gh.sh
  -h, --help                Show this help and exit

Examples:
  # Only activate Scenario 1, no plan, no commit
  ./scripts/${SCRIPT_NAME} --scenario 1

  # Scenario 5 + refresh locked users from TFC + local plan
  ./scripts/${SCRIPT_NAME} -s 5 --load-users tfc --mode local

  # Scenario 5 + refresh locked users from TFC + commit to git
  ./scripts/${SCRIPT_NAME} -s 5 --load-users tfc --mode git

EOF
}

error() {
  echo "❌ $*" >&2
  exit 1
}

# Simple arg parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--scenario)
      SCENARIO="${2:-}"
      shift 2
      ;;
    --load-users)
      LOAD_USERS="${2:-}"
      shift 2
      ;;
    --auto-apply)
      AUTO_APPLY="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      error "Unknown argument: $1 (use --help for usage)"
      ;;
  esac
done

# Basic validations
if [[ -z "${SCENARIO}" ]]; then
  error "No scenario specified. Use --scenario <1-6>."
fi

if ! [[ "${SCENARIO}" =~ ^[1-6]$ ]]; then
  error "Invalid scenario: ${SCENARIO}. Must be one of 1, 2, 3, 4, 5, 6."
fi

if [[ "${LOAD_USERS}" != "none" && "${LOAD_USERS}" != "tfc" ]]; then
  error "Invalid --load-users value: ${LOAD_USERS}. Use 'none' or 'tfc'."
fi

if [[ "${AUTO_APPLY}" != "true" && "${AUTO_APPLY}" != "false" ]]; then
  error "Invalid --auto-apply value: ${AUTO_APPLY}. Use 'true' or 'false'."
fi

if [[ "${MODE}" != "scenario" && "${MODE}" != "local" && "${MODE}" != "git" ]]; then
  error "Invalid --mode value: ${MODE}. Use 'scenario', 'local', or 'git'."
fi

# Check we are in the repo root
if [[ ! -f "main.tf" || ! -d "scenarios" ]]; then
  error "This script must be run from the repository root (main.tf and scenarios/ must exist)."
fi

SCENARIO_FILE="scenarios/terraform.auto.tfvars.s${SCENARIO}"

if [[ ! -f "${SCENARIO_FILE}" ]]; then
  error "Scenario file not found: ${SCENARIO_FILE}"
fi

echo "🔧 Terraform Cloud User Controller wrapper"
echo "   Scenario        : ${SCENARIO}"
echo "   Scenario file   : ${SCENARIO_FILE}"
echo "   Load users mode : ${LOAD_USERS}"
echo "   Execution mode  : ${MODE}"
echo "   Auto apply      : ${AUTO_APPLY} (local mode only)"
echo "   Output dir      : ${OUT_DIR}"
echo

# 1) Activate scenario
echo "📂 Activating scenario ${SCENARIO}..."
cp "${SCENARIO_FILE}" terraform.auto.tfvars
echo "✅ terraform.auto.tfvars updated from ${SCENARIO_FILE}"
echo

# 2) Optional user retrieval and locked_users regeneration
if [[ "${LOAD_USERS}" == "tfc" ]]; then
  echo "📡 Pulling credentials from Terraform Cloud and regenerating locked_users.auto.tfvars..."
  ./scripts/pull_credentials_from_tfc.sh "${OUT_DIR}"
  echo
else
  echo "📡 Skipping user retrieval (load-users = ${LOAD_USERS})."
  echo
fi

# 3) Mode routing

# MODE = scenario: only prepare files, no Terraform, no git
if [[ "${MODE}" == "scenario" ]]; then
  echo "📄 Scenario-only mode selected."
  echo "   Scenario ${SCENARIO} is now active in terraform.auto.tfvars."
  echo "   locked_users.auto.tfvars refreshed: ${LOAD_USERS}"
  echo "   No terraform commands were run."
  echo "   No git commits were made."
  echo
  echo "✅ Done."
  exit 0
fi

# MODE = git: commit changes, no terraform
if [[ "${MODE}" == "git" ]]; then
  echo "📤 Git mode selected. Skipping local terraform init/plan/apply."
  echo "   Committing changes so TFC can pick up the new scenario."

  # Prefer commit_gh in PATH, then fallback to scripts/commit_gh.sh
  if command -v commit_gh >/dev/null 2>&1; then
    echo "📝 Using commit_gh from PATH: $(command -v commit_gh)"
    commit_gh
  elif [[ -x "./scripts/commit_gh.sh" ]]; then
    echo "📝 Using ./scripts/commit_gh.sh as fallback."
    ./scripts/commit_gh.sh
  else
    error "Git mode requested but neither 'commit_gh' nor './scripts/commit_gh.sh' was found or executable."
  fi

  echo
  echo "🎉 Done."
  echo "   Scenario ${SCENARIO} executed with load-users=${LOAD_USERS}, mode=git."
  echo "   Git commit helper ran, TFC will handle the run from the git workspace."
  exit 0
fi

# MODE = local: run terraform directly
echo "🏗  Local mode selected. Running terraform directly."

echo "🧱 Running terraform init -upgrade..."
terraform init -upgrade
echo

if [[ "${AUTO_APPLY}" == "true" ]]; then
  echo "🚀 Running terraform apply -auto-approve..."
  terraform apply -auto-approve
else
  echo "🔍 Running terraform plan..."
  terraform plan
fi

echo
echo "🎉 Done."
echo "   Scenario ${SCENARIO} executed with load-users=${LOAD_USERS}, mode=${MODE}, auto-apply=${AUTO_APPLY}."
