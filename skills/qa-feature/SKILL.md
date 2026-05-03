---
name: qa-feature
description: Run ad-hoc QA on any feature on stage.jobescape.me from a free-form spec. Use when the user describes something to test that isn't covered by /qa-upsell, /qa-onboarding, or /qa-unsubflow — e.g. "QA the new course-detail page", "verify the AI chat sends messages", "check that the Academy filter works on mobile viewport", "test the login flow on stage", or invokes /qa-feature. Drives the Playwright executor at ~/jobescape-auto-qa to register a fresh user via funnel (so the test runs as a logged-in paid user), navigate to the target URL, and snapshot or walk it. The skill interprets the executor's report against the user's spec and answers concretely with screenshot evidence.
---

# QA Feature — generalist skill

You are doing ad-hoc QA from a free-form description. The Playwright-based executor at `~/jobescape-auto-qa` provides primitives (navigate + snapshot + optional auto-click walk); your job is to interpret the user's spec, drive the executor, and answer their question with evidence.

You have these resources:

- **`knowledge/feature-guide.yaml`** — auth model, stage URL surface, workflow, modes, anti-patterns

---

## Step 1 — Understand the spec

Read what the user said. Identify:

- **Where**: what URL or page? If they said "the new lesson page" but no URL → ask.
- **What action**: do they want navigation only (snapshot mode) or to click through buttons (explore_buttons) or follow links (explore_links)?
- **What "works" means**: a specific visual ("the price says $X"), a specific behaviour ("clicking Save persists data"), or a smoke check ("the page loads without errors").

If the spec is too vague, ask up to 3 clarifying questions:

1. URL or path on stage.jobescape.me?
2. What specific thing should I verify?
3. Logged-in or logged-out?

---

## Step 2 — Pick mode

- **`snapshot`** (default) — single navigate + full-page screenshot + structure dump. Best when the user's question is "does it render correctly" or "is feature X visible".
- **`explore_buttons`** — after landing, click the first visible button per screen up to `--max-steps`. Best for short happy-path walks.
- **`explore_links`** — like explore_buttons but follows first `<a href>`. Best for navigation/site-map verification.

If unsure → start with `snapshot`. Re-run with `explore_buttons` if needed.

---

## Step 3 — Execute

```bash
cd ~/jobescape-auto-qa && HEADED=1 npx tsx src/index.ts \
  --scenario check_feature \
  --feature-url "https://stage.jobescape.me/<path>" \
  --feature-spec "<short description from user>" \
  --feature-mode <snapshot|explore_buttons|explore_links> \
  --paywall solidgate \
  --subscription 4week \
  [--max-steps N]
```

Wall time: ~5-7 min (mostly funnel registration). Set expectations with the user before starting.

After the run:

```bash
ls -td ~/jobescape-auto-qa/reports/* | head -1
```

Read `report.json`:
- `walkedSteps[0]` — initial-screen state (most useful for snapshot mode)
- `walkedSteps[1..]` — subsequent screens for explore modes
- `checks[]` — page_loaded, no_4xx_5xx, no_console_error_flood
- `notes[]` — feature spec echo + summary stats

---

## Step 4 — Answer the user

For each piece of the user's spec, give a specific yes/no/ambiguous answer:

- **Visual assertions**: open the relevant `step-NN.png` via the Read tool — you have vision — and report what you saw.
- **Text assertions**: search `walkedSteps[].bodyPreview` and `visibleButtons` / `visibleLinks` / `visibleInputs` for the expected strings.
- **Behavioural assertions**: did the URL change after action? Did a confirmation appear? Did a network call return 200?

If a single run isn't enough (e.g., "click Save then verify the data persisted") — chain runs by:
1. Re-running with adjusted `--feature-url` (post-action URL)
2. Re-running with `explore_buttons` mode to drive the click
3. Note: each run starts a FRESH user. State from previous runs doesn't carry.

---

## Step 5 — When to escalate to a richer skill

If the user's spec turns out to be:
- An onboarding flow walk → suggest `/qa-onboarding` instead (it has dedicated decision strategies)
- An unsub flow walk → suggest `/qa-unsubflow`
- An upsell QA → suggest `/qa-upsell`

Don't try to reimplement those flows here. `qa-feature` is the catch-all for things the dedicated skills don't cover.

---

## Anti-patterns

- **Don't claim a feature works without reading the screenshot or walkedSteps[]**. The executor's checks[] are coarse signals, not the final answer.
- **Don't treat 4xx/5xx as automatic fail**. Many stage pages have 403s on third-party assets that aren't user-facing. Check what URL the error came from before flagging.
- **Don't navigate to URLs outside `stage.jobescape.me` / `funnels.jobescape.me`**. The executor's `assertHostAllowed` will refuse, surfacing as a run-failure error.
- **Don't try to test logged-out behaviour by skipping the funnel registration**. The executor's flow always registers — for logged-out tests, manually open an incognito tab and report; this is outside the skill's scope.
- **Don't expand scope mid-test**. If the user asked "does the page load", answer that. Don't also report unrelated findings unless they're severe (broken layout, JS errors crashing the page).
