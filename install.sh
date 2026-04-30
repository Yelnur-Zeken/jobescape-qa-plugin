#!/usr/bin/env bash
# One-shot installer for the jobescape-auto-qa Playwright executor.
# Run this once after installing the jobescape-qa plugin via Claude Code.
# Idempotent — re-running is safe (it just re-syncs deps).

set -euo pipefail

EXECUTOR_DIR="${HOME}/jobescape-auto-qa"
EXECUTOR_REPO="https://github.com/Yelnur-Zeken/jobescape-auto-qa.git"

echo "▶ jobescape-qa plugin installer"
echo ""

if [ ! -d "${EXECUTOR_DIR}" ]; then
  echo "  · Cloning executor → ${EXECUTOR_DIR}"
  git clone "${EXECUTOR_REPO}" "${EXECUTOR_DIR}"
else
  echo "  · Executor exists at ${EXECUTOR_DIR} — pulling latest"
  (cd "${EXECUTOR_DIR}" && git pull --rebase --autostash)
fi

echo "  · npm install in ${EXECUTOR_DIR}"
(cd "${EXECUTOR_DIR}" && npm install --silent)

echo "  · Installing Chromium (Playwright)"
(cd "${EXECUTOR_DIR}" && npx playwright install chromium)

if [ ! -f "${EXECUTOR_DIR}/.env" ]; then
  cp "${EXECUTOR_DIR}/.env.example" "${EXECUTOR_DIR}/.env"
  echo "  · Created ${EXECUTOR_DIR}/.env from .env.example — edit it if you need ANTHROPIC_API_KEY for Vision checks"
fi

echo ""
echo "✓ Installed."
echo ""
echo "Try it:"
echo "  In Claude Code, type: /qa-upsell u13.0.4 4-week solidgate"
echo "  Or describe naturally: 'QA upsell u15.4.3 on Solidgate, 4-week subscription'"
