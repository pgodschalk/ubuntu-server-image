#!/usr/bin/env bash
# Perform APT maintenance

msg "${BLUE}  Updating package lists...${NOFORMAT}"
apt-get update --quiet --quiet || die "apt-get update failed"

msg "${BLUE}  Upgrading packages...${NOFORMAT}"
apt-get dist-upgrade --yes --quiet --quiet || die "apt-get dist-upgrade failed"

msg "${BLUE}  Removing unused packages...${NOFORMAT}"
apt-get autoremove --yes --quiet --quiet || die "apt-get autoremove failed"

msg "${BLUE}  Cleaning package cache...${NOFORMAT}"
apt-get clean --quiet --quiet || die "apt-get clean failed"

msg "${GREEN}  APT maintenance completed${NOFORMAT}"
exit 0
