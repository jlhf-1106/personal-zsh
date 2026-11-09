#!/usr/bin/env bash
# Usage: move.sh <issue-number> [status|stage]   (no status = print current status)
#        move.sh list [status|stage]             (tickets of the repo's board)
# stage = start | review | done | ready | backlog, matched against whatever
# Status names the board defines; an exact status name also works.
# Works for any repo/owner (user or org) the current gh login can access.
set -euo pipefail
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
owner=${repo%/*}; name=${repo#*/}

# stage -> case-insensitive regex over status names
stage_re() { case "$(tr A-Z a-z <<<"$1")" in
  start|progress|doing) echo 'progress|doing|started|wip' ;;
  review) echo 'review|qa|testing' ;;
  done|finish|close) echo '^(done|closed|complete|completed|shipped)$' ;;
  ready|todo) echo '^(ready|to ?do|selected.*)$' ;;
  backlog) echo 'backlog|new|triage' ;;
  *) echo "^$1\$" ;; esac; }

if [ "$1" = list ]; then
  pnum=$(gh api graphql -F o="$owner" -F n="$name" -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){projectsV2(first:5){nodes{number}}}}' -q '.data.repository.projectsV2.nodes[0].number // empty')
  [ -n "$pnum" ] || { echo "no board linked to $repo" >&2; exit 2; }
  re=$( [ -n "${2:-}" ] && stage_re "$2" || echo . )
  gh project item-list "$pnum" --owner "$owner" --limit 200 --format json |
    jq -r --arg re "$re" '.items[]|select((.status//"none")|test($re;"i"))|[.content.number//"-",.status//"none",.title]|@tsv'
  exit 0
fi
num=${1:?issue number}; want=${2:-}

item=$(gh api graphql -F o="$owner" -F n="$name" -F i="$num" -f query='
query($o:String!,$n:String!,$i:Int!){repository(owner:$o,name:$n){issueOrPullRequest(number:$i){
 ... on Issue{title projectItems(first:10){nodes{id project{id number}
   status:fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}
 ... on PullRequest{title projectItems(first:10){nodes{id project{id number}
   status:fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}}}}' \
 -q '.data.repository.issueOrPullRequest')

n=$(jq '.projectItems.nodes|length' <<<"$item")
[ "$n" -ge 1 ] || { echo "#$num is not on any project board" >&2; exit 2; }
[ "$n" -eq 1 ] || echo "warn: #$num on $n boards, using first" >&2
pid=$(jq -r '.projectItems.nodes[0].project.id' <<<"$item")
pnum=$(jq -r '.projectItems.nodes[0].project.number' <<<"$item")
iid=$(jq -r '.projectItems.nodes[0].id' <<<"$item")
cur=$(jq -r '.projectItems.nodes[0].status.name // "none"' <<<"$item")
title=$(jq -r .title <<<"$item")

if [ -z "$want" ]; then echo "#$num [$cur] $title"; exit 0; fi
fields=$(gh project field-list "$pnum" --owner "$owner" --format json)
fid=$(jq -r '.fields[]|select(.name=="Status").id' <<<"$fields")
re=$(stage_re "$want")
oid=$(jq -r --arg re "$re" '[.fields[]|select(.name=="Status").options[]|select(.name|test($re;"i"))][0].id // empty' <<<"$fields")
want=$(jq -r --arg re "$re" '[.fields[]|select(.name=="Status").options[]|select(.name|test($re;"i"))][0].name // empty' <<<"$fields")
[ -n "$oid" ] || { echo "no status matching '$2'. options: $(jq -r '[.fields[]|select(.name=="Status").options[].name]|join(", ")' <<<"$fields")" >&2; exit 3; }

[ "$cur" = "$want" ] && { echo "#$num already [$want]"; exit 0; }
gh project item-edit --id "$iid" --project-id "$pid" --field-id "$fid" --single-select-option-id "$oid" >/dev/null
echo "#$num [$cur] -> [$want] $title"
