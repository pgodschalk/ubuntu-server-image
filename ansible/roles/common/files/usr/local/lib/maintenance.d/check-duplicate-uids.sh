#!/usr/bin/env bash
# Check that no duplicate UIDs exist

duplicate_uids=$(cut -d: -f3 /etc/passwd | sort | uniq -d)

if [[ -n "$duplicate_uids" ]]; then
  msg "${RED}  Duplicate UIDs found:${NOFORMAT}"
  while IFS= read -r uid; do
    user_names=$(awk -F: -v uid="$uid" '$3 == uid {print $1}' /etc/passwd \
      | paste -sd, -)
    msg "${RED}    UID $uid: $user_names${NOFORMAT}"
  done <<<"$duplicate_uids"
  exit 1
fi

msg "${GREEN}  No duplicate UIDs found${NOFORMAT}"
exit 0
