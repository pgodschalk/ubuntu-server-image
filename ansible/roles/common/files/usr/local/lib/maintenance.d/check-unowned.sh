#!/usr/bin/env bash
# Check for files and directories without a valid owner or group

nouser=$(find / -xdev -nouser 2>/dev/null)
nogroup=$(find / -xdev -nogroup 2>/dev/null)

failed=0

if [[ -n "$nouser" ]]; then
  msg "${RED}  Files/directories without valid owner found:${NOFORMAT}"
  while IFS= read -r item; do
    msg "${RED}    $item${NOFORMAT}"
  done <<<"$nouser"
  failed=1
fi

if [[ -n "$nogroup" ]]; then
  msg "${RED}  Files/directories without valid group found:${NOFORMAT}"
  while IFS= read -r item; do
    msg "${RED}    $item${NOFORMAT}"
  done <<<"$nogroup"
  failed=1
fi

if [[ $failed -eq 0 ]]; then
  msg "${GREEN}  No unowned files or directories found${NOFORMAT}"
fi

exit $failed
