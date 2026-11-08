
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
