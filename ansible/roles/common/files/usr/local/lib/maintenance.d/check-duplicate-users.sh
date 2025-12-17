#!/usr/bin/env bash
# Check that no duplicate user names exist

duplicate_users=$(cut -d: -f1 /etc/passwd | sort | uniq -d)

if [[ -n "$duplicate_users" ]]; then
  msg "${RED}  Duplicate user names found:${NOFORMAT}"
  while IFS= read -r user; do
    msg "${RED}    $user${NOFORMAT}"
  done <<<"$duplicate_users"
  exit 1
fi

msg "${GREEN}  No duplicate user names found${NOFORMAT}"
exit 0
