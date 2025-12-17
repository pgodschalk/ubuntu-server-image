#!/usr/bin/env bash
# Perform snap maintenance

if ! command -v snap &>/dev/null; then
  msg "${ORANGE}  snap not installed (skipped)${NOFORMAT}"
  exit 0
fi

msg "${BLUE}  Refreshing snap packages...${NOFORMAT}"
snap refresh || die "snap refresh failed"

msg "${GREEN}  Snap maintenance completed${NOFORMAT}"
exit 0
