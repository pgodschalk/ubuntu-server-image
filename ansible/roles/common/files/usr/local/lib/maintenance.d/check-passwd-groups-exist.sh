#!/usr/bin/env bash
# Check that all groups in /etc/passwd exist in /etc/group

invalid_groups=$(
  while IFS=: read -r user _ _ gid _ _ _; do
    if ! getent group "$gid" >/dev/null 2>&1; then
      echo "$user (GID: $gid)"
    fi
  done </etc/passwd
)

if [[ -n "$invalid_groups" ]]; then
  msg "${RED}  Accounts with non-existent primary group:${NOFORMAT}"
  while IFS= read -r entry; do
    msg "${RED}    $entry${NOFORMAT}"
  done <<<"$invalid_groups"
  exit 1
fi

msg "${GREEN}  All primary groups in /etc/passwd exist${NOFORMAT}"
exit 0
