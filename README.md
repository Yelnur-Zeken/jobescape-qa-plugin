# jobescape-qa-plugin

Claude Code plugin for running automated QA across jobescape's main user surfaces — **upsells**, **onboardings**, the **unsubscribe flow**, and any **ad-hoc feature** you describe. Drives the Playwright-based executor at `~/jobescape-auto-qa` through scripted scenario matrices, asks the right clarifying questions, and surfaces a dashboard-style summary in chat.

## Skills

| Skill | Use it for |
|---|---|
| `/qa-upsell` | QA an upsell version (UI / success / already-purchased / decline / skip+chase matrix). Solidgate / Primer / PayPal channels. |
| `/qa-onboarding` | QA a stage onboarding (`o1.0.0_claude` / `o2.2.0` / `o3.0.0` / etc.). Walks all screens with multiple decision strategies (pick_first / pick_last / all_skip) to surface UI affordance bugs. |
| `/qa-unsubflow` | QA the manage-subscriptions / unsub flow on stage. Pause / Turn-off-auto-renewal / explore strategies. |
| `/qa-feature` | Catch-all. Describe what you want tested in any URL on stage; the skill registers a fresh user, navigates there, snapshots or walks it, and answers your spec with screenshot evidence. |

## What it does (general flow)

You type, in Claude Code:

```
/qa-upsell        # or /qa-onboarding, /qa-unsubflow, /qa-feature
```

Each skill:

1. Loads relevant knowledge from baked-in YAMLs — known versions / strategies / focus areas.
2. Asks targeted clarifying questions when needed (new version, vague spec).
3. Builds a test plan and shows it before running.
4. Drives the executor (~5–7 min per run; funnel registration dominates).
5. Aggregates into a dashboard — verdict tables, walked-step traces, console/network errors, visual checks via the Read tool on screenshots, anomalies cross-referenced against `known-anomalies.md`.
6. Offers to save discovered observations back into the knowledge base.

## What's inside

| File | Purpose |
|---|---|
| `skills/qa-upsell/SKILL.md` | Upsell-matrix orchestrator. |
| `skills/qa-onboarding/SKILL.md` | Onboarding walker orchestrator (decision strategies + per-version focus). |
| `skills/qa-unsubflow/SKILL.md` | Unsub-flow walker orchestrator (Pause / Turn-off / explore strategies). |
| `skills/qa-feature/SKILL.md` | Free-form feature-test orchestrator. |
| `knowledge/channels.yaml` | Solidgate / Primer / PayPal rules — test cards, mechanic, automation status, pricing patterns. |
| `knowledge/scenarios.yaml` | The 5 base upsell scenarios + their CLI invocations + when to apply each. |
| `knowledge/versions.yaml` | Every upsell version we know about — baked from xlsx + empirically verified entries. |
| `knowledge/onboardings.yaml` | Known onboarding versions + audience + first-screen baseline + per-version QA focus. |
| `knowledge/unsub-scenarios.yaml` | Unsub-flow entry baseline + 4 decision strategies + qa_focus checklist. |
| `knowledge/feature-guide.yaml` | Auth model + stage URL surface + workflow / modes for ad-hoc feature tests. |
| `knowledge/known-anomalies.md` | Bugs the tool has previously surfaced. Cross-referenced during each run. |
| `install.sh` / `install.ps1` | One-shot installer for the executor. Clones `Yelnur-Zeken/jobescape-auto-qa`, installs deps, downloads Chromium. |

## Install

In Claude Code (any platform):

```
/plugin marketplace add https://github.com/Yelnur-Zeken/jobescape-qa-plugin
/plugin install jobescape-qa@yelnur-zeken
```

Then run the executor installer (one-time):

**macOS / Linux:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/Yelnur-Zeken/jobescape-qa-plugin/main/install.sh)
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Yelnur-Zeken/jobescape-qa-plugin/main/install.ps1 | iex
```

**Windows (Git Bash):** same as macOS command above — `bash <(curl …)` works in Git Bash.

This clones `Yelnur-Zeken/jobescape-auto-qa` to `~/jobescape-auto-qa` (macOS/Linux) or `%USERPROFILE%\jobescape-auto-qa` (Windows) and prepares Chromium.

## Use

Pick the skill that matches what you're testing:

```
/qa-upsell              QA upsell u13.0.4 on Solidgate, 4-week
/qa-onboarding          QA onboarding o2.2.0 with both pick_first and pick_last
/qa-unsubflow           run the full unsub-flow regression
/qa-feature             check that the new lesson page at /academy/<slug> renders
```

Or just describe naturally — Claude routes to the right skill.

The skill walks you through clarifying questions if needed, then drives the executor and presents the dashboard.

## Coverage

**Channels supported:** Solidgate ✓ · Primer (URL flag works, iframe filler pending) · PayPal (URL flag works, double_confirmation walker pending). All three accept `--paywall <name>` on the executor; today only Solidgate runs the full purchase scenarios end-to-end.
**Subscriptions supported:** 4-week (default). 1-week and 12-week need executor work to click the correct plan tile on the selling page.
**Versions baked in:** every entry in the company Upsells.xlsx as of 2026-04-30, plus empirically-verified `u13.0.4` and `u15.4.3` (full price matrices + buy-CTA copy + chase modal text discovered through automated runs).

## Limitations honest about

- **Cross-platform.** Tested on macOS; works on Windows (PowerShell or Git Bash) via the `install.ps1` script. The executor itself is Node + Playwright, no platform-specific code.
- **Headed mode is required.** The funnel error-pages out under default headless config in some sessions; we use a real Chromium window. Means QA runs need a desktop session, not pure CI.
- **Each run takes ~5 minutes** — 4 to walk the funnel + register, 1 to test the upsell. A 6-scenario plan = ~30 min wall time. The Chromium window is busy that whole time.
- **No shared run history yet.** Each colleague's runs live in their own `~/jobescape-auto-qa/reports/`. Future: shared S3/git remote.
- **Vision checks use your own Claude.** When the skill needs a visual verdict ("is the disclaimer text correct", "is the layout broken"), it reads the screenshot via the Read tool — you, the running Claude, have vision built in. No external Vision API key needed. (`ANTHROPIC_API_KEY` in `.env` is left over from an earlier executor-side stub and is fully optional.)
- **PayPal automation needs a walker for the `double_confirmation` mechanic** (popup/scroll → second confirm click) plus sandbox PayPal credentials. The `?paywall=paypal` URL flag works today and the funnel walker reaches the PayPal flow — just the second-confirm click isn't wired yet. `check_ui` against PayPal-only versions works.

## Contributing

When you discover something new in a run (a previously-unknown version's prices, a new anomaly, a new buy-CTA copy), the skill will offer to save it back into `versions.yaml` / `known-anomalies.md`. Accept — it makes the next colleague's run faster.

When the funnel itself changes (new quiz steps, new selling-page copy, payment provider rotation), the executor (`~/jobescape-auto-qa/src/flows/register.ts`) is what needs updating, not this plugin.
