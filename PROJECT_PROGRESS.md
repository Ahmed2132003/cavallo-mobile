
---

## Forgot-password STATE layer - branch `feature/forgot-password-state` (2026-11-08)

**Scope:** data + state + routing + l10n for the forgot-password flow. **The three screens are still PLACEHOLDERS** (Scaffold + localized text, no form, no buttons); the real screens are the next step.

**Backend contract verified in cavallo-app (develop), and where it differs from the brief:**
- `password-reset/request/` answers **202** (not 200) with `{detail}`; same body for every well-formed email.
- `verify/` -> `200 {reset_token}`; every failure is the unified `400` with code `ERROR` (not a dedicated code) and empty `fields`.
- `confirm/` -> `200 {detail: "Password has been reset."}`; a weak password is `400 VALIDATION_ERROR` with `fields.new_password` ONLY (there is no `password` field); a wrong/expired token is the unified `400`.
- 429 = `THROTTLED` with a `Retry-After` header (whole seconds). TTLs 300 s, OTP locks after 5 tries, OTP is exactly 6 ASCII digits.

**What was added:**
- Data: 4 DTOs (request/verify request, verify response, confirm request) and 3 `AuthRepository` methods (named params, like the rest of the file). They never touch `SecureTokenStorage` or the session.
- 429: stays an `UnknownFailure` with code `THROTTLED` (pinned by `error_interceptor_code_test`; a new sealed subtype would break every exhaustive `switch`). New: `UnknownFailure.retryAfter` parsed from `Retry-After`; a 429 without an envelope now also gets code `THROTTLED`. `localizedApiError` already mapped `THROTTLED` -> `errorThrottled`.
- State: `forgotPasswordProvider` (autoDispose `Notifier`): email -> otp -> newPassword -> done, 60 s resend cooldown (Retry-After aware), reset token in a private field only (cleared on success, dead token, backToEmail/reset, dispose).
- Routing: `/forgot-password`, `/forgot-password/verify`, `/forgot-password/new-password` in `_publicRoutes`, `RouteNames`, and the manifest (auth-flow). Signed-in users go to /home; steps 2/3 without state go back to step 1.
- L10n: 26 `authReset*` keys in EN + AR.
- Also: `LoggingInterceptor` no longer prints bodies of `/password-reset/` requests (OTP / token / password) in dev builds. Note: it still prints other bodies, including login passwords - out of scope here.

**Fixes after the first run (the 5 failures were all in this change, none pre-existing):**
- 4 tests (`error_interceptor_throttled_test`, `password_reset_repository_test`): the production 429 code was correct. `http_mock_adapter` 0.6.1 throws a `_TypeError` inside the adapter when a Map body is replied together with `headers` but without `content-type`; Dio wrapped it as `DioExceptionType.unknown` and `ErrorInterceptor` turned it into `NetworkFailure`. Fix: the mocks now send `content-type: application/json` next to `retry-after`.
- 1 test (`no_hardcoded_strings_test`): the literal in `forgot_password_provider.dart` is now `UnknownFailure.unexpected()` (developer-only text, `localizedApiError` never shows `message` and maps it to `errorUnknown`).

**Verification (REAL results of this run):**
- flutter gen-l10n: PASS
- flutter analyze: PASS (No issues found)
- flutter test (FULL): +1657 passed, 0 skipped, 0 failed (last number known before this change: +1587)
- Live smoke, request endpoint on localhost:8095 (scd-backend-web-1): HTTP 202, body `{"detail":"If the email is registered, a verification code will be sent."}`

**Not verified:** the verify/confirm endpoints were NOT exercised against the real backend (unit tests use a mocked Dio adapter shaped from the backend code). No UI exists yet, so no manual walk-through was possible.

**Known, unrelated to this change:** some existing test still issues real requests to localhost:8095 (`/posts/`, `/reels/`, `/stories/`) and gets 400. It does not fail the suite. To be tracked separately.

---

## Forgot-password SCREENS - branch `feature/forgot-password-state` (2026-11-08)

**Scope:** the three real screens (email -> code -> new password) replace the placeholders; login got a "Forgot password?" link and an optional prefilled email.

**What was added:**
- `forgot_password_screens.dart`: step 1 (email, neutral text, 429 + network retry), step 2 (6-digit code read from backend `_OTP_PATTERN`, 60 s resend cooldown, 5-minute note, unified 400 shown as "invalid or expired", back to change email), step 3 (new password + confirm, show/hide, weak-password text under the field, dead token restarts at step 1). Success: flow state wiped, snackbar, back to /login with the email filled (route `extra`, nothing stored). No automatic login.
- `AppTextField`: 4 optional params (inputFormatters, suffixIcon, textInputAction, onChanged) - backward compatible, every existing call site unchanged.
- `LoginScreen`: link between login and register (disabled while submitting; passes the typed email), optional `initialEmail`.
- L10n: 5 new keys in EN + AR (link, neutral hint, expiry note, show/hide password).
- Goldens: 12 new PNGs in `test/goldens/p116_forgot_password/`.

**Verification (REAL results of the script run):**
- flutter gen-l10n: PASS
- flutter analyze: PASS
- Targeted tests (new tests + auth + routing + l10n guards + core widgets): 00:24 +135: All tests passed!
- Goldens: generated 12, stable on 3 consecutive runs
- flutter test (FULL): 04:17 +1696: All tests passed!

**Manual end-to-end (emulator + real backend):** PASSED on 2026-11-08 - the walk-through was run on the emulator against the real backend. Status: **DONE**.


---

## PART BI-03 - Chat order creation and Orders management - branch `part-116b-edit-profile` (2026-11-19)

**Scope:** a merchant records a sale from a Product card in chat; the order appears as a card under that message for both sides; the merchant manages orders from a new Orders tab in the Business Console.

**What was added:**
- Feature `lib/features/orders/`: entities (Order, OrderNote, OrderStatusEvent/OrderEvents, OrderSummary), DTOs (merchant and customer serializers kept separate), `OrdersRepository`, providers, `OrdersListScreen`, `OrderDetailsScreen`, change-status and add-note sheets, `RecordSaleSheet`, status chips (colour + icon), money helpers in integer minor units.
- Chat: `Message.order` (nullable, old payloads parse as before), `OrderMessageCard`, "Record Sale" button (only for the business that owns the shared product, only while the message has no order).
- Idempotency: `createFromChat` is safe to repeat; the server answers a repeat with HTTP 200 and the same order. The sheet disables the button while sending and retries with the SAME source message id.
- Privacy: `internal_note` is never read in the customer parser; internal events are dropped client-side again; the chat card never renders an internal note.
- Conversation start: `startConversationWithBusiness(productId:)` sends `business_id` + `product_id`; `product_detail_screen` passes the product id. The call without a product is unchanged.
- Routing: `ordersList` (Console branch 4, appended so branches 0..3 are unchanged) and `orderDetail` (`/business-console/orders/:id`, id in the path so it survives a restart), covered by the Business-only gate; entries in `navigation_manifest.dart`.
- L10n: all strings in EN + AR.
- Tests: DTOs, money, repository contract, providers, list / details / sheets / record-sale widgets, chat button visibility and order card (merchant vs customer), conversation start with product, routing. Fixed the fake in `message_business_button_test.dart` for the new `productId` parameter.

**Verification (fill in with the REAL output of your run):**
- flutter gen-l10n: ?
- flutter analyze: ?
- Targeted tests: ?
- flutter test (FULL): ?

**Not verified:** nothing was run against the real backend. The contract is taken from `api_contract_BI01.md` only. Manual walk-through on the emulator (record a sale, retry after a dropped connection, status change seen by the customer, Arabic/RTL, Dark) is still to do.

**Remaining gaps:**
- No orders count endpoint: Overview counters are computed from at most `kOrdersMaxPages` (10) loaded pages and the list says so when truncated. Status filtering is client-side; only search is server-side.
- No "get one conversation" endpoint: "Open conversation" scans the conversation list (up to 10 pages) and shows "could not open" if not found.
- The WebSocket `MessageReceived` path in `ChatThreadScreen` builds `Message` without `order`, so a customer sees the order card under the shared product only after the thread is reloaded (or the card's own live fetch, once the message carries `order`). A real-time order event is not part of the contract.
- There is no customer "my orders" screen; the customer endpoint is used only by the chat card.
- The Console now has 5 destinations; any older widget test that counts `NavigationDestination`s in the console shell must be checked in the full run.
- Customer name in the sheet is the other participant's display name (correct only because a business is always the merchant).

## PART BI-04 - Business Analytics dashboard (overview, products, orders & sales, content, external) - branch `part-116b-edit-profile` (2026-11-20)

**Scope:** the Business Console Analytics tab becomes a five-section dashboard over one shared period, with a product detail and a post/reel detail, and manual entry of external platform numbers. Everything comes from `api_contract_BI02.md`; no endpoint or JSON outside it is used.

**Screens:**
- `AnalyticsDashboardScreen` (replaces the P-085 `AnalyticsScreen` in the router only): tabs Overview, Products, Orders & sales, Content, External, under one period bar (7 / 14 / 30 / 90 days, this month, previous month, custom). Every tab keeps its state and is cached by non auto-dispose providers, so switching tabs sends no request.
- `ProductAnalyticsDetailScreen`: totals, sales per currency, funnel, daily trends, link to the orders list.
- `ContentAnalyticsDetailScreen`: internal (in-app) block and external (platform) block kept separate, plus the manual-entry sheet.
- The older daily-rollup screen, its providers and tests (P-085) are untouched.

**Files:**
- Data: `business_analytics_repository.dart` (`BusinessAnalyticsRepository` + Impl), DTOs `dto_parsing.dart`, `analytics_common_dto.dart`, `overview_dto.dart`, `products_dto.dart`, `content_dto.dart`, `orders_summary_dto.dart`.
- Domain: `analytics_period.dart`, `analytics_common.dart`, `analytics_overview.dart`, `analytics_products.dart`, `analytics_content.dart`, `analytics_orders_summary.dart`.
- Presentation: `analytics_dashboard_screen.dart`, `product_analytics_detail_screen.dart`, `content_analytics_detail_screen.dart`, `presentation/providers/`, `presentation/widgets/` (common, overview, orders, products, content, external).
- Routing: `businessAnalyticsProduct` (`/business-console/analytics/product/:id`) and `businessAnalyticsContent` (`/business-console/analytics/content/:type/:id`), children of the analytics tab under the Business-only gate; `route_names.dart`, `app_router.dart`, `navigation_manifest.dart`.
- `lib/features/analytics_tracking/` is part of this change set (added in parts 1-4). TODO: complete this line from its docstrings; it was not part of the material this entry was written from.
- L10n: 163 keys in EN + AR (`analyticsContent*`, `analyticsExternal*`, `analyticsProd*`, `bi*`).

**APIs used (all under `/api/v1/analytics/business/{id}/`, Bearer):** `overview/`, `products/`, `products/{product_id}/`, `content/`, `content/{type}/{id}/`, `content/{type}/{id}/external-metrics/` (GET and POST), `orders-summary/`. `business_id` is never sent in a query or body.

**Rules implemented:**
- Period: the app ALWAYS sends `date_from` + `date_to` (the server accepts `period=` only for 7d / 30d / 90d). Rolling presets end YESTERDAY in UTC (today has no rollup yet); "today" is the UTC date of the injected clock, never the device date (Cairo is UTC+2/+3). Custom ranges use the picked year/month/day as UTC dates. Maximum 366 days; `from > to` is rejected before any request. `orders-summary` defaults `date_to` to the server's today, so it is always sent.
- Missing data is null and shown as a dash, never 0; real counts (orders, interests) keep their 0.
- Money is a String; sales are listed per currency and never summed.
- The funnel is shown exactly as the backend returned it; nothing is recomputed on the client.
- Comparison: only the backend's `change_pct` is read. A null `previous_period`, a metric without a delta (sales, AOV) and a null `change_pct` all show "No previous data".
- No "live" label: the screens show `data_updated_at` and `orders_data_updated_at`; views unavailable / incomplete are explained.
- Lists are page based (`page`, `page_size` max 100, `ordering`). "Lowest conversion" is `ordering=conversion` (ascending); there is no separate key.
- Sales Value = confirmed + processing + shipped + delivered; pending and cancelled are not counted; these are merchant-recorded sales, not collected payments.

**External integration constraints:**
- No sync integration exists (`providers_registered` is `[]`): every external number is manual. Anything that is not explicitly `source: synced` is labelled Manual, never live.
- Platforms: instagram, facebook, tiktok. Metric types: views, likes, shares, saves. There is NO "engagement" external type, and "reach" does not exist (no reliable source), so it is not shown.
- POST body: `platform`, `metric_type`, `metric_value` (int >= 0), optional `captured_at` (not in the future) and `external_reference`. `source` can never be sent. The POST is NOT idempotent, so the app does not auto-retry it.
- Internal and external numbers are never added together; in-app shares do not prove any external view.

**Tests (new):** `test/features/business_console/`: `bi_fixtures.dart`, `fake_business_analytics_repository.dart`, `data/business_analytics_dtos_test.dart` (parsing, null vs 0, funnel as sent, money, UTC timestamps, ordering keys), `data/business_analytics_repository_test.dart` (paths, exact query params, ordering, pagination, error mapping), `domain/analytics_period_test.dart` (every preset, UTC / Cairo edge, month boundaries, 366 limit), `domain/metric_comparison_test.dart`, `presentation/bi_test_harness.dart`, `presentation/analytics_dashboard_screen_test.dart` (loading / error / empty, dash for null, no reload on tab change, shared period, sorting, pagination, AR / EN, Light / Dark), `presentation/product_analytics_detail_screen_test.dart`, `presentation/content_analytics_detail_screen_test.dart`, `presentation/analytics_navigation_test.dart`; `test/routing/analytics_routes_test.dart`. No old test was removed. `arb_parity_test` and `no_hardcoded_strings_test` must keep passing.

**Verification (fill in with the REAL output of your run):**
- flutter gen-l10n: ?
- flutter analyze: ?
- Targeted tests (test/features/business_console, test/l10n, test/routing): ?
- flutter test (FULL): ?

**Not verified:** nothing was run against the real backend; the contract is taken from `api_contract_BI02.md` only. The widget tests were written without the full presentation sources and assume: the period chips change the shared period, "Load more" is visible while `hasMore`, ordering and type filters are visible chips, a null number renders as `—`, a missing business shows `biNoBusiness`, a product row or content card opens its detail by route name, and "Open orders" goes to `ordersList`. Manual walk-through on the emulator (Arabic / RTL, Dark, a custom range, use between 00:00 and 02:00 in Cairo, manual external entry) is still to do.

**Remaining gaps:**
- The products list row has no image, no price, no conversations count and no separate confirmed / completed counts (contract gaps); image and name come from the products feature by `product_id`. The content list has no thumbnail and no external numbers.
- No per-product orders filter exists (marked UNVERIFIED in `api_contract_BI01.md`), so "Open orders" opens all orders and says so.
- The external-entry form submit is covered only at repository level; its widget flow is not tested.
- The real `app_router.dart` registration and the Business-only gate for the new routes are not covered by a router-level test; `analytics_routes_test.dart` checks the constants and an equivalent route table.
- No provider-level unit tests (the provider sources were not available when the tests were written).
- Rollups are computed by Celery: days not yet rolled up are null, so very recent days can show a dash.