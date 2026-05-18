#!/usr/bin/env bash
set -euo pipefail

# Export Azure Policy Assignments to JSON + TSV (Excel-friendly)
# Fields:
# - Assignment Scope
# - Assignment Name (displayName)
# - Assignment Type (e.g. SystemHidden)
# - Name (policy/initiative name)
# - Type (built-in/custom)
# - Version
# - DefinitionId (last segment of policyDefinitionId)
# - Managed Identity (principalId)
# - Parameters (non-default assignment parameters; key: value, joined by " I ")
# - Policy enforcement

OUT_DIR="${1:-policy_export}"
START_DIR="$PWD"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

echo "[1/7] Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found"; exit 1; }

echo "[2/7] Validating Azure login..."
if ! az account show >/dev/null 2>&1; then
  echo "ERROR: Not logged in. Run: az login"
  exit 1
fi

# echo "[3/7] Collecting subscriptions and management groups..."
# az account list --all --query "[?state=='Enabled'].id" -o tsv > subs.txt
# az account management-group list --query "[].name" -o tsv > mgs.txt || true

# If metadata files already exist in the start directory, reuse them.
# Otherwise fetch them now to keep the script self-sufficient.
if [[ -f "$START_DIR/subs.txt" ]]; then
  cp "$START_DIR/subs.txt" subs.txt
else
  az account list --all --query "[?state=='Enabled'].id" -o tsv > subs.txt
fi

if [[ -f "$START_DIR/mgs.txt" ]]; then
  cp "$START_DIR/mgs.txt" mgs.txt
else
  az account management-group list --query "[].name" -o tsv > mgs.txt || true
fi

# Tenant root scope for policy assignments should be a management group scope,
# not "/". By default we use tenantId (UUID), and allow override via env var.
TENANT_ID="$(az account show --query tenantId -o tsv)"
TENANT_ROOT_MG_ID="${TENANT_ROOT_MG_ID:-$TENANT_ID}"
TENANT_ROOT_SCOPE="/providers/Microsoft.Management/managementGroups/$TENANT_ROOT_MG_ID"

: > assignments.ndjson

echo "[4/7] Collecting assignments from tenant root scope..."
if ! az policy assignment list --scope "$TENANT_ROOT_SCOPE" -o json \
  | jq -c '.[]' >> assignments.ndjson; then
  echo "  - WARNING: Could not read tenant root scope: $TENANT_ROOT_SCOPE"
  echo "    If your tenant root MG ID is different, run with:"
  echo "    TENANT_ROOT_MG_ID=<management-group-id> ./export_policy_assignments.sh"
fi

echo "[5/7] Collecting assignments from management groups..."
if [[ -s mgs.txt ]]; then
  while IFS= read -r mg; do
    [[ -z "$mg" ]] && continue
    echo "  - MG: $mg"
    if ! az policy assignment list \
      --scope "/providers/Microsoft.Management/managementGroups/$mg" \
      -o json \
      | jq -c '.[]' >> assignments.ndjson; then
      echo "    WARNING: Skipping MG (no access or not found): $mg"
    fi
  done < mgs.txt
else
  echo "  - No management groups found or no permissions"
fi

echo "[6/7] Collecting assignments from subscriptions..."
while IFS= read -r sub; do
  [[ -z "$sub" ]] && continue
  echo "  - SUB: $sub"
  if ! az policy assignment list \
    --scope "/subscriptions/$sub" \
    -o json \
    | jq -c '.[]' >> assignments.ndjson; then
    echo "    WARNING: Skipping subscription (no access or not found): $sub"
  fi
done < subs.txt

jq -s 'unique_by(.id)' assignments.ndjson > assignments_all.json

echo "    Total unique assignments: $(jq 'length' assignments_all.json)"

echo "[7/7] Fetching definitions and building final report..."
az policy definition list -o json > policy_definitions.json
az policy set-definition list -o json > initiative_definitions.json
jq -s '.[0] + .[1]' policy_definitions.json initiative_definitions.json > definitions_all.json

jq -n \
  --slurpfile a assignments_all.json \
  --slurpfile d definitions_all.json '
  def v(x):
    if (x|type) == "object" and (x|has("value")) then x.value else x end;

  def normalize_scope($s):
    ($s // "")
    | sub("^/providers/Microsoft.Management/managementGroups/"; "/managementGroups/");

  def params_diff($ap; $dp):
    ($ap // {}) as $assigned
    | ($dp // {}) as $defs
    | [
        $assigned | to_entries[]?
        | .key as $k
        | v(.value) as $aval
        | ($defs[$k].defaultValue?) as $defval
        | if ($defs|has($k)|not) then "\($k): \($aval|tojson)"
          elif ($defval == null and ($defs[$k]|has("defaultValue")|not)) then "\($k): \($aval|tojson)"
          elif ($aval == $defval) then empty
          else "\($k): \($aval|tojson)"
          end
      ]
    | join(" I ");

  ($d[0] | map({ ( .id | ascii_downcase ): . }) | add) as $defMap

  | $a[0]
  | map(
      . as $x
      | ($x.policyDefinitionId | ascii_downcase) as $did
      | ($defMap[$did] // {}) as $def
      | {
          AssignmentScope: normalize_scope($x.scope),
          AssignmentName: ($x.displayName // ""),
          AssignmentType: ($x.assignmentType // ""),
          Name: ($def.displayName // $def.name // ""),
          Type: (
            if (($def.policyType // "") | ascii_downcase) == "builtin" or (($def.policyType // "") | ascii_downcase) == "static"
            then "built-in"
            elif (($def.policyType // "") | ascii_downcase) == "custom"
            then "custom"
            else ""
            end
          ),
          Version: ($def.metadata.version // $def.version // ""),
          DefinitionId: (($x.policyDefinitionId // "") | split("/") | last),
          ManagedIdentity: ($x.identity.principalId // ""),
          Parameters: params_diff($x.parameters; $def.parameters),
          PolicyEnforcement: ($x.enforcementMode // "")
        }
    )
' > policy_assignments_enriched.json

jq -r '
  ([
    "Assignment Scope",
    "Assignment Name",
    "Assignment Type",
    "Name",
    "Type",
    "Version",
    "DefinitionId",
    "Managed Identity",
    "Parameters",
    "Policy enforcement"
  ] | @tsv),
  (.[] | [
    .AssignmentScope,
    .AssignmentName,
    .AssignmentType,
    .Name,
    .Type,
    .Version,
    .DefinitionId,
    .ManagedIdentity,
    .Parameters,
    .PolicyEnforcement
  ] | @tsv)
' policy_assignments_enriched.json > policy_assignments_report.tsv

echo
echo "Done. Files generated in: $PWD"
echo "- assignments_all.json"
echo "- policy_assignments_enriched.json"
echo "- policy_assignments_report.tsv"
echo "Rows in final report: $(($(wc -l < policy_assignments_report.tsv)-1))"
