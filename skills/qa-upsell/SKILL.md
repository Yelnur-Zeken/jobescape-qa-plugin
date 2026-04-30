---
name: qa-upsell
description: Run automated QA on a jobescape upsell version. Use when the user asks to QA an upsell, test an upsell version, check upsell flows, validate upsell prices, run regression on an upsell, or invokes /qa-upsell. Asks the right clarifying questions for unknown versions, drives the Playwright executor at ~/jobescape-auto-qa through the full base-scenario matrix (UI / success paths / decline / already-purchased / skip+chase), and presents a dashboard-style summary of pass/fail/anomaly findings in chat.
---

# QA Upsell — orchestrator skill

You are running automated QA on a jobescape upsell version on behalf of a PM/QAer. The Playwright-based executor lives at `~/jobescape-auto-qa`. Your job is to:

1. Identify what to test (version + channel + subscription + custom asks)
2. Build the right test plan from the base-scenario matrix
3. Execute it via `bash`
4. Aggregate results into a dashboard-style summary in chat

You have these resources:

- **`knowledge/channels.yaml`** — per-channel rules (cards, mechanic, automation status, pricing patterns)
- **`knowledge/scenarios.yaml`** — base 5 scenarios + how each maps to a CLI invocation
- **`knowledge/versions.yaml`** — known upsell metadata (pages, mechanic, expected prices, channels, status)
- **`knowledge/known-anomalies.md`** — bugs the tool has previously surfaced; warn user about these for affected versions

**Always read these files at the start of a run.** Don't guess from memory — version data drifts as new upsells ship.

---

## Step 1 — Identify the QA target

Ask the user for whatever isn't already provided:

- **Version** (e.g. `u15.4.3`, `u13.0.4`)
- **Channel** (Solidgate / Primer / PayPal). Look up the version in `versions.yaml` to see which channels it's available on. If only one is supported, default to it.
- **Subscription** (1-week / 4-week / 12-week). Defaults to 4-week (the funnel walker's auto-selected plan). Note: the executor doesn't yet support 1w/12w via CLI flag — surface this as a limitation if user asks.
- **Variant** (standard / chase) — usually `standard`. Chase is reached by skipping inside a path, not as a top-level variant.

---

## Step 2 — Look up the version

Read `knowledge/versions.yaml`. Two cases:

### Case A — Known version (entry exists, especially `verified: true`)

The skill already knows pages, mechanic, expected prices, buy CTA text, channel quirks, and any anomalies. Skip to Step 4 — only ask the user **one** question:

> Что-то уникальное в этой версии за пределами baseline? (например: A/B disclaimer на page 2, кастомная цена которую надо проверить, новая копия CTA)

### Case B — Unknown version (no entry in versions.yaml)

This is a new A/B test or a version not yet in the xlsx. Ask the user **4 questions** in one go (numbered, each standalone):

1. **Сколько страниц** в этой версии? (1 / 2 / 3)
2. **Какая механика покупки?** (`one_click` — клик-и-готово, как у Solidgate-апселлов / `double_confirmation` — клик → попап/скролл → подтверждение, типичный для PayPal / `two_click` — две отдельные страницы апселлов)
3. **Какие ожидаемые цены?** Пожалуйста по каждой странице: standard и chase. Если page без chase — пиши «no chase». Пример формата: `page 1: $99.99 std / $79.99 chase; page 2: $79.99 std / $63.99 chase`
4. **Что-то уникальное помимо базы?** Кастомные disclaimer'ы, CTA-копия, особенности дизайна, custom assertions.

After receiving answers, **save the new version to `versions.yaml`** with `verified: false` and a note "Provided by user on YYYY-MM-DD pending automated verification" — so the next colleague QAing the same version doesn't have to re-answer.

---

## Step 3 — Channel-specific rules (auto-applied)

Read `knowledge/channels.yaml`. Apply the rules:

- **Solidgate** — automation supported. Use card 4242 for funnel registration on success runs, card 4123 for funnel registration on `check_decline` runs. Forces `?paywall=solidgate` in funnel URL (already in executor).
- **Primer** — **automation not yet supported in the executor**. If the user picks Primer, surface this and ask if they want to (a) wait for Primer support to ship, (b) run on Solidgate as a proxy if the version also serves Solidgate, or (c) do manual QA. Do NOT silently fall back.
- **PayPal** — **automation BLOCKED** (OAuth-gated). For PayPal-only versions (u15.1.1, u15.1.2, u13.0.1, u15.3.1), the tool can only run `check_ui` (page renders, view event fires). All purchase scenarios must be done manually. Surface this clearly.

---

## Step 4 — Build the test plan

Pull base scenarios from `scenarios.yaml`. Default plan for an automatable channel + N pages:

1. **`check_ui`** — page renders, view event fires
2. **`check_works` `buy` × N** — buy on every page
3. **`check_works` `skip_chase_skip` × N** — full-skip path; if a page has no chase (e.g. u13.0.4 page 2), use `skip` for that page instead. Validates skip flow and reveals all chase prices.
4. **`check_works` `skip_chase_buy` × N** — buy chases; validates chase-buy mechanic across all pages
5. **`check_already_purchased`** — buy → reload → click Buy AGAIN → expect "Already purchased" popup + unsuccessful_purchase event
6. **`check_decline`** — funnel with decline-card → upsell click → expect "decline" popup + unsuccessful_purchase event + retry CTA. Skip on PayPal.

If the user requested **custom checks** in Step 1/2, add them as additional assertions to verify after the runs (read screenshots, search DOM observations, etc).

If the upsell has 2+ pages, optionally add **mixed paths** to test conditional pricing:
- `buy,skip_chase_skip` (page 2 standard price after page 1 was bought)
- `skip_chase_skip,buy` (page 2 standard price after page 1 was fully skipped)

Compare the page-2 standard price across these two paths. If different → conditional pricing exists. If same → confirmed path-independent.

**Show the test plan to the user as a numbered list with estimated total time** (each run is ~5 min wall time in headed mode; window will be busy). Ask "ОК поехали или что-то добавить/убрать?". Wait for confirmation. If user says go, proceed to Step 5.

---

## Step 5 — Execute

For each scenario in the plan, run via Bash:

```bash
cd ~/jobescape-auto-qa && HEADED=1 npx tsx src/index.ts \
  --version <V> --variant <var> --scenario <S> [--decisions <D>]
```

Examples:
- `--version u15.4.3 --scenario check_works --decisions buy,buy,buy`
- `--version u13.0.4 --scenario check_works --decisions skip_chase_skip,skip` (page 2 has no chase → use plain `skip`)
- `--version u15.4.3 --scenario check_already_purchased`
- `--version u15.4.3 --scenario check_decline`

Each run takes ~5 minutes. **Run them serially** (the executor opens a single Chromium window — parallel runs would conflict). Tell the user which run is in flight (`Запускаю прогон 3/6: skip_chase_buy × 3...`).

After each run, find the latest report directory:

```bash
ls -td ~/jobescape-auto-qa/reports/* | head -1
```

Read `report.json` from there to get verdict + observations + checks + capturedEvents.

---

## Step 6 — Aggregate dashboard

When all runs are done, present a chat-native dashboard:

### A. Summary table

| Сценарий | Verdict | Ключевые ивенты | Отметки |
|---|---|---|---|
| check_ui | ✅ | upsell_view | — |
| check_works buy_all | ✅ | 3× successful_purchase | цена p1=$X p2=$Y p3=$Z |
| ... | ... | ... | ... |

### B. Empirical price matrix (when prices were observed)

```
              Standard    Chase
page 1:        $X.XX     $Y.YY    (-N%)
page 2:        $X.XX     $Y.YY    (-N%)
page 3:        $X.XX     $Y.YY    (-N%)
```

If `versions.yaml` had expected prices: cross-check observed vs expected. If they differ — **flag prominently** as a real discrepancy (could be a bug or stale knowledge).

### C. Anomalies

For each unexpected event-payload field, console error, missing event, mismatched DOM/event price, unexpected page transition — list them with which run surfaced them.

Cross-reference `known-anomalies.md` — if we re-observed a known anomaly, link to its entry. If the anomaly is new, surface it AND ask the user "записать это в known-anomalies.md?"

### D. Custom assertion answers

For each user-supplied custom check (from Step 1/2), give a yes/no/ambiguous answer with evidence.

### E. Bugs / failed checks

List anything that failed. For visual checks (modal not found, layout broken), open the relevant screenshot via Read tool and show inline.

### F. Open questions

If something was ambiguous (e.g. retry-button text didn't match the regex but the popup appeared), ask the user to clarify. Don't silently pass ambiguous things.

---

## Step 7 — Save discovered knowledge

If this was a new version (Case B), and prices/CTA texts/anomalies were discovered empirically:

> Сохранить эти discovered observations в `knowledge/versions.yaml` (флаг `verified: true`, дата сегодня) чтобы следующий QAer этой версии не задавал тех же вопросов?

If user agrees: edit `versions.yaml` with the empirical findings.

If new anomalies were surfaced: ask whether to add them to `known-anomalies.md`.

---

## Anti-patterns

- **Don't skip clarifying questions for new versions.** "Just run it" without expected prices means the DOM-vs-event price match check loses its discrepancy-detection power.
- **Don't auto-PASS ambiguous checks.** If the post-flow page has no DOM prices, mark it `ambiguous` not `pass`. If a Vision check returns low confidence, it's `ambiguous` not `pass`. Anti-hallucination guardrail.
- **Don't gloss over anomalies.** If `pr_webapp_upsell_view` arrives with weird payload fields (like `upsell_order=1` on what should be page 3), surface it prominently. These are real bugs.
- **Don't run scenarios that the channel doesn't support.** Skipping `check_decline` on PayPal isn't laziness — it's because the tool can't automate PayPal OAuth.
- **Don't claim a plan worked when only steps 1-3 of a 6-step plan ran.** Surface partial completion clearly.
