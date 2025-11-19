#!/usr/bin/env bash
set -euo pipefail

# tfc_rights_extract.sh
#
# Read-only helper to extract current organization_access rights
# for a TFC team from Terraform state as JSON.
#
# Usage:
#   ./tfc_rights_extract.sh --email raymon.epping@ibm.com
#   ./tfc_rights_extract.sh --address 'tfe_team.shared[0]'
#   ./tfc_rights_extract.sh --email raymon.epping@ibm.com --output rights_raymon.json
#
# Output JSON example:
# {
#   "resource": "tfe_team.personal[\"raymon.epping@ibm.com\"]",
#   "team_email": "raymon.epping@ibm.com",
#   "in_state": true,
#   "name": "team_raymon_epping",
#   "organization": "HUGGING_NL",
#   "visibility": "secret",
#   "allow_member_token_management": true,
#   "organization_access": {
#     "read_workspaces": false,
#     ...
#   }
# }

VERSION="1.1.0"

JT_MODE=false
TEAM_EMAIL=""
RESOURCE_ADDRESS=""
OUTPUT_BASENAME=""
OUTPUT_DIR="."
WORKDIR=""
QUIET_HEADERS=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
tfc_rights_extract.sh v${VERSION}

Usage:
  $0 --email <email> [--output <file.json>] [--output-dir <dir>] [--workdir <dir>] [--jt]
  $0 --address <resource_address> [--output <file.json>] [--output-dir <dir>] [--workdir <dir>] [--jt]

Options:
  --email, -e        User email. Maps to tfe_team.personal["<email>"].
  --address, -a      Full Terraform resource address, for example:
                     'tfe_team.shared[0]' or 'tfe_team.personal["user@example.com"]'
  --output, -o       Output JSON filename. Default:
                       rights_<email>.json or rights_<safe_address>.json
  --output-dir, -d   Directory where JSON will be written. Default: current directory.
  --workdir, -w      Terraform working directory.
                     Default: auto detected from script location.
  --jt, --bring-sexy-back
                     Enable JT mode for root detection logs.
  --help, -h         Show this help and exit.
EOF
}

log() {
  if [[ "${JT_MODE}" == true && "${QUIET_HEADERS}" != true ]]; then
    printf '%s\n' "$@" >&2
  fi
}

# Terraform root auto detection (same pattern as the other scripts)
auto_detect_workdir() {

  local start="$1"
  local dir="$start"

  [[ "$JT_MODE" == true ]] && log ""

  while [[ "$dir" != "/" ]]; do

    log "🎤 Check: Do we have any *.tf? (Uh-huh)"
    if compgen -G "$dir"/*.tf >/dev/null 2>&1; then
      echo "$dir"
      return 0
    fi

    log "🎤 Check: Is the state lying around? (Yeah)"
    if [[ -f "$dir/terraform.tfstate" ]]; then
      echo "$dir"
      return 0
    fi

    log "🎤 Check: Has .terraform locked in the groove? (Come on)"
    if [[ -d "$dir/.terraform" ]]; then
      echo "$dir"
      return 0
    fi

    log "🕺 Move up the directory tree like sliding onto the dance floor"
    dir="$(cd "$dir/.." && pwd)"
  done

  log "fallback: where the beat started"
  echo "$start"
}

# Arg parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email|-e)
      TEAM_EMAIL="${2:-}"
      shift 2
      ;;
    --address|-a)
      RESOURCE_ADDRESS="${2:-}"
      shift 2
      ;;
    --output|-o)
      OUTPUT_BASENAME="${2:-}"
      shift 2
      ;;
    --output-dir|-d)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --workdir|-w)
      WORKDIR="${2:-}"
      shift 2
      ;;
    --jt|--bring-sexy-back)
      JT_MODE=true
      shift
      ;;
    --quiet-headers)
      QUIET_HEADERS=true
      shift
      ;;      
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${RESOURCE_ADDRESS}" && -z "${TEAM_EMAIL}" ]]; then
  echo "Error: provide either --email or --address." >&2
  usage
  exit 1
fi

if [[ -z "${RESOURCE_ADDRESS}" && -n "${TEAM_EMAIL}" ]]; then
  RESOURCE_ADDRESS="tfe_team.personal[\"${TEAM_EMAIL}\"]"
fi

# Normalise dirs
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

if [[ -z "${WORKDIR}" ]]; then
  # Start one level above scripts, where your main .tf and state live
  DEFAULT_WORKDIR="$(auto_detect_workdir "$(cd "$SCRIPT_DIR/.." && pwd)")"
  WORKDIR="${DEFAULT_WORKDIR}"
fi

WORKDIR="$(cd "${WORKDIR}" && pwd)"

# Derive output filename
if [[ -z "${OUTPUT_BASENAME}" ]]; then
  if [[ -n "${TEAM_EMAIL}" ]]; then
    SAFE_EMAIL="${TEAM_EMAIL//[^a-zA-Z0-9_]/_}"
    OUTPUT_BASENAME="rights_${SAFE_EMAIL}.json"
  else
    SAFE_ADDR="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"
    OUTPUT_BASENAME="rights_${SAFE_ADDR}.json"
  fi
fi

OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_BASENAME}"

# Dependencies
if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform is required on PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required on PATH." >&2
  exit 1
fi

if [[ "${QUIET_HEADERS}" != true ]]; then
  if [[ "${JT_MODE}" == true ]]; then
    echo "🎧 Terraform workdir detected: ${WORKDIR}"
    echo ""
  else
    echo "📁 Terraform dir:    ${WORKDIR}"
  fi

  echo "📁 Output dir:       ${OUTPUT_DIR}"
  echo "🔍 Resource address: ${RESOURCE_ADDRESS}"
  echo "📝 Output file:      ${OUTPUT_FILE}"
  echo ""
fi

echo "🔎 Checking if resource is in Terraform state..."
if ! terraform -chdir="${WORKDIR}" state show "${RESOURCE_ADDRESS}" >/dev/null 2>&1; then
  jq -n \
    --arg addr "${RESOURCE_ADDRESS}" \
    --arg email "${TEAM_EMAIL}" \
    '{
      resource: $addr,
      team_email: ($email | select(. != "")),
      in_state: false,
      organization_access: null
    }' > "${OUTPUT_FILE}"

  echo "❌ Resource not in state. Wrote ${OUTPUT_FILE}"
  exit 0
fi

echo "✅ Resource is in state. Reading full state as JSON..."

STATE_JSON="$(terraform -chdir="${WORKDIR}" show -json)"

# Walk all modules, just like the live drift script
jq --arg addr "${RESOURCE_ADDRESS}" --arg email "${TEAM_EMAIL}" '
  def all_resources(m):
    [
      ((m.resources // [])[]),
      ((m.child_modules // [])[] | all_resources(.))
    ]
    | flatten;

  .values as $v
  | ($v.root_module | all_resources(.))
  | map(select(.address == $addr))
  | .[0]? as $res
  | if $res == null then
      {
        resource: $addr,
        team_email: ($email | select(. != "")),
        in_state: true,
        organization_access: null,
        note: "resource not found in JSON tree for this address; check state layout or modules"
      }
    else
      {
        resource: $res.address,
        team_email: ($email | select(. != "")),
        in_state: true,
        name: ($res.values.name // null),
        organization: ($res.values.organization // null),
        visibility: ($res.values.visibility // null),
        allow_member_token_management: ($res.values.allow_member_token_management // null),
        organization_access: ($res.values.organization_access // null)
      }
    end
' <<< "${STATE_JSON}" > "${OUTPUT_FILE}"

if jq -e '.organization_access != null' "${OUTPUT_FILE}" >/dev/null 2>&1; then
  echo "✅ Rights extracted to: ${OUTPUT_FILE}"
else
  echo "⚠️ Resource is in state but organization_access was not found. Wrote minimal info to ${OUTPUT_FILE}"
fi
