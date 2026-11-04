# UI review – task list (branch `feat/ui-redesign`)

Source: designer review D1–D15 of the redesigned UI. All paths are relative to the repo root `F:\WORKING\Flutter\di-dau`.
Line numbers are from the review and are approximate; locate by the quoted code if they have shifted.
All user-facing copy stays in Vietnamese.

## Scope decisions

| Finding | Decision | Task(s) / reason |
|---|---|---|
| D1 | Accepted | UI-01 |
| D2 | Accepted (as a capture fix, not a UI rewrite) | UI-02 |
| D3 | Accepted | UI-06 |
| D4 | Accepted | UI-03 |
| D5 | Accepted | UI-04 |
| D6 | Accepted | UI-05 |
| D7 | Accepted | UI-07 |
| D8 | Accepted (scoped down: swipe and SnackBar already exist; only undo is missing) | UI-08 |
| D9 | Accepted, partly | UI-09 (Pill row plus attribution footer). A hero image/map "anchor" is deferred: there is no image data in the API yet, so it needs backend or design work |
| D10 | Accepted | UI-10 |
| D11 | Accepted | UI-11 |
| D12 | Accepted | UI-12 |
| D13 | Accepted | UI-13 |
| D14 | Accepted | UI-14 |
| D15 | Accepted | UI-15 |

Accepted: 15 tasks (UI-01..UI-15). Deferred: 1 sub-item (the D9 visual anchor image/map, see the reason above).

---

## P1: Critical (layout breakage, contrast)

- [x] **UI-01** (D1). ChoiceTile grid overflows at 320px width or text scale > 1
  - Files: `app/lib/features/suggestions/suggestions_screen.dart`, `app/lib/widgets/ui.dart` (ChoiceTile)
  - Change:
    - Replace `GridView(crossAxisCount: 4, childAspectRatio: .92)` with a `LayoutBuilder`: use `crossAxisCount: constraints.maxWidth < 340 ? 2 : 4` and a `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: 96, ...)` instead of `childAspectRatio`. Keep `shrinkWrap: true` and `NeverScrollableScrollPhysics`.
    - ChoiceTile: when `caption == null`, use `padding: EdgeInsets.all(12)`. Give the label `maxLines: 1` and wrap it in `FittedBox(fit: BoxFit.scaleDown)`. Give the caption (if any) `maxLines: 1, overflow: TextOverflow.ellipsis`.
  - Acceptance: at 320×640 and 375×812, with `MediaQuery` textScaler 1.0 and 1.3, there are no "RenderFlex overflowed" errors and no yellow/black stripes. Check with a widget test that pumps SuggestionsScreen at 320px with `textScaler: TextScaler.linear(1.3)` and asserts `tester.takeException()` is null. At ≥ 340px the grid still shows 4 columns.

- [x] **UI-02** (D2). `tour-mobile.png` shows an inset/scaled tour screen with the tab bar bleeding through (capture artifact)
  - Files: `scripts/browser-smoke.cjs`, and only if needed `app/lib/features/tours/tour_screen.dart`
  - Change:
    - In the smoke script, after the click that opens the tour route and after the target button/text appears, add `await page.waitForTimeout(600);` (route transition settle) before `page.screenshot(...)`. Do the same for every screenshot taken right after a `Navigator.push`.
    - Confirm the route is opaque: TourScreen is pushed with a `MaterialPageRoute` (default `opaque: true`) and its `Scaffold` has a non-transparent `backgroundColor` (AppColors.paper). Change code only if one of these is false.
  - Acceptance: a re-run of `node scripts/browser-smoke.cjs` produces a `tour-mobile.png` that is full-bleed, with no scaling inset and no tab bar visible behind it. No UI layout rewrite.

- [x] **UI-03** (D4). `AppColors.faint` (#8a948f) is about 2.8:1 on paper
  - Files: `app/lib/theme/` (the AppColors file), plus usages found by `grep -rn "AppColors.faint" app/lib`
  - Change: set `faint = Color(0xFF6B756F)` (≥ 4.5:1 on paper). Add `faintDecor = Color(0xFF8A948F)` and switch it in only where faint colors purely decorative icons or dividers (never text).
  - Acceptance: no `Text`/`TextStyle` uses `faintDecor`. Every text color using `faint` is ≥ 4.5:1 against `AppColors.paper` (check with a contrast tool).

- [x] **UI-04** (D5). Terracotta #d0633f used as a text color or as a background under white text (about 3.4–3.8:1)
  - Files: `app/lib/theme/` (AppColors), `app/lib/features/suggestions/suggestions_screen.dart` (~L188 rank badge), `app/lib/features/tours/tour_screen.dart` (~L212 stop markers, ~L287 link), `app/lib/widgets/ui.dart` (~L19 eyebrow)
  - Change: add `terracottaInk = Color(0xFFA8472A)`. Use it for the rank badge background, the stop marker background, the eyebrow text color and the link text color. Keep `terracotta` for icons and fills that carry no text.
  - Acceptance: each listed element is ≥ 4.5:1 (white on terracottaInk, terracottaInk on paper). `grep` shows no text style using `AppColors.terracotta` (only `terracottaInk`).

- [x] **UI-05** (D6). City eyebrow on the tour header uses `AppColors.sun` on lagoon (about 3.5:1)
  - Files: `app/lib/features/tours/tour_screen.dart` (~L159), and `app/lib/theme/` if a token is added
  - Change: use `Color(0xFFFFD27A)` (add it as `AppColors.sunLight`) for the city eyebrow text.
  - Acceptance: eyebrow-on-lagoon contrast ≥ 4.5:1. Visually checked in `tour-mobile.png`.

## P2: Major UX

- [x] **UI-06** (D3). The "Xuất phát từ chỗ tôi" switch is hidden under BottomAction
  - Files: `app/lib/features/tours/tour_form_screen.dart` (~L247-263)
  - Change: put the switch in its own section, preceded by `StepLabel(4, 'Điểm xuất phát (tuỳ chọn)')` (match the existing StepLabel signature), with the switch label "Xuất phát từ chỗ tôi". Set the ListView padding bottom to `≥ 96` (BottomAction height of about 80 plus spacing), e.g. `AppSpace.page.copyWith(bottom: 96)`.
  - Acceptance: at 375×667, after scrolling to the end, the switch is fully visible above the BottomAction and can be tapped. Step numbering reads 1→4 in order.

- [x] **UI-07** (D7). SaveButton: the tooltip stays on screen in screenshots, and the saved state is unclear
  - Files: `app/lib/features/saved/save_button.dart`
  - Change:
    - Compact variant: `IconButton(isSelected: saved, icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), color: AppColors.lagoon, ...)`. Remove the `colorScheme.secondary` (terracotta) tint. Keep `tooltip` for a11y, but in the smoke script hover away/press `Escape` before screenshots (see UI-02) instead of removing it.
    - After a successful toggle, show `SnackBar(content: Text(saved ? 'Đã lưu' : 'Đã bỏ lưu'), action: SnackBarAction(label: 'Hoàn tác', onPressed: <toggle back>))`. Call `ScaffoldMessenger.hideCurrentSnackBar()` first.
    - Full variant: same lagoon icon colors. Label stays 'Đã lưu' / 'Lưu'.
  - Acceptance: saved and unsaved states differ by icon shape (filled vs outline), not only by color. Undo restores the previous state. `app/test/widget_test.dart` still finds 'Đã lưu' exactly once (the SnackBar only appears after a tap, so the test must not tap save). If a test does tap, scope its finder.

- [x] **UI-08** (D8). Removing an item from Saved has no undo
  - Files: `app/lib/features/saved/saved_screen.dart`
  - Note: swipe-to-delete (`Dismissible`, endToStart, L140-160) and a confirmation SnackBar (`confirmRemove`, L96-104) **already exist**. Both swipe and the inline `Bỏ lưu` IconButton (L218-222) call `confirmRemove`, which removes immediately with no undo. Do not add another delete mechanism.
  - Change: in `confirmRemove`, keep a copy of the removed `SavedItem`, then show `SnackBar(duration: Duration(seconds: 5), content: Text('Đã bỏ lưu “…”.'), action: SnackBarAction(label: 'Hoàn tác', onPressed: () async { await store.save(item.kind, <raw id: item.id without the "${item.kind}:" prefix>, item.title, item.snapshot); await load(); }))`. Call `hideCurrentSnackBar()` before showing.
  - Acceptance: removing via swipe and via the icon both show the SnackBar for about 5s. Tapping "Hoàn tác" brings the item back in the same group, and it persists after a pull-to-refresh.

- [x] **UI-09** (D9). Place detail has no anchor; source links are scattered
  - Files: `app/lib/features/suggestions/place_detail_screen.dart`, `app/lib/widgets/source_attribution.dart`
  - Change: under the title, add a `Wrap(spacing: 8, runSpacing: 8)` of `Pill`s (from `ui.dart`): category, distance (e.g. "1,2 km"), and open state ("Đang mở cửa" / "Đã đóng cửa", only when data exists). Move the "Xem nguồn dữ liệu" link next to `SourceAttribution` as one footer block at the end of the ListView.
  - Acceptance: pills render when fields are present and are omitted (no empty pill) when null. The source link and attribution appear together, last on the page. No overflow at 320px.

## P3: Minor / copy / a11y

- [x] **UI-10** (D10). The location summary label "Gần" is unclear
  - Files: `app/lib/features/suggestions/location_picker.dart`
  - Change: label "Gần" → "Vị trí của bạn". Make the whole summary card tappable (`InkWell` over the card, `ConstrainedBox(minHeight: 64)`). Wrap it in `Semantics(button: true, label: 'Đổi vị trí')`.
  - Acceptance: tapping anywhere on the card opens the picker. The card is ≥ 64px tall. The semantics tree has a button 'Đổi vị trí'. Update the smoke selectors if they reference "Gần".

- [x] **UI-11** (D11). The disabled CTA label is used as an instruction, at low contrast
  - Files: `app/lib/features/tours/tour_form_screen.dart` (~L283-287)
  - Change: the button label is always "Tạo lộ trình". When the form is invalid, show the hint (the current instruction text) as `Text(..., style: textTheme.bodySmall)` above the button inside BottomAction, colored `AppColors.muted`/ink (≥ 4.5:1).
  - Acceptance: the button text never changes with validity. The hint is visible only when invalid and meets ≥ 4.5:1. Update the smoke/integration selectors that matched the old disabled label.

- [x] **UI-12** (D12). ChoiceTile semantics for multi-select
  - Files: `app/lib/widgets/ui.dart` (ChoiceTile), `app/lib/features/suggestions/suggestions_screen.dart` (interests)
  - Change: wrap ChoiceTile in `Semantics(button: true, toggled: multi ? selected : null, selected: !multi ? selected : null, excludeSemantics: true, label: selected ? '$label, đã chọn' : label)` (add a `multiSelect` flag, true for interests).
  - Acceptance: a widget test with `tester.getSemantics(find.byType(ChoiceTile).first)` shows the label "Lịch sử, đã chọn" and the toggled flag when "Lịch sử" is selected.

- [x] **UI-13** (D13). City ChoiceChips are about 40px tall and show selection by color only
  - Files: `app/lib/features/suggestions/suggestions_screen.dart` (and `tour_form_screen.dart` if it has the same chips)
  - Change: `ChoiceChip(showCheckmark: true, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), materialTapTargetSize: MaterialTapTargetSize.padded, ...)`.
  - Acceptance: chip hit target ≥ 48px. The selected chip shows a checkmark.

- [x] **UI-14** (D14). Duration caption sits outside the tour header
  - Files: `app/lib/features/tours/tour_screen.dart`
  - Change: move "Thời gian gồm tham quan và di chuyển ước tính." inside the header card, directly under the time stat, as `bodySmall` (use a readable color on lagoon, ≥ 4.5:1). Remove the old standalone Text.
  - Acceptance: the text appears exactly once, inside the header card.

- [x] **UI-15** (D15). Copy fixes
  - Files: `app/lib/features/suggestions/suggestions_screen.dart`, `app/lib/features/tours/tour_screen.dart`, `app/lib/features/tours/tour_form_screen.dart` (locate with `grep -rn` for each string across `app/lib`)
  - Change:
    - "Ăn uống" → "Quán ăn"
    - "Gợi ý phương án khác" → "Đổi lộ trình khác"
    - busy text "tối đa ~20 giây…" → "có thể mất khoảng 20 giây"
    - remove every literal "→" inside a `Text(...)` string (use an `Icon(Icons.arrow_forward)` in a Row if direction must be shown, or drop it). Check with `grep -rn "→" app/lib`.
  - Acceptance: `grep -rn "Ăn uống\|Gợi ý phương án khác\|tối đa ~20\|→" app/lib` returns nothing user-facing. Selectors updated (see DoD).

---

## Definition of done

- [x] `flutter analyze` is clean (no errors, warnings or infos) — run from `app/` with the SDK at `C:\Users\PC\Development\flutter\bin` (e.g. `C:\Users\PC\Development\flutter\bin\flutter analyze`).
- [x] `flutter test` passes, including the new widget tests from UI-01 and UI-12. `app/test/widget_test.dart` still finds `'Đi Đâu'`, `'Tour'` and `'Đã lưu'` **exactly once** each. Make sure new copy (e.g. the UI-07 SnackBar 'Đã lưu') does not add a duplicate on the initial screen.
- [x] Web build succeeds:
  `cd app && flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define=API_BASE_URL=http://localhost:5000/api`
- [x] `node scripts/browser-smoke.cjs` reports PASS, and the fresh screenshots (especially `tour-mobile.png`) have been reviewed.
- [x] Smoke/integration selectors are updated wherever visible text or tooltips changed (UI-07 tooltips/icons, UI-10 "Gần", UI-11 CTA label, UI-15 copy):
  - `scripts/browser-smoke.cjs`
  - `app/integration_test/android_smoke_test.dart`
  - `app/test/widget_test.dart`
- [x] Every new color pair used for text is ≥ 4.5:1 (UI-03, UI-04, UI-05, UI-11, UI-14).
- [x] No files changed outside those listed in the tasks.

## PM sign-off — 2026-11-04

- Designer round 2: **APPROVE** — UI-01..UI-15 all pass, no critical/major regressions.
- Round-2 minor follow-ups fixed before merge: place pills use `lagoonSoft` background; StepLabel hint is `Flexible` + ellipsis (no squeeze at 320px); tour busy text uses `muted`; logo tile uses `terracottaInk`.
- Checks: `flutter analyze` clean · `flutter test` 16/16 · web build OK · `scripts/browser-smoke.cjs` PASS (fixture API) · backend `dotnet test` 61/61.
- Not verified: Android integration test (no emulator in this run), live Goong/OSM data, dark mode, tablet widths.
- Deferred: image/map anchor on place detail (D9 remainder) — needs image data from the API.
