#!/usr/bin/env bash
# Check that local interactive user dot files access is configured

valid_shells=$(grep --invert-match '^#' /etc/shells 2>/dev/null)

# Files that must be 0600 if they exist
readonly RESTRICTED_FILES=(.bash_history .netrc)

# Files that must not exist
readonly FORBIDDEN_FILES=(.forward .rhosts)

failed=0

while IFS=: read -r user _ uid _ _ home shell; do
  # Skip system accounts (UID < 1000) except root
  [[ "$uid" -lt 1000 && "$user" != "root" ]] && continue

  # Skip non-interactive users
  if ! echo "$valid_shells" | grep --quiet --line-regexp "$shell"; then
    continue
  fi

  # Skip if home directory doesn't exist
  [[ ! -d "$home" ]] && continue

  # Check forbidden files must not exist
  for file in "${FORBIDDEN_FILES[@]}"; do
    filepath="$home/$file"
    if [[ -e "$filepath" ]]; then
      msg "${RED}  $user: $filepath must not exist${NOFORMAT}"
      failed=1
    fi
  done

  # Check restricted files must be 0600
  for file in "${RESTRICTED_FILES[@]}"; do
    filepath="$home/$file"
    if [[ -f "$filepath" ]]; then
      mode=$(stat --format "%a" "$filepath")
      if [[ "$mode" != "600" ]]; then
        msg "${RED}  $user: $filepath must be 600, has $mode${NOFORMAT}"
        failed=1
      fi
    fi
  done

  # Check all dot files are not group/world writable
  while IFS= read -r -d '' dotfile; do
    mode=$(stat --format "%a" "$dotfile")
    if [[ "${mode:1:1}" =~ [2367] ]] || [[ "${mode:2:1}" =~ [2367] ]]; then
      msg "${RED}  $user: $dotfile has unsafe permissions ($mode)${NOFORMAT}"
      failed=1
    fi
  done < <(find "$home" -maxdepth 1 -name ".*" -type f -print0 2>/dev/null)
done </etc/passwd

if [[ $failed -eq 0 ]]; then
  msg "${GREEN}  All interactive user dot files have correct permissions${NOFORMAT}"
fi

exit $failed
