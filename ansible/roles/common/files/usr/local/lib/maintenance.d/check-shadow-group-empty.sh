#!/usr/bin/env bash
# Check that the shadow group has no members

shadow_members=$(awk -F: '/^shadow:/ {print $4}' /etc/group)

[[ -z "$shadow_members" ]] || die "Shadow group has members: $shadow_members"

msg "${GREEN}  Shadow group is empty${NOFORMAT}"
exit 0
