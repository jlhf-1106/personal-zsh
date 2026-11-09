#!/usr/bin/env bash
# Usage: priority.sh <issue-number> [level]   (no level = print current priority)
#        priority.sh list [status|stage]      (board tickets, highest priority first)
# level = urgent | high | medium | low | none, matched against the owner's
# native "Priority" issue field (an org issue field, not a label or project field).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
owner=${repo%/*}; name=${repo#*/}

# Issue fields belong to the organization; user-owned repos have none.
field=$(gh api graphql -F o="$owner" -f query='
query($o:String!){organization(login:$o){issueFields(first:50){nodes{
 ... on IssueFieldSingleSelect{id name options{id name}}}}}}' \
 -q '[.data.organization.issueFields.nodes[]|select(.name=="Priority")][0] // empty' 2>/dev/null || true)
[ -n "$field" ] || { echo "$owner has no native Priority issue field" >&2; exit 2; }
fid=$(jq -r .id <<<"$field")

# Priority of each issue: "number<TAB>name" ("none" when unset).
VALUES='issueFieldValues(first:20){nodes{... on IssueFieldSingleSelectValue{name field{... on IssueFieldSingleSelect{name}}}}}'
prio_of='([.issueFieldValues.nodes[]|select(.field.name=="Priority").name][0] // "none")'

if [ "${1:-}" = list ]; then
  prios=$(gh api graphql --paginate -F o="$owner" -F n="$name" -f query="
query(\$o:String!,\$n:String!,\$endCursor:String){repository(owner:\$o,name:\$n){
 issues(first:100,states:OPEN,after:\$endCursor){pageInfo{hasNextPage endCursor} nodes{number $VALUES}}}}" \
   -q ".data.repository.issues.nodes[]|[.number, $prio_of]|@tsv")
  # Join with the board's tickets, then sort Urgent > High > Medium > Low > none.
  "$here/move.sh" list ${2:+"$2"} | awk -F'\t' -v OFS='\t' '
    BEGIN { r["Urgent"] = 0; r["High"] = 1; r["Medium"] = 2; r["Low"] = 3 }
    NR == FNR { p[$1] = $2; next }
    { pr = ($1 in p) ? p[$1] : "none"; rank = (pr in r) ? r[pr] : 4; print rank, $1, pr, $2, $3 }' \
    <(printf '%s\n' "$prios") - |
    sort -t$'\t' -k1,1n -k2,2n | cut -f2-
  exit 0
fi
num=${1:?issue number}; want=${2:-}

issue=$(gh api graphql -F o="$owner" -F n="$name" -F i="$num" -f query="
query(\$o:String!,\$n:String!,\$i:Int!){repository(owner:\$o,name:\$n){issue(number:\$i){id title $VALUES}}}" \
 -q '.data.repository.issue')
iid=$(jq -r .id <<<"$issue")
title=$(jq -r .title <<<"$issue")
cur=$(jq -r "$prio_of" <<<"$issue")

if [ -z "$want" ]; then echo "#$num [$cur] $title"; exit 0; fi

if [ "$(tr A-Z a-z <<<"$want")" = none ]; then
  want=none; value=$(jq -nc --arg f "$fid" '{fieldId:$f, delete:true}')
else
  oid=$(jq -r --arg w "$want" '[.options[]|select(.name|ascii_downcase==($w|ascii_downcase))][0].id // empty' <<<"$field")
  [ -n "$oid" ] || { echo "no priority '$want'. options: $(jq -r '[.options[].name]|join(", ")' <<<"$field"), none" >&2; exit 3; }
  want=$(jq -r --arg o "$oid" '.options[]|select(.id==$o).name' <<<"$field")
  value=$(jq -nc --arg f "$fid" --arg o "$oid" '{fieldId:$f, singleSelectOptionId:$o}')
fi

[ "$cur" = "$want" ] && { echo "#$num already [$want]"; exit 0; }
jq -nc --arg i "$iid" --argjson v "$value" '{
  query: "mutation($in:SetIssueFieldValueInput!){setIssueFieldValue(input:$in){clientMutationId}}",
  variables: {in: {issueId: $i, issueFields: [$v]}}}' | gh api graphql --input - >/dev/null
echo "#$num [$cur] -> [$want] $title"
