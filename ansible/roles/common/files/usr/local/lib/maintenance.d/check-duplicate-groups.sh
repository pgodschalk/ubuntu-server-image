#!/usr/bin/env bash
# Check that no duplicate group names exist

duplicate_groups=$(cut -d: -f1 /etc/group | sort | uniq -d)

if [[ -n "$duplicate_groups" ]]; then
  msg "${RED}  Duplicate group names found:${NOFORMAT}"
  while IFS= read -r group; do
    msg "${RED}    $group${NOFORMAT}"
  done <<<"$duplicate_groups"
  exit 1
fi

msg "${GREEN}  No duplicate group names found${NOFORMAT}"
exit 0
