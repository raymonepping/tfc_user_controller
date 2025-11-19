#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./scripts/output}"
mkdir -p "${OUT_DIR}"

echo "📡 Fetching credentials_json from Terraform Cloud..."
terraform output -json credentials_json > "${OUT_DIR}/credentials_from_tfc.json"

echo "📦 Regenerating locked_users.auto.tfvars..."
./scripts/generate_tfvars_from_json.sh "${OUT_DIR}/credentials_from_tfc.json"

echo "✅ Done."
echo "   Raw JSON → ${OUT_DIR}/credentials_from_tfc.json"
echo "   HCL TFVARS → locked_users.auto.tfvars"
