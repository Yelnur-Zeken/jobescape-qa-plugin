# Known anomalies — observed during automated QA runs

These are real findings the tool has surfaced. Surface them prominently in the dashboard whenever the affected version is being QAed.

## u15.4.3 — page 3 chase event has wrong `upsell_order`

**Observed:** 2026-04-30, multiple runs (`skip_chase_skip × 3`, `skip_chase_buy × 3`, `buy + skip + skip`).

**What happens:** When the user reaches page 3 and either skips-into-chase or buys-chase, the `pr_webapp_upsell_view` event for that chase view arrives with `upsell_order: 1` instead of `upsell_order: 3`. The price ($47.99) is correct, the `chase: true` flag is correct, but the order field is wrong.

**Why it matters:** Cohort analytics that group by `upsell_order` will conflate page-3 chase views with page-1 chase views. Time-on-page metrics, conversion funnels, and any pivot-by-page-number analysis will be distorted for u15.4.3.

**Severity:** Medium (data quality, not user-facing).

**Recommendation:** Surface to data team / product analytics. Worth checking other 3-page upsells (when added) to see if the bug is generalised or specific to u15.4.3.

## (Add new anomalies below as the tool surfaces them.)
