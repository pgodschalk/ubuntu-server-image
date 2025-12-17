#!/usr/bin/env bash
# Check that local interactive user home directories are configured

valid_shells=$(grep --invert-match '^#' /etc/shells 2>/dev/null)

failed=0

while IFS=: read -r user _ uid _ _ home shell; do
  # Skip system accounts (UID < 1000) except root
  [[ "$uid" -lt 1000 && "$user" != "root" ]] && continue

  # Skip non-interactive users
  if ! echo "$valid_shells" | grep --quiet --line-regexp "$shell"; then
    continue
  fi

  # Check if home directory exists
  if [[ ! -d "$home" ]]; then
    msg "${RED}  $user: home directory $home does not exist${NOFORMAT}"
    failed=1
    continue
  fi

  # Check if home directory is owned by user
  owner=$(stat --format "%U" "$home")
  if [[ "$owner" != "$user" ]]; then
    msg "${RED}  $user: home directory $home is owned by $owner${NOFORMAT}"
    failed=1
  fi

  # Check if home directory has safe permissions (not group/world writable)
  mode=$(stat --format "%a" "$home")
  if [[ "${mode:1:1}" =~ [2367] ]] || [[ "${mode:2:1}" =~ [2367] ]]; then
    msg "${RED}  $user: home directory $home has unsafe permissions ($mode)${NOFORMAT}"
    failed=1
  fi
done </etc/passwd

if [[ $failed -eq 0 ]]; then
  msg "${GREEN}  All interactive user home directories are configured correctly${NOFORMAT}"
fi

exit $failed
