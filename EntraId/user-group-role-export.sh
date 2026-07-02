#!/bin/bash
#
# entraid-user-and-role-export.sh
#
# Description:
#   Exports Microsoft Entra ID users with their profile data, account creation date,
#   last sign-in date (interactive and non-interactive merged into the most recent),
#   assigned Entra directory roles (direct and inherited via Security Groups),
#   and group memberships (by display name).
#   Additionally exports all Security Groups with their assigned directory roles.
#
#   Output files:
#     users_export.csv           - user list with roles and groups
#     security_groups_export.csv - security groups with roles
#
#   All timestamps are converted to Europe/Warsaw local time (CET/CEST).
#
# Usage:
#   bash entraid-user-and-role-export.sh
#
#   Optional env overrides:
#     TEST_USER_UPN_PREFIX=<upn_prefix>  - limit export to a single user (testing)
#     TOP_LIMIT=<n>                      - limit export to first N users (testing)
#
# Created by: Chris Polewiak
# With the assistance of: Claude AI (Anthropic) & GitHub Copilot (VS Code)
#

GRAPH="https://graph.microsoft.com/v1.0"
GRAPH_BETA="https://graph.microsoft.com/beta"
TOP_LIMIT=0  # 0 = no limit (full export); set to e.g. 10 for testing
processed=0
TEST_USER_UPN_PREFIX=""  # optional: set UPN prefix to limit export to one user (e.g. for testing)

GROUP_ROLE_MAP_FILE="group_role_map.tmp"
USER_ROLE_MAP_FILE="user_role_map.tmp"

fetch_all_items() {
  local url="$1"
  local response

  while [ -n "$url" ]; do
    response=$(az rest --method GET --uri "$url" -o json)
    echo "$response" | jq -c '.value[]?'
    url=$(echo "$response" | jq -r '."@odata.nextLink" // empty')
  done
}

collect_distinct_csv() {
  tr ',' '\n' | sed '/^$/d' | sort -u | paste -sd ',' -
}

to_warsaw_time() {
  local ts="$1"

  if [ -z "$ts" ]; then
    echo ""
    return
  fi

  TZ=Europe/Warsaw jq -nr --arg ts "$ts" '$ts | fromdateiso8601 | strflocaltime("%Y-%m-%d %H:%M:%S")' 2>/dev/null || echo ""
}

echo "Building role maps (directory roles -> users/groups)..."
: > "$GROUP_ROLE_MAP_FILE"
: > "$USER_ROLE_MAP_FILE"

while read role; do
  rid=$(echo "$role" | jq -r '.id')
  rname=$(echo "$role" | jq -r '.displayName')

  fetch_all_items "$GRAPH/directoryRoles/$rid/members/microsoft.graph.group?\$select=id" \
    | jq -r --arg rname "$rname" '.id + ";" + $rname' >> "$GROUP_ROLE_MAP_FILE"

  fetch_all_items "$GRAPH/directoryRoles/$rid/members/microsoft.graph.user?\$select=id" \
    | jq -r --arg rname "$rname" '.id + ";" + $rname' >> "$USER_ROLE_MAP_FILE"
done < <(fetch_all_items "$GRAPH/directoryRoles?\$select=id,displayName")

echo "UserId;displayName;FirstName;LastName;UPN;Email;Company;JobTitle;Department;CreatedAt;LastSignIn;EntraRoles;Groups" > users_export.csv
echo "GroupId;DisplayName;IsAssignableToRole;Roles" > security_groups_export.csv

if [ -n "$TEST_USER_UPN_PREFIX" ]; then
  url="$GRAPH_BETA/users?\$filter=startswith(userPrincipalName,'$TEST_USER_UPN_PREFIX')&\$select=id,displayName,givenName,surname,userPrincipalName,mail,companyName,jobTitle,department,createdDateTime,signInActivity&\$top=999"
else
  url="$GRAPH_BETA/users?\$select=id,displayName,givenName,surname,userPrincipalName,mail,companyName,jobTitle,department,createdDateTime,signInActivity&\$top=999"
fi

while [ -n "$url" ]; do

  response=$(az rest --method GET --uri "$url" -o json)

  while read user; do

    if [ "$TOP_LIMIT" -gt 0 ] && [ "$processed" -ge "$TOP_LIMIT" ]; then
      break
    fi

    uid=$(echo $user | jq -r '.id')

    displayName=$(echo $user | jq -r '.displayName')
    first=$(echo $user | jq -r '.givenName')
    last=$(echo $user | jq -r '.surname')
    upn=$(echo $user | jq -r '.userPrincipalName')
    email=$(echo $user | jq -r '.mail')
    company=$(echo $user | jq -r '.companyName')
    title=$(echo $user | jq -r '.jobTitle')
    dept=$(echo $user | jq -r '.department')
    createdAtRaw=$(echo $user | jq -r '.createdDateTime // ""')
    createdAt=$(to_warsaw_time "$createdAtRaw")
    lastInteractiveSignInRaw=$(echo $user | jq -r '.signInActivity.lastSignInDateTime // ""')
    lastNonInteractiveSignInRaw=$(echo $user | jq -r '.signInActivity.lastNonInteractiveSignInDateTime // ""')
    lastSignInRaw=$(printf '%s\n%s\n' "$lastInteractiveSignInRaw" "$lastNonInteractiveSignInRaw" | grep -v '^$' | sort -r | head -n1)
    lastSignIn=$(to_warsaw_time "$lastSignInRaw")

    groups=$(fetch_all_items "$GRAPH/users/$uid/transitiveMemberOf/microsoft.graph.group?\$select=id,displayName" \
      | jq -r '.displayName' \
      | paste -sd '|' -)

    directRoles=$(awk -F';' -v uid="$uid" '$1==uid{print $2}' "$USER_ROLE_MAP_FILE" | sort -u | paste -sd ',' -)
    inheritedRoles=""

    if [ -n "$groups" ]; then
      inheritedRoles=$(echo "$groups" | tr ',' '\n' | while read gid; do
        awk -F';' -v gid="$gid" '$1==gid{print $2}' "$GROUP_ROLE_MAP_FILE"
      done | sort -u | paste -sd ',' -)
    fi

    roles=$(printf "%s\n%s\n" "$directRoles" "$inheritedRoles" | collect_distinct_csv)

    echo "$uid  $displayName  $first  $last  $upn  $email  $company  $title  $dept  $createdAt  $lastSignIn  $roles  $groups"

    echo "$uid;$displayName;$first;$last;$upn;$email;$company;$title;$dept;$createdAt;$lastSignIn;$roles;$groups" >> users_export.csv

    processed=$((processed + 1))

  done < <(echo "$response" | jq -c '.value[]')

  if [ "$TOP_LIMIT" -gt 0 ] && [ "$processed" -ge "$TOP_LIMIT" ]; then
    break
  fi

  url=$(echo "$response" | jq -r '."@odata.nextLink" // empty')

done

echo "Building security groups export..."

group_url="$GRAPH/groups?\$filter=securityEnabled eq true&\$select=id,displayName,isAssignableToRole&\$top=999"
while [ -n "$group_url" ]; do
  group_response=$(az rest --method GET --uri "$group_url" -o json)

  while read grp; do
    gid=$(echo "$grp" | jq -r '.id')
    gname=$(echo "$grp" | jq -r '.displayName')
    isAssignable=$(echo "$grp" | jq -r '.isAssignableToRole')
    groles=$(awk -F';' -v gid="$gid" '$1==gid{print $2}' "$GROUP_ROLE_MAP_FILE" | sort -u | paste -sd ',' -)

    echo "$gid;$gname;$isAssignable;$groles" >> security_groups_export.csv
  done < <(echo "$group_response" | jq -c '.value[]')

  group_url=$(echo "$group_response" | jq -r '."@odata.nextLink" // empty')
done

rm -f "$GROUP_ROLE_MAP_FILE" "$USER_ROLE_MAP_FILE"

echo "Done -> users_export.csv (processed: $processed users)"
echo "Done -> security_groups_export.csv"
