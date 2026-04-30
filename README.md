# jobescape-qa-plugin

Claude Code plugin for running automated QA on jobescape upsell flows. Drives the Playwright-based executor at `~/jobescape-auto-qa` through the full base-scenario matrix, asks the right clarifying questions for new upsell versions, and surfaces a dashboard-style summary in chat.

## What it does

You type, in your Claude Code:

```
QA upsell u15.4.3 on Solidgate, 4-week
```

The plugin:

1. Loads version metadata from baked-in knowledge — pages, mechanic, expected prices, channel quirks, known anomalies.
2. If the version is new (not in the knowledge base), asks 4 targeted questions (pages / mechanic / prices / unique features).
3. Builds the right test plan: 5 base scenarios (UI / success paths / already-purchased / decline / skip+chase) plus your custom checks.
4. Drives the executor in the background. ~5 minutes per run; the plan typically runs 5–7 scenarios serially.
5. Aggregates everything into a dashboard in chat — summary table, empirical price matrix, anomalies cross-referenced against `known-anomalies.md`, screenshots inline for failures.
6. Offers to save newly discovered observations back into the knowledge base so the next colleague QAing the same version doesn't have to re-answer the same questions.

## What's inside

| File | Purpose |
|---|---|
| `skills/qa-upsell/SKILL.md` | Orchestrator. Identifies the version, runs the clarifying-question protocol, builds and executes the plan, presents the dashboard. |
| `knowledge/channels.yaml` | Solidgate / Primer / PayPal rules — test cards, mechanic, automation status, pricing patterns. |
| `knowledge/scenarios.yaml` | The 5 base scenarios + their CLI invocations + when to apply each. |
| `knowledge/versions.yaml` | Every upsell version we know about — baked from xlsx + empirically verified entries. |
| `knowledge/known-anomalies.md` | Bugs the tool has previously surfaced. Cross-referenced during each run. |
| `install.sh` | One-shot installer for the executor. Clones `Yelnur-Zeken/jobescape-auto-qa`, installs deps, downloads Chromium. |

## Install

```
/plugin marketplace add https://github.com/Yelnur-Zeken/jobescape-qa-plugin
/plugin install jobescape-qa@yelnur-zeken
```

Then run the executor installer (one-time):

```
bash <(curl -sL https://raw.githubusercontent.com/Yelnur-Zeken/jobescape-qa-plugin/main/install.sh)
```

This clones `Yelnur-Zeken/jobescape-auto-qa` to `~/jobescape-auto-qa` and prepares Chromium.

## Use

Minimal:

```
/jobescape-qa:qa-upsell

(or just describe naturally:)

QA upsell u13.0.4 on Solidgate, 4-week subscription. Verify the disclaimer
on page 2 contains "cancel anytime".
```

The skill walks you through the rest — channel-specific rules apply automatically (Solidgate uses 4242, PayPal automation is blocked, etc.).

## Coverage

**Channels supported:** Solidgate ✓ · Primer (planned) · PayPal (manual only — OAuth-gated)
**Subscriptions supported:** 4-week (default). 1-week and 12-week need executor work.
**Versions baked in:** every entry in the company Upsells.xlsx as of 2026-04-30, plus empirically-verified `u13.0.4` and `u15.4.3` (full price matrices + buy-CTA copy + chase modal text discovered through automated runs).

## Limitations honest about

- **Headed mode is required.** The funnel error-pages out under default headless config in some sessions; we use a real Chromium window. Means QA runs need a desktop session, not pure CI.
- **Each run takes ~5 minutes** — 4 to walk the funnel + register, 1 to test the upsell. A 6-scenario plan = ~30 min wall time. The Chromium window is busy that whole time.
- **No shared run history yet.** Each colleague's runs live in their own `~/jobescape-auto-qa/reports/`. Future: shared S3/git remote.
- **Vision checks need `ANTHROPIC_API_KEY` env var** in `~/jobescape-auto-qa/.env`. Optional — the tool falls back to "ambiguous, needs human review" without it.
- **PayPal automation is blocked.** PayPal sandbox login uses OAuth + sometimes 2FA; reliably fails on the auth screen. Recommend manual QA for PayPal-only versions.

## Contributing

When you discover something new in a run (a previously-unknown version's prices, a new anomaly, a new buy-CTA copy), the skill will offer to save it back into `versions.yaml` / `known-anomalies.md`. Accept — it makes the next colleague's run faster.

When the funnel itself changes (new quiz steps, new selling-page copy, payment provider rotation), the executor (`~/jobescape-auto-qa/src/flows/register.ts`) is what needs updating, not this plugin.
