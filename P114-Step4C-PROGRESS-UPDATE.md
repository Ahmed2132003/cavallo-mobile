### P-114 - STEP 4C (goldens + closing notes) - PASTE THIS AT THE END OF PROJECT_PROGRESS.md

Status: P-114 code is DONE through STEP 4C. P-114 is NOT yet marked COMPLETE: the manual
four-combination walk-through (below) has not been recorded. Mark COMPLETE only after it.

What STEP 4C added (tests only, nothing under lib\ changed)
- New: test\goldens\p114_goldens_test.dart. 6 subjects x 4 combinations (English LTR / Arabic RTL
  x Light / Dark): post card, reel card, story ring (unseen and seen), business profile header,
  search result card (Featured + organic rows in one list), product detail header.
  = 28 PNG files under test\goldens\p114\ (named <subject>_<en|ar>_<light|dark>.png).
- Regenerate after an intended visual change: flutter test --update-goldens test\goldens
  (review the PNGs, then commit them). Plain flutter test test\goldens compares to the commit.
- Goldens use no network, no timestamp (relative time would change daily) and fakes only.

Where the other P-114 test requirements live (already green before 4C)
- Story viewer tap zones in LTR and RTL: test\features\stories\presentation\story_viewer_rtl_and_hold_test.dart
- Action row callbacks: test\features\social\content_action_row_p114_test.dart (+ content_action_row_test.dart)
- Follow button states: test\features\social\follow_button_test.dart
- Comments sheet: test\features\social\comments_sheet_p114_test.dart (4B)
- Product detail: test\features\products\presentation\product_detail_p114_test.dart (4A)

Existing tests changed by STEP 4A (assert removed visual details, documented)
- Loading: CircularProgressIndicator replaced by AppShimmerBox (skeleton required by the part).
- Product detail now has two AppBar IconButtons (Save + Share) instead of one; ButtonStyleButton
  counts changed accordingly (3 instead of 2 overall, 2 instead of 1 in the AppBar). The body still
  has exactly one button (Message Business).

Known issues (carry to P-115 / follow-up)
- Product Save icon starts as "not saved": the Product entity has no isSaved field, so a product that
  is already saved shows the empty bookmark until tapped. Saving is idempotent on the server, so the end
  state is correct. Fixing the initial icon needs a DTO/provider change (out of scope for P-114).
- Product detail shows no Availability: the Product entity has no availability field; nothing was invented.
- Product price is still the raw backend text (Western digits), per the P-034 rule. AppFormatters.price
  would break existing tests (it drops ".00").
- Golden images are generated on the developer's machine (Windows). If CI runs on another OS, regenerate
  there or the comparison may differ by font rasterization.
- Carried from P-113: BusinessConsoleScreen placeholder hardcoded English + "Back to splash" button
  (P-115 scope); confirm the Language selector PATCHes preferred_language on /api/v1/auth/me/ before the
  P-115 l10n sweep.

GitHub: cavallo-mobile, branch part-111: STEP 1 = 24683f2; STEP 3 = 9fbe551; STEP 3A = 766470c;
STEP 3B = 0597d87; STEP 4A = 3c74f5d; STEP 4B = 78994f2; STEP 4C = (add the hash after pushing).
(STEP 2 and its two fixes are in the history between 24683f2 and 9fbe551; check git log.)

Manual check to record (real device, 4 combinations: Light/EN, Light/AR, Dark/EN, Dark/AR)
For each combination tick: [ ] Home feed + stories tray (skeleton while loading, pull to refresh)
[ ] Story viewer (tap zones: in Arabic the reading-start side = right side goes BACK, left goes FORWARD;
    hold = pause; swipe down = close) [ ] Post card (Like, Comment sheet, Share, Save, caption "more")
[ ] Reel card [ ] Business profile (stats, Follow/Message, 4 tabs, Info) [ ] Explore (sticky search, chips,
    filter bottom sheet, Featured badge + organic results visible) [ ] Product detail (Message Business is
    the only primary action, no cart/buy anywhere, Save/Share) [ ] Comments sheet (input above keyboard)
Result: ______ (fill in; list anything that failed).

Remaining work
- Run the manual check above and record it; then mark P-114 COMPLETE.
- Exact next starting point after that: P-115 (chat, notifications, business console, moderation
  restyle + final QA sweep). Keep every navigation manifest entry and keep
  test\routing\navigation_reachability_test.dart green.
