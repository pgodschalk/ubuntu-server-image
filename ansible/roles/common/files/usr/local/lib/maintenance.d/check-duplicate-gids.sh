#!/usr/bin/env bash
# Check that no duplicate GIDs exist

duplicate_gids=$(cut -d: -f3 /etc/group | sort | uniq -d)

if [[ -n "$duplicate_gids" ]]; then
  msg "${RED}  Duplicate GIDs found:${NOFORMAT}"
  while IFS= read -r gid; do
    group_names=$(awk -F: -v gid="$gid" '$3 == gid {print $1}' /etc/group \
      | paste -sd, -)
    msg "${RED}    GID $gid: $group_names${NOFORMAT}"
  done <<<"$duplicate_gids"
  exit 1
fi

msg "${GREEN}  No duplicate GIDs found${NOFORMAT}"
exit 0
