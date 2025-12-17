#!/usr/bin/env bash
# Check /etc/security/opasswd permissions and ownership

readonly FILE="/etc/security/opasswd"
readonly EXPECTED_MODE="600"
readonly EXPECTED_OWNER="root"
readonly EXPECTED_GROUP="root"

if [[ ! -f "$FILE" ]]; then
  msg "${ORANGE}  $FILE does not exist (skipped)${NOFORMAT}"
  exit 0
fi

actual_mode=$(stat --format "%a" "$FILE")
actual_owner=$(stat --format "%U" "$FILE")
actual_group=$(stat --format "%G" "$FILE")

failed=0

if [[ "$actual_mode" != "$EXPECTED_MODE" ]]; then
  msg "${RED}  $FILE has mode $actual_mode, expected $EXPECTED_MODE${NOFORMAT}"
  failed=1
fi

if [[ "$actual_owner" != "$EXPECTED_OWNER" ]]; then
  msg "${RED}  $FILE is owned by $actual_owner, expected $EXPECTED_OWNER${NOFORMAT}"
  failed=1
fi

if [[ "$actual_group" != "$EXPECTED_GROUP" ]]; then
  msg "${RED}  $FILE has group $actual_group, expected $EXPECTED_GROUP${NOFORMAT}"
  failed=1
fi

if [[ $failed -eq 0 ]]; then
  msg "${GREEN}  $FILE: OK${NOFORMAT}"
fi

exit $failed
