# Premium sandbox QA — StoreKit sandbox against the live App Store Connect products

Store-side twin of `m9-manual-qa.md`: that file verifies the paywall and entitlement
UI inside the app; this one verifies the real purchase pipeline — App Store Connect
products → StoreKit sandbox → RevenueCat → `PremiumRepository`. Run it on a **physical
device** (sandbox works on simulator since iOS 17, but Ask to Buy / interrupted flows
and the Sandbox Account settings pane behave properly only on device).

Tick a box only after observing the described behaviour, not before.

## §0. Prerequisites (one-time)

> **⚠️ PRODUCT ID MISMATCH — RESOLVE BEFORE RUNNING THIS.** The IDs below and the ones in
> `docs/revenuecat-ios-setup.md` disagree. This file says `com.alicansekban.salus.monthly` /
> `.six_month` / `.annual` in a group named `Premium_Plan`; the setup guide says
> `com.alicansekban.salus.premium.monthly` / `.premium.sixmonth` / `.premium.annual` in a group
> named "Premium". **Neither doc is authoritative: App Store Connect is.** A product ID cannot be
> changed once created, so whatever the dashboard already holds wins. Nothing in the Swift sources
> depends on the answer — `RevenueCatPurchasesGateway` reads `Purchases.shared.offerings()` and
> never names a product ID — so this is a documentation fix, not a code change. Read the three
> product IDs and the group name off App Store Connect → Monetization → Subscriptions, then
> correct whichever of the two files is wrong. Do not guess, and do not create a second set of
> products to make a doc true.


- [ ] Paid Applications Agreement is **Active** (App Store Connect → Business)
- [ ] All three subscriptions show **Ready to Submit**: `com.alicansekban.salus.monthly`,
      `com.alicansekban.salus.six_month`, `com.alicansekban.salus.annual`
- [ ] All three are on **Level 1** of the `Premium_Plan` group (duration switches must be
      crossgrades, not upgrades/downgrades)
- [ ] RevenueCat dashboard shows the three products without a "Missing Metadata" warning,
      and the current offering contains all three packages
- [ ] A sandbox tester exists (App Store Connect → Users and Access → Sandbox Testers) —
      never use a real Apple ID
- [ ] On the device: Settings → App Store → Sandbox Account → signed in with the tester

## §1. Product loading

- [ ] Fresh install, open the paywall → all three plans render with **localized sandbox
      prices** (a plan missing here = that product's metadata or the offering is wrong)
- [ ] Prices and durations match what App Store Connect shows (1 month / 6 months / 1 year)
- [ ] Airplane mode → paywall shows its error/empty state, no crash; back online → recovers

## §2. Purchase — once per plan

Repeat for monthly, six_month, annual (use "Manage → clear purchase history" in the
device's Sandbox Account pane, or a fresh tester, between plans if needed):

- [ ] Purchase completes with the sandbox payment sheet (marked *[Environment: Sandbox]*)
- [ ] Entitlement unlocks immediately — premium features open without app restart
      (the M9 §3 lifecycle, now against a real receipt)
- [ ] RevenueCat dashboard shows the purchase on the customer within ~1 min
- [ ] Cancelling the payment sheet mid-purchase leaves the app in the free state, no error
      dialog stuck on screen

## §3. Restore

- [ ] Delete the app while subscribed → reinstall → Restore Purchases → premium unlocks
      without a new charge
- [ ] Restore while owning nothing (expired/cleared tester) → clear "nothing to restore"
      outcome, app stays free, no crash

## §4. Plan change (the Level-1 crossgrade behaviour)

- [ ] While on monthly, buy annual from the paywall → sheet says the change takes effect
      at the **next renewal** (same-level, different-duration crossgrade — not immediate)
- [ ] Entitlement stays premium throughout; no double charge in the RevenueCat customer view

## §5. Expiry (sandbox time is accelerated)

Sandbox renewal clock: 1 month ≈ 5 min · 6 months ≈ 30 min · 1 year ≈ 1 hour; a
subscription auto-renews up to ~6 times, then lapses (~30 min total for monthly).

- [ ] Buy monthly, wait for the auto-renew cycle to lapse → entitlement drops, app
      returns to the free state on next foreground (no restart needed)
- [ ] Re-purchase after expiry works

## §6. Release checklist (after §1–§5 pass)

- [ ] First subscriptions **cannot** be submitted standalone ("add an app version" error is
      expected): create the new app version, attach the build, and the Draft Submission's
      subscriptions ride along in the same review submission
- [ ] Verify the version's submission page lists all three subscriptions before submitting
- [ ] App Review will exercise the paywall — the review screenshots and notes should match
      what the reviewer will actually see
