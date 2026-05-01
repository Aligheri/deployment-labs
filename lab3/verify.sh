#!/bin/bash
# Post-deployment verification script.
# Run on the target node. Checks service availability and nginx config correctness.
set -uo pipefail

TARGET_HOST="${TARGET_HOST:-localhost}"
APP_PORT="${APP_PORT:-8080}"
BASE_URL="http://${TARGET_HOST}"
APP_URL="http://localhost:${APP_PORT}"
EXIT_CODE=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; EXIT_CODE=1; }

# 1. App health (direct to app port, bypasses nginx)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/health/alive")
[ "$STATUS" = "200" ] && pass "/health/alive returns 200" || fail "/health/alive returned ${STATUS}"

# 2. DB readiness
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/health/ready")
[ "$STATUS" = "200" ] && pass "/health/ready returns 200" || fail "/health/ready returned ${STATUS}"

# 3. Items endpoint accessible via nginx
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Accept: application/json" "${BASE_URL}/items")
[ "$STATUS" = "200" ] && pass "nginx proxies /items (200)" || fail "nginx /items returned ${STATUS}"

# 4. nginx is the server
SERVER=$(curl -sI "${BASE_URL}/" 2>/dev/null | grep -i "^Server:" | tr -d '\r\n' || true)
echo "${SERVER}" | grep -qi "nginx" \
    && pass "nginx is serving (${SERVER})" \
    || fail "nginx not detected (${SERVER})"

# 5. nginx blocks undefined paths with 404
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/undefined-path-xyz")
[ "$STATUS" = "404" ] && pass "nginx returns 404 for unknown paths" \
    || fail "expected 404 for unknown path, got ${STATUS}"

# 6. Health endpoints are NOT exposed via nginx
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health/alive")
[ "$STATUS" = "404" ] && pass "nginx does not expose /health (404)" \
    || fail "nginx should block /health, got ${STATUS}"

# Summary
echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "All verification checks PASSED"
else
    echo "Some verification checks FAILED"
fi

exit "$EXIT_CODE"
