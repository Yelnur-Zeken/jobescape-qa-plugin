# Known anomalies — observed during automated QA runs

These are real findings the tool has surfaced. Surface them prominently in the dashboard whenever the affected version is being QAed.

## u15.4.3 — page 3 chase event has wrong `upsell_order`

**Observed:** 2026-04-30, multiple runs (`skip_chase_skip × 3`, `skip_chase_buy × 3`, `buy + skip + skip`).

**What happens:** When the user reaches page 3 and either skips-into-chase or buys-chase, the `pr_webapp_upsell_view` event for that chase view arrives with `upsell_order: 1` instead of `upsell_order: 3`. The price ($47.99) is correct, the `chase: true` flag is correct, but the order field is wrong.

**Why it matters:** Cohort analytics that group by `upsell_order` will conflate page-3 chase views with page-1 chase views. Time-on-page metrics, conversion funnels, and any pivot-by-page-number analysis will be distorted for u15.4.3.

**Severity:** Medium (data quality, not user-facing).

**Recommendation:** Surface to data team / product analytics. Worth checking other 3-page upsells (when added) to see if the bug is generalised or specific to u15.4.3.

## chat-v3/email funnel — `?paywall=paypal` falls back to Solidgate

**Observed:** 2026-04-30 via reconnaissance run.

**What happens:** Adding `?paywall=paypal` to the funnel selling page URL does not route to a PayPal payment flow. The funnel renders the same Solidgate iframe (`#solid-payment-form-iframe` with "Confirm Payment" CTA) it would have shown without any paywall flag. By contrast `?paywall=primer` correctly routes to the Primer hosted modal with its 3-iframe form.

**Why it matters:** PayPal QA via the funnel walker is currently impossible — anyone setting `--paywall paypal` thinks they are testing PayPal but is actually testing Solidgate again. Manual QAers may have the same confusion.

**Severity:** Medium (test coverage / data integrity).

**Recommendation:** Investigate how PayPal A/B routing is supposed to be triggered on the chat-v3 funnel (UTM? cookie? specific URL? paypal-only versions like u15.1.x that force the channel?). Once the right entry is identified, update `register.ts` to use it for `--paywall paypal`.

## (Add new anomalies below as the tool surfaces them.)
