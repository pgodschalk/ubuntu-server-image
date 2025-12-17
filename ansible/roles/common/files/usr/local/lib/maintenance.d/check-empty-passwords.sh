#!/usr/bin/env bash
# Check that no accounts have empty password fields in /etc/shadow

empty_pw=$(awk -F: '$2 == "" {print $1}' /etc/shadow)

if [[ -n "$empty_pw" ]]; then
  msg "${RED}  Accounts with empty password fields:${NOFORMAT}"
  while IFS= read -r user; do
    msg "${RED}    $user${NOFORMAT}"
  done <<<"$empty_pw"
  exit 1
fi

msg "${GREEN}  No accounts with empty password fields${NOFORMAT}"
exit 0
