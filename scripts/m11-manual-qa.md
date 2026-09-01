# iOS-M11 Manual QA Matrix

Run each step on the simulator after `scripts/build-app.sh` succeeds.
Tick a box only after observing the described behaviour, not before.

## 1. Free user — locked preview

- [ ] Open Trends from Vitals "Analiz" icon → screen opens, sample data visible behind blur
- [ ] Open Trends from More "Trendler" row → same screen
- [ ] Sample data is blurred (`.blur(radius: 16)`) and a scrim covers it
- [ ] Lock icon + "Premium ile aç" button visible on top
- [ ] Tapping the blurred cards does nothing (hit-testing disabled)
- [ ] Tapping "Premium ile aç" opens the paywall sheet
- [ ] Dismissing paywall returns to the locked Trends screen

## 2. Premium user — four cards

- [ ] After premium unlock, Trends screen reloads automatically (no manual pull)
- [ ] Time-of-day card renders (if BP or glucose data exists)
- [ ] Multi-metric overlay card renders (if ≥2 metrics have data)
- [ ] Dose weeks card renders (if any dose logs exist)
- [ ] Metric summary card renders (if any measurements exist)
- [ ] Each card shows real data, not sample data

## 3. Period switch

- [ ] Default range is Quarter (90 days)
- [ ] Switching to Month / Half-Year / Year reloads the data
- [ ] Re-selecting the same range does not reload (guard)

## 4. Card hiding

- [ ] Time-of-day card hidden when no BP and no glucose measurements
- [ ] Overlay card hidden when fewer than 2 metrics have data
- [ ] Dose weeks card hidden when no dose logs exist
- [ ] Summary card shows only metrics with readings

## 5. Banned vocabulary

- [ ] No "uyum", "adherence", "planlanan doz", "hedef aralık" anywhere on screen
- [ ] Dose card text uses "kaydedilen doz" / "recorded doses" semantics
- [ ] No value is labelled good/bad/normal — only numbers, averages, and change direction

## 6. Entry points

- [ ] Vitals tab → "Analiz" icon navigates to Trends
- [ ] More tab → "Trendler" row navigates to Trends
- [ ] Back button returns to the originating tab

## 7. Paywall feature list

- [ ] Paywall shows exactly 4 features (AI summary, doctor report, trends, themes)
- [ ] `backup` is not in the list
- [ ] Trends copy reads: "Sabah-akşam dağılımı, çoklu metrik ve doz-ölçüm analizi" (TR)
- [ ] Trends copy reads: "Time-of-day breakdown, multi-metric overlay and dose-vs-measurement analysis" (EN)

## 8. Existing free features unchanged

- [ ] Vitals chart range chips (Week/Month/Quarter/Year) still work and are free
- [ ] Vitals chart is unchanged — no visual regression