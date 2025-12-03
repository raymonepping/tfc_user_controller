#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

SCENARIO=""
LOAD_USERS="none"       # valid: none, tfc
AUTO_APPLY="false"      # valid: true, false (only relevant for mode=local)
OUT_DIR="./scripts/output"
MODE="scenario"         # valid: scenario, local, git, actual
SHOW_TOPOLOGY="false"   # valid: true, false

# Simple ANSI colors
BOLD=$'\e[1m'
DIM=$'\e[2m'
RESET=$'\e[0m'
CYAN=$'\e[36m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
MAGENTA=$'\e[35m'

print_help() {
  cat <<EOF
${BOLD}${SCRIPT_NAME}${RESET} ${DIM}- Terraform Cloud User Controller wrapper${RESET}

${BOLD}Usage:${RESET}
  ${GREEN}./scripts/${SCRIPT_NAME} --scenario <1-6>${RESET} [options]

${BOLD}Required for scenario/local/git modes:${RESET}
  ${YELLOW}-s, --scenario <1-6>${RESET}      Scenario number to activate:
                              1: Existing project, existing team
                              2: Existing project, new shared team
                              3: New shared project, new shared team
                              4: Per user sandboxes
                              5: Per user sandboxes, locked users
                              6: RBAC validation and topology only

${BOLD}Mode-specific notes:${RESET}
  ${MAGENTA}mode=actual${RESET}               Does not require --scenario, only reads current terraform.auto.tfvars

${BOLD}Options:${RESET}
      ${CYAN}--load-users <mode>${RESET}   User loading mode:
                              none  (default) do not touch locked users
                              tfc   run pull_credentials_from_tfc.sh and regenerate locked_users.auto_tfvars

      ${CYAN}--auto-apply <bool>${RESET}   (mode=local only)
                            If true, run "terraform apply -auto-approve"
                            If false (default), run "terraform plan" only

      ${CYAN}--out-dir <path>${RESET}      Output directory for TFC credentials JSON
                            Default: ./scripts/output

      ${CYAN}--mode <scenario|local|git|actual>${RESET}
                            Execution mode:
                              scenario (default) activate scenario and optionally refresh users, no Terraform, no git
                              local    run terraform init / plan or apply locally
                              git      update files and run commit_gh or scripts/commit_gh.sh
                              actual   inspect and print current active scenario from terraform.auto.tfvars

      ${CYAN}--show-topology <bool>${RESET}
                            If true:
                              mode=local  -> show "terraform output -json topology | jq ."
                              mode=actual -> same, after showing active scenario
                              no scenario -> topology shortcut, no file changes

  ${CYAN}-h, --help${RESET}                Show this help and exit

${BOLD}Examples:${RESET}
  ${DIM}# Only activate Scenario 1, no plan, no commit${RESET}
  ./scripts/${SCRIPT_NAME} --scenario 1

  ${DIM}# Scenario 5 + refresh locked users from TFC + local plan${RESET}
  ./scripts/${SCRIPT_NAME} -s 5 --load-users tfc --mode local

  ${DIM}# Scenario 5 + refresh locked users from TFC + commit to git${RESET}
  ./scripts/${SCRIPT_NAME} -s 5 --load-users tfc --mode git

  ${DIM}# Just show the currently active scenario (from terraform.auto.tfvars)${RESET}
  ./scripts/${SCRIPT_NAME} --mode actual

  ${DIM}# RBAC validation only with topology dump${RESET}
  ./scripts/${SCRIPT_NAME} -s 6 --mode local --show-topology true

  ${DIM}# Inspect active scenario and current topology${RESET}
  ./scripts/${SCRIPT_NAME} --mode actual --show-topology true

  ${DIM}# Topology shortcut, no scenario changes${RESET}
  ./scripts/${SCRIPT_NAME} --show-topology true

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
    --show-topology)
      SHOW_TOPOLOGY="${2:-}"
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

# Basic mode validation
if [[ "${MODE}" != "scenario" && "${MODE}" != "local" && "${MODE}" != "git" && "${MODE}" != "actual" ]]; then
  error "Invalid --mode value: ${MODE}. Use 'scenario', 'local', 'git', or 'actual'."
fi

if [[ "${LOAD_USERS}" != "none" && "${LOAD_USERS}" != "tfc" ]]; then
  error "Invalid --load-users value: ${LOAD_USERS}. Use 'none' or 'tfc'."
fi

if [[ "${AUTO_APPLY}" != "true" && "${AUTO_APPLY}" != "false" ]]; then
  error "Invalid --auto-apply value: ${AUTO_APPLY}. Use 'true' or 'false'."
fi

if [[ "${SHOW_TOPOLOGY}" != "true" && "${SHOW_TOPOLOGY}" != "false" ]]; then
  error "Invalid --show-topology value: ${SHOW_TOPOLOGY}. Use 'true' or 'false'."
fi

# Ensure we are in repo root
if [[ ! -f "main.tf" ]]; then
  error "This script must be run from the repository root (main.tf must exist)."
fi

########################################
# Topology-only shortcut
########################################
if [[ -z "${SCENARIO}" && "${MODE}" != "actual" && "${SHOW_TOPOLOGY}" == "true" ]]; then
  echo "🔍 Topology-only shortcut"
  echo "   No scenario selected."
  echo "   No files will be changed."
  echo "   No terraform plan or apply will be run."
  echo
  echo "🧩 Running: terraform output -json topology | jq ."
  if command -v jq >/dev/null 2>&1; then
    terraform output -json topology | jq .
  else
    echo "ℹ️ jq not found, falling back to raw output:"
    terraform output topology
  fi
  echo
  echo "✅ Done. Topology inspected, nothing else touched."
  exit 0
fi

########################################
# MODE = actual: only inspect current scenario (+ optional topology)
########################################
if [[ "${MODE}" == "actual" ]]; then
  if [[ ! -f "terraform.auto.tfvars" ]]; then
    error "No terraform.auto.tfvars found. Cannot detect active scenario."
  fi

  # Expect something like on line 2:
  # # Scenario 3: New shared project + new shared team
  HEADER_LINE="$(sed -n '2p' terraform.auto.tfvars || true)"

  if [[ -z "${HEADER_LINE}" ]]; then
    echo "ℹ️  Could not read line 2 from terraform.auto.tfvars."
    echo "    Raw file preview:"
    head -n 5 terraform.auto.tfvars || true

    if [[ "${SHOW_TOPOLOGY}" == "true" ]]; then
      echo
      echo "🧩 Showing topology output (terraform output -json topology | jq .)..."
      if command -v jq >/dev/null 2>&1; then
        terraform output -json topology | jq .
      else
        echo "ℹ️ jq not found, falling back to raw output:"
        terraform output topology
      fi
    fi

    exit 0
  fi

  CURRENT_SCENARIO_NUM=""
  CURRENT_SCENARIO_DESC_RAW=""

  if [[ "${HEADER_LINE}" =~ ^\#\ Scenario[[:space:]]+([0-9]+):(.*)$ ]]; then
    CURRENT_SCENARIO_NUM="${BASH_REMATCH[1]}"
    CURRENT_SCENARIO_DESC_RAW="${BASH_REMATCH[2]}"
  fi

  if [[ -z "${CURRENT_SCENARIO_NUM}" ]]; then
    echo "ℹ️  Could not parse a Scenario header from terraform.auto.tfvars."
    echo "    Header line was:"
    echo "    ${HEADER_LINE}"

    if [[ "${SHOW_TOPOLOGY}" == "true" ]]; then
      echo
      echo "🧩 Showing topology output (terraform output -json topology | jq .)..."
      if command -v jq >/dev/null 2>&1; then
        terraform output -json topology | jq .
      else
        echo "ℹ️ jq not found, falling back to raw output:"
        terraform output topology
      fi
    fi

    exit 0
  fi

  # Trim leading space from description if any
  CURRENT_SCENARIO_DESC_RAW="${CURRENT_SCENARIO_DESC_RAW# }"

  # Friendly descriptor
  CURRENT_SCENARIO_DESC=""
  case "${CURRENT_SCENARIO_NUM}" in
    1) CURRENT_SCENARIO_DESC="shared: existing project + existing team" ;;
    2) CURRENT_SCENARIO_DESC="shared: existing project + new shared team" ;;
    3) CURRENT_SCENARIO_DESC="shared: new shared project + new shared team" ;;
    4) CURRENT_SCENARIO_DESC="per user sandboxes: project + team per user" ;;
    5) CURRENT_SCENARIO_DESC="per user sandboxes: locked users" ;;
    6) CURRENT_SCENARIO_DESC="RBAC validation: topology only (dry run wiring)" ;;
    *) CURRENT_SCENARIO_DESC="unknown scenario mapping" ;;
  esac

  SCENARIO_FILE_GUESS="scenarios/terraform.auto.tfvars.s${CURRENT_SCENARIO_NUM}"
  SCENARIO_FILE_STATUS="missing"
  if [[ -f "${SCENARIO_FILE_GUESS}" ]]; then
    SCENARIO_FILE_STATUS="present"
  fi

  echo "🔍 Active scenario inspection (mode=actual)"
  echo "   terraform.auto.tfvars header : ${HEADER_LINE}"
  echo "   Detected scenario number     : ${CURRENT_SCENARIO_NUM}"
  echo "   Detected scenario desc       : ${CURRENT_SCENARIO_DESC}"
  echo "   Matching scenario file       : ${SCENARIO_FILE_GUESS} (${SCENARIO_FILE_STATUS})"
  echo
  echo "   No files were changed."
  echo "   No terraform commands were run."
  echo "   No git commits were made."
  echo

  if [[ "${SHOW_TOPOLOGY}" == "true" ]]; then
    echo "🧩 Showing topology output (terraform output -json topology | jq .)..."
    if command -v jq >/dev/null 2>&1; then
      terraform output -json topology | jq .
    else
      echo "ℹ️ jq not found, falling back to raw output:"
      terraform output topology
    fi
    echo
  fi

  echo "   Not a single rubber duck was sacrificed for debugging. 🦆"
  exit 0
fi

########################################
# For scenario/local/git modes, scenario is required
########################################
if [[ -z "${SCENARIO}" ]]; then
  error "No scenario specified. Use --scenario <1-6> (not required for --mode actual)."
fi

if ! [[ "${SCENARIO}" =~ ^[1-6]$ ]]; then
  error "Invalid scenario: ${SCENARIO}. Must be one of 1, 2, 3, 4, 5, 6."
fi

if [[ ! -d "scenarios" ]]; then
  error "scenarios/ directory not found. It must exist when running in scenario/local/git modes."
fi

SCENARIO_FILE="scenarios/terraform.auto.tfvars.s${SCENARIO}"

if [[ ! -f "${SCENARIO_FILE}" ]]; then
  error "Scenario file not found: ${SCENARIO_FILE}"
fi

# Scenario descriptions
SCENARIO_DESC=""
case "${SCENARIO}" in
  1) SCENARIO_DESC="shared: existing project + existing team" ;;
  2) SCENARIO_DESC="shared: existing project + new shared team" ;;
  3) SCENARIO_DESC="shared: new shared project + new shared team" ;;
  4) SCENARIO_DESC="per user sandboxes: project + team per user" ;;
  5) SCENARIO_DESC="per user sandboxes: locked users" ;;
  6) SCENARIO_DESC="RBAC validation: topology only (dry run wiring)" ;;
esac

echo "🔧 Terraform Cloud User Controller wrapper"
echo "   Scenario        : ${SCENARIO}"
echo "   Scenario desc   : ${SCENARIO_DESC} 🍰🍒"
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
  echo "   Consider this the icing on the cake, cherry optional 🍰🍒"
  echo
  echo "✅ Done."
  exit 0
fi

# MODE = git: commit changes, no terraform
if [[ "${MODE}" == "git" ]]; then
  echo "📤 Git mode selected. Skipping local terraform init/plan/apply."
  echo "   Committing changes so TFC can pick up the new scenario."

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

if [[ "${SHOW_TOPOLOGY}" == "true" ]]; then
  echo
  echo "🧩 Showing topology output (terraform output -json topology | jq .)..."
  if command -v jq >/dev/null 2>&1; then
    terraform output -json topology | jq .
  else
    echo "ℹ️ jq not found, falling back to raw output:"
    terraform output topology
  fi
fi

echo
echo "🎉 Done."
echo "   Scenario ${SCENARIO} executed with load-users=${LOAD_USERS}, mode=${MODE}, auto-apply=${AUTO_APPLY}."
