---
name: qa-unsubflow
description: Run automated QA on the jobescape unsubscribe / manage-subscription flow. Use when the user asks to QA unsub, test the cancellation flow, check pause-subscription, walk through the manage-subscriptions page, or invokes /qa-unsubflow. Drives the Playwright executor at ~/jobescape-auto-qa to register a fresh paid user, navigate to /my-profile/manage-subscriptions, click through the flow with multiple strategies (Pause / Turn-off auto-renewal / explore), and report dead ends, broken buttons, network errors, and confirmation outcomes.
---

# QA Unsubflow — orchestrator skill

You are running automated QA on the jobescape unsub flow on stage. The Playwright-based executor lives at `~/jobescape-auto-qa`. Each run registers a fresh paid user, navigates to manage-subscriptions, walks the chosen path, and reports.

You have these resources:

- **`knowledge/unsub-scenarios.yaml`** — entry-screen baseline + 4 base strategies + qa_focus checklist
- **`knowledge/known-anomalies.md`** — shared anomaly log

---

## Step 1 — Confirm scope

Ask:

- **Which paths?** Default plan covers all 4: `pause_first`, `turn_off_first`, `explore_buttons`, `pick_last`. If the user has a hot-spot ("just verify the cancellation reason picker works") — narrow to one strategy.
- **Custom assertions** — anything specific to verify, like:
    - "Verify the win-back offer screen shows the right discounted price"
    - "Verify clicking the X (close) button at any step returns to manage-subscriptions"
    - "Verify pause duration options are: 1 / 2 / 3 months"

If user just said "QA the unsub flow" → run the full default plan (4 runs).

---

## Step 2 — Execute

For each strategy, run via Bash:

```bash
cd ~/jobescape-auto-qa && HEADED=1 npx tsx src/index.ts \
  --scenario check_unsubflow \
  --unsub-strategy <strategy> \
  --paywall solidgate \
  --subscription 4week \
  [--max-steps N]   # optional — default 30
```

Each run takes ~6-7 min (5 min funnel registration + 1-2 min unsub walk).

**Run serially.** 4-run plan = 25-30 min total — set expectations with the user before kicking off.

After each run, latest report dir:

```bash
ls -td ~/jobescape-auto-qa/reports/* | head -1
```

Read `report.json` for `walkedSteps[]`, `checks[]`, `notes[]`.

---

## Step 3 — Aggregate dashboard

### A. Per-strategy summary table

| Strategy | Verdict | Steps | Terminus | Final URL |
|---|---|---|---|---|
| pause_first | ✅ | 5 | confirmation_reached | …/manage-subscriptions?page=fourth |
| turn_off_first | ✅ | 7 | confirmation_reached | …/manage-subscriptions?page=fifth |
| explore_buttons | ⚠️ | 30 | max_steps_reached | (looped on reasons screen) |
| pick_last | ✅ | 7 | confirmation_reached | … |

### B. Per-strategy walked steps

For each run: list URL path + first heading + decision per step. Highlight steps where the URL `?page=X` parameter advanced (to map the multi-page funnel structure).

### C. Findings against qa_focus

Walk through each `qa_focus` item from `unsub-scenarios.yaml` and answer pass/fail/ambiguous with evidence:

- Every reason-for-cancelling option clickable? → grep walkedSteps decisionTaken for "failed option click"
- Win-back offer screens have working Accept/Decline? → check whether explore_buttons reached confirmation
- Final confirmation screen present? → terminus=confirmation_reached
- No 4xx/5xx network errors? → check `no_4xx_5xx_responses`
- Console errors not flooded? → check `no_repeated_console_errors`

### D. Bugs / open questions

Cross-reference `known-anomalies.md`. Surface new ones for the user to confirm before logging.

### E. Visual checks

For any visual assertion ("the win-back banner uses the right brand color", "the price font isn't broken"), open relevant step screenshots via Read tool and answer.

---

## Anti-patterns

- **Don't actually leave the user's test subscription cancelled forever**. The executor registers a fresh user per run — each cancellation is on a throwaway account, not on a real customer. (If the user instead asks you to test on their personal account → refuse and explain why.)
- **Don't run Pause and Turn-off in the SAME process**. Each run starts fresh. Don't try to chain them in one Playwright session.
- **Don't fail a run on console-error count alone**. The executor uses "ambiguous" for >3× steps console errors — surface to user but don't claim "it's broken" without seeing what the errors are.
- **Don't auto-PASS confirmation_reached without verifying the confirmation copy actually says cancellation/pause succeeded**. Some flows reach a "thank you" page that's a win-back (still active subscription).
