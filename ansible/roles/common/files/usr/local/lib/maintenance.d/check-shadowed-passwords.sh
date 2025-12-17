#!/usr/bin/env bash
# Check that all accounts use shadowed passwords

unshadowed=$(awk -F: '$2 != "x" {print $1}' /etc/passwd)

if [[ -n "$unshadowed" ]]; then
  msg "${RED}  Accounts not using shadowed passwords:${NOFORMAT}"
  while IFS= read -r user; do
    msg "${RED}    $user${NOFORMAT}"
  done <<<"$unshadowed"
  exit 1
fi

msg "${GREEN}  All accounts use shadowed passwords${NOFORMAT}"
exit 0
