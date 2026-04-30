# Known anomalies — observed during automated QA runs

These are real findings the tool has surfaced. Surface them prominently in the dashboard whenever the affected version is being QAed.

## u15.4.3 — page 3 chase event has wrong `upsell_order`

**Observed:** 2026-04-30, multiple runs (`skip_chase_skip × 3`, `skip_chase_buy × 3`, `buy + skip + skip`).

**What happens:** When the user reaches page 3 and either skips-into-chase or buys-chase, the `pr_webapp_upsell_view` event for that chase view arrives with `upsell_order: 1` instead of `upsell_order: 3`. The price ($47.99) is correct, the `chase: true` flag is correct, but the order field is wrong.

**Why it matters:** Cohort analytics that group by `upsell_order` will conflate page-3 chase views with page-1 chase views. Time-on-page metrics, conversion funnels, and any pivot-by-page-number analysis will be distorted for u15.4.3.

**Severity:** Medium (data quality, not user-facing).

**Recommendation:** Surface to data team / product analytics. Worth checking other 3-page upsells (when added) to see if the bug is generalised or specific to u15.4.3.

## RESOLVED — PayPal channel was misunderstood, not broken

**Final understanding (Yelnur clarification 2026-04-30):** No URL flag is required to test PayPal-channel upsells. The upsell version itself (u15.1.x) is server-side designated for PayPal cohort and renders the **double_confirmation** mechanic in its own UI. To QA: walk the funnel normally via Solidgate (4242 card), register, then navigate to `?upsell_version=u15.1.x`. The first Confirm Payment click fires `pr_webapp_upsell_payment_intent_click` + opens a popup; the second Confirm Payment click in the popup fires `purchase_click` + `successful_purchase`.

For decline on a PayPal-channel upsell: same as any other version — append `&paywall=solidgate` to the upsell URL and use the 4123 decline card in the funnel. PayPal-ness lives entirely in the upsell page UI; decline routing is processor-agnostic.

The executor's `--paywall paypal` flag is now functionally an alias for `--paywall solidgate` at the funnel step (kept for declarative clarity in QA reports). Verified end-to-end on u15.1.3 2026-04-30.

(Original investigation kept below for context.)

---

## chat-v3/email funnel — `?paywall=paypal` falls back to Solidgate

**Observed:** 2026-04-30. Three runs verified, all the same outcome:

1. `?paywall=paypal` set at funnel entry (the email URL) → after walking to selling page + GET MY PLAN, Solidgate iframe shows.
2. Funnel walked normally without paywall flag, then on selling page navigated to the same URL with `&paywall=paypal` appended (per Yelnur's explicit instructions: "вставляем в конце selling page URL") → after GET MY PLAN, Solidgate iframe still shows.
3. Same as #2 but selecting the 1-week plan tile first (in case PayPal is tied to 1-week subs that PayPal-only versions like u15.1.2 use) → Solidgate iframe still shows.

In all three: the visible payment form is `iframe[name="solid-payment-form-iframe"]` (Solidgate), with title "Complete checkout" and CTA "Confirm Payment". No PayPal button, no PayPal sandbox login, no PayPal-style flow appears. By contrast `?paywall=primer` does correctly route to the Primer hosted modal with its 3-iframe form on the same funnel.

**Why it matters:** Automated QA cannot exercise the actual PayPal payment flow today — both the executor and any manual QAer setting `?paywall=paypal` will end up testing Solidgate. PayPal-only versions (u15.1.1, u15.1.2, u13.0.1, u15.3.1) cannot have their purchase scenarios validated until the correct PayPal-trigger mechanism is identified.

**Severity:** Medium (test coverage gap).

**Recommendation:** Ask the funnel team how PayPal A/B routing is configured on stage — is it UTM-driven, account-segment-driven, geo-IP-driven, or only enabled on a different funnel entry URL? Until then the executor's `--paywall paypal` flag is a no-op (logs the intent but actually runs Solidgate).

**Alternative hypothesis worth testing next:** maybe PayPal-only **upsell** versions (e.g. u15.1.2) trigger their own PayPal flow at the upsell page step regardless of how the funnel was paid — i.e. PayPal is upsell-side, not funnel-side, on this codebase. Test by paying funnel via Solidgate (4242), then visiting `/additional_offer?upsell_version=u15.1.2`, click buy, see whether PayPal appears.

## RESOLVED — `u1.1.3_claude` Confirm Payment "broken" was scroll_gated_one_click mechanic, not a bug

**Initial finding (2026-04-30):** Buy button on `u1.1.3_claude` page 1 appeared completely non-functional in 4 independent runs — click registered but no purchase events fired and no double_confirmation popup opened.

**Resolution:** This version uses the **`scroll_gated_one_click`** mechanic (the PayPal pattern documented in `channels.yaml`). The buy button only acts as one_click AFTER the user has scrolled past the price element. Pre-scroll, the click is consumed as a "scroll-to-price" gesture (no events). The executor wasn't satisfying the gate because `clickBuyButton` clicks without scrolling first.

**Fix applied:** Added `scroll_gated_one_click` to `PurchaseMechanic` union; `doBuy` and `runCheckAlreadyPurchasedScenario` now call `scrollPriceIntoView` before clicking buy on versions with this mechanic. Re-runs (buy,buy / skip_chase_buy,skip_chase_buy / buy,skip_chase_skip / check_already_purchased) all PASS empirically.

**Lesson for future PayPal upsells:** Don't assume `double_confirmation`. If a PayPal upsell has no popup after the first click, the mechanic is most likely `scroll_gated_one_click`. The fastest distinguishing test: scroll the page programmatically before clicking — if a single click then fires purchase events, it's scroll-gated.

## (Add new anomalies below as the tool surfaces them.)
