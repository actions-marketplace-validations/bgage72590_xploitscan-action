#!/usr/bin/env bash
# Fail-on gate for the XploitScan GitHub Action.
#
# Thresholds use per-severity graded counts. Graded = critical/high/medium/low.
# Info findings (VC097, VC104, …) never fail the build.
#   critical → critical
#   high     → high + critical
#   medium   → medium + high + critical
#   low      → low + medium + high + critical
#
# Quality findings gate only when FAIL_ON_QUALITY=true, independently
# of FAIL_ON. Invoked from action.yml with every value in env: — do not
# put ${{ expressions in this file.
#
# Env: FAIL_ON, FAIL_ON_QUALITY, CRITICAL, HIGH, MEDIUM, LOW,
#      UNGRADED, QUALITY_HIGH
# Exit: 0 pass, 1 threshold hit, 2 invalid input

# Trim, then treat empty / all-whitespace as none so
# `fail-on: ${{ vars.FAIL_ON }}` with the variable unset still passes.
FAIL_ON=$(printf '%s' "${FAIL_ON}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
FAIL_ON="${FAIL_ON:-none}"
FAIL_ON=$(printf '%s' "${FAIL_ON}" | tr '[:upper:]' '[:lower:]')
case "${FAIL_ON}" in
  none|critical|high|medium|low) ;;
  *)
    echo "::error::XploitScan: unknown fail-on '${FAIL_ON}' (expected none, critical, high, medium, or low)."
    exit 2
    ;;
esac

if [ "${FAIL_ON}" != "none" ]; then
  require_int() {
    local name="$1"
    local raw="$2"
    local val="${raw:-0}"
    if ! [[ "${val}" =~ ^[0-9]+$ ]]; then
      echo "::error::XploitScan: ${name} must be a non-negative integer (got '${raw}')."
      exit 2
    fi
  }
  require_int CRITICAL "${CRITICAL}"
  require_int HIGH "${HIGH}"
  require_int MEDIUM "${MEDIUM}"
  require_int LOW "${LOW}"
  require_int UNGRADED "${UNGRADED}"
  require_int QUALITY_HIGH "${QUALITY_HIGH}"
fi

if [ "${FAIL_ON_QUALITY}" = "true" ] && [ "${QUALITY_HIGH:-0}" -gt 0 ] 2>/dev/null; then
  echo "XploitScan: $QUALITY_HIGH high-severity code-quality finding(s) and fail-on-quality is set. Failing."
  exit 1
fi

if [ "${FAIL_ON}" = "none" ]; then
  echo "XploitScan: No failure threshold set. Passing."
  exit 0
fi

if [ "${FAIL_ON}" = "critical" ] && [ "${CRITICAL:-0}" -gt 0 ]; then
  echo "::error::XploitScan found $CRITICAL critical vulnerabilities"
  exit 1
elif [ "${FAIL_ON}" = "high" ] && [ "$(( ${CRITICAL:-0} + ${HIGH:-0} ))" -gt 0 ]; then
  echo "::error::XploitScan found critical/high vulnerabilities (Critical: $CRITICAL, High: $HIGH)"
  exit 1
elif [ "${FAIL_ON}" = "medium" ] && [ "$(( ${CRITICAL:-0} + ${HIGH:-0} + ${MEDIUM:-0} ))" -gt 0 ]; then
  echo "::error::XploitScan found critical/high/medium vulnerabilities (Critical: $CRITICAL, High: $HIGH, Medium: $MEDIUM)"
  exit 1
elif [ "${FAIL_ON}" = "low" ] && [ "$(( ${CRITICAL:-0} + ${HIGH:-0} + ${MEDIUM:-0} + ${LOW:-0} ))" -gt 0 ]; then
  echo "::error::XploitScan found critical/high/medium/low vulnerabilities (Critical: $CRITICAL, High: $HIGH, Medium: $MEDIUM, Low: $LOW)"
  exit 1
fi

if [ "${UNGRADED:-0}" -gt 0 ]; then
  echo "XploitScan: $UNGRADED finding(s) in vendored, generated, or documentation files were reported but not counted toward this gate."
fi
echo "XploitScan: No findings above the '${FAIL_ON}' threshold. Passing."
