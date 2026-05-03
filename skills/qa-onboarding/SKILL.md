---
name: qa-onboarding
description: Run automated QA on a jobescape onboarding version. Use when the user asks to QA an onboarding, test an onboarding version, walk through onboarding o1.0.0_claude / o2.2.0 / o3.0.0 / etc., check onboarding flows, or invokes /qa-onboarding. Drives the Playwright executor at ~/jobescape-auto-qa to register a fresh user via funnel, navigate to /onboarding?onboarding_version=<v>, walk all the screens with multiple decision strategies, and report bugs (broken UI, console/network errors, missing-or-unexpected Skip buttons, dead-end screens, missing copy).
---

# QA Onboarding — orchestrator skill

You are running automated QA on a jobescape onboarding version. The Playwright-based executor lives at `~/jobescape-auto-qa`. Your job is to:

1. Identify which onboarding version(s) to test
2. Decide which decision strategies to run
3. Drive the executor via `bash`
4. Read each report and aggregate into a chat-native dashboard

You have these resources:

- **`knowledge/onboardings.yaml`** — known versions + audience + first-screen baseline + QA focus per version
- **`knowledge/known-anomalies.md`** — bugs the tool has previously surfaced (shared with qa-upsell). Cross-reference observations.

**Always read `onboardings.yaml` at the start.** Don't guess from memory — the version list grows.

---

## Step 1 — Identify the target

Ask the user for whatever isn't already provided:

- **Version** (e.g. `o2.2.0`, `o1.0.0_claude`, `o3.0.0`). Look up in `onboardings.yaml`. If unknown, accept it but flag this as "first-time run" and surface findings to update the YAML.
- **Custom focus** — anything specific they want verified, like:
    - "Verify the Skip button is missing on the bot-test step in o3.0.0"
    - "Verify each interest in o2.2.0 (AI Influencer / Chatbot Creation / etc.) actually branches to its own copy"
    - "Visual check on the Claude-branded surfaces"

If the user said "all onboardings" — run the full set listed in `onboardings.yaml` with status=active.

---

## Step 2 — Pick decision strategies

The executor supports `--onboarding-strategy`:

- **`pick_first`** (default) — picks first option on each multi-option screen. Fast, covers happy path.
- **`pick_last`** — picks last option. Useful for o2.2.0 to hit a different interest variant.
- **`all_skip`** — only clicks Skip-labelled buttons; stops if no Skip is offered. Surfaces which steps allow skip vs not.
- **`explore_first_5`** — reserved (not implemented yet); falls back to pick_first.

Default plan for a single version:

1. `pick_first` — happy path
2. `pick_last` — alternative branches (especially useful for o2.2.0)
3. `all_skip` — verifies which steps are/aren't skippable

Show the plan to the user with rough wall-time estimate (~6-8 min per run, dominated by the funnel registration). Wait for "поехали" before executing.

---

## Step 3 — Execute

For each strategy, run via Bash:

```bash
cd ~/jobescape-auto-qa && HEADED=1 npx tsx src/index.ts \
  --scenario check_onboarding \
  --onboarding-version <version> \
  --onboarding-strategy <strategy> \
  --paywall solidgate \
  --subscription 4week \
  [--max-steps N]   # optional — default 60
```

**Cross-platform note:** `~/jobescape-auto-qa` resolves on macOS/Linux + Git Bash on Windows. On Windows cmd.exe use `cd %USERPROFILE%\jobescape-auto-qa`. PowerShell needs `$env:HEADED=1; npx tsx ...`.

Each run takes ~6-8 minutes (5 min funnel registration + onboarding walk).

**Run serially** — single Chromium window per executor process.

After each run, find the latest report:

```bash
ls -td ~/jobescape-auto-qa/reports/* | head -1
```

Read `report.json` for `walkedSteps[]`, `checks[]`, `notes[]`.

---

## Step 4 — Aggregate dashboard

Present a chat-native summary:

### A. Per-strategy verdict table

| Strategy | Verdict | Steps walked | Terminus | Notable |
|---|---|---|---|---|
| pick_first | ✅ | 24 | redirected_off_onboarding | — |
| pick_last  | ✅ | 22 | redirected_off_onboarding | hit AI-Influencer branch |
| all_skip   | ⚠️ | 6  | stuck_no_progress | Skip absent on bot-creation step (✓ good) |

### B. Walked-step trace (compact)

For each strategy, list steps with: step idx | URL path | first heading | decision taken. Highlight steps where:
- `newConsoleErrors` is non-empty
- `newNetworkErrors` is non-empty
- the walker got stuck

### C. UI affordance findings

- Which steps offered Skip (vs which didn't)? Compare against user's spec.
- Which interest variants were exercised in pick_first vs pick_last (for o2.2.0)?
- Console-error counts per step — pages with > 3 are suspicious.

### D. Visual checks

For each user-supplied visual assertion, **open the relevant step screenshot via the Read tool** (you have vision) and answer concretely. The screenshots live at `report.artifactsDir/step-NN.png`.

### E. Bugs / open questions

For each anomaly: cross-reference `known-anomalies.md`. New ones — ask the user "записать это в known-anomalies.md?".

If the version was unknown → ask the user to confirm the discovered structure so you can update `onboardings.yaml` with `verified: true`.

---

## Anti-patterns

- **Don't auto-PASS without reading walkedSteps**. The verdict is "ambiguous" by default for many checks (e.g., `no_4xx_5xx_responses` flags 403s as ambiguous, not fail) — open the steps to interpret severity.
- **Don't claim a Skip button is missing without trying `all_skip` strategy**. The walker proves it by stopping.
- **Don't fold console errors into a single number**. Surface per-step counts; analytics noise on every step is different from a 500 on one specific transition.
- **Don't conflate funnel quiz with onboarding**. The funnel quiz (chat-v3 quiz_version=v6.0.23) is the marketing funnel BEFORE signup. Onboardings are POST-auth on stage.jobescape.me. They're different surfaces and different code paths.
- **Don't promise "I'll run it overnight" without actually starting the run**. Each Bash invocation must be visible in the chat.
