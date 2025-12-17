#!/usr/bin/env bash
# Check for world-writable files and directories (without sticky bit)

world_writable_files=$(find / -xdev -type f -perm -0002 2>/dev/null)
world_writable_dirs=$(find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null)

failed=0

if [[ -n "$world_writable_files" ]]; then
  msg "${RED}  World-writable files found:${NOFORMAT}"
  while IFS= read -r file; do
    msg "${RED}    $file${NOFORMAT}"
  done <<<"$world_writable_files"
  failed=1
fi

if [[ -n "$world_writable_dirs" ]]; then
  msg "${RED}  World-writable directories without sticky bit found:${NOFORMAT}"
  while IFS= read -r dir; do
    msg "${RED}    $dir${NOFORMAT}"
  done <<<"$world_writable_dirs"
  failed=1
fi

if [[ $failed -eq 0 ]]; then
  msg "${GREEN}  No world-writable files or directories found${NOFORMAT}"
fi

exit $failed
