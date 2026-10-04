# Store Listing Checklist (Part P-107)

Prepared 2026-10-04. Store requirements change often: items marked VERIFIED were read from the official page on that date; items marked (verify) come from general knowledge or were not stated on the page read, and MUST be re-checked in App Store Connect / Play Console before submitting. Real submission is BLOCKED on master plan Section 7 item 8 (Apple Developer and Google Play Console accounts).

Legend: `[ ]` open, `[x]` done, BLOCKER = the store will reject or refuse the release until it is fixed.

## A. BLOCKERS and open decisions found while preparing (not store assets)

Each one needs an owner decision; the code-level ones need NEW parts (they are not part of P-107).

| # | Item | Why it matters | Status |
|---|---|---|---|
| A1 | In-app ACCOUNT DELETION | Apple 5.1.1(v): apps that support account creation must offer deletion inside the app. Google Play: an in-app path AND a web link where users can request deletion, plus the deletion answers in the Data safety form (VERIFIED) | BLOCKER. Not found: the backend only deactivates accounts (`is_active=False`), no delete endpoint or Flutter screen was found |
| A2 | BLOCK USER | Apple 1.2: report mechanism, ability to block abusive users, published contact information, content filtering. Google UGC policy: in-app reporting AND blocking, blocking mandatory for 1:1 interaction such as chat (VERIFIED) | BLOCKER. Reporting exists (reports app); no block-user feature was found in the Flutter code or the Progress file |
| A3 | TERMS OF USE and PRIVACY POLICY links in the app | Google UGC policy: users accept terms before creating or uploading UGC. Apple 5.1.1: privacy policy in the metadata AND in the app (VERIFIED) | BLOCKER. No terms or privacy text or link exists in the register screen or anywhere in `lib/` |
| A4 | PRIVACY POLICY document and public URL | Required by both stores (Apple's property table lists the URL as optional, but its App Privacy page and guideline 5.1.1 require it; treat as required). Must state data collected, uses, third-party sharing, retention and how to request deletion (VERIFIED) | BLOCKER. NO privacy policy exists yet. Content must follow section D |
| A5 | Android target API | New apps and updates must target API 36 from 2026-08-31; extension request possible until 2026-11-01 (VERIFIED). `build.gradle.kts` uses `targetSdk = flutter.targetSdkVersion`, so it depends on the installed Flutter version | CHECK the `targetSdkVersion` printed by `p107_step3.ps1`; if it is below 36 it is a BLOCKER |
| A6 | Apple build toolchain | Uploads must be built with Xcode 26 or later and the iOS 26 SDK since 2026-04-28 (VERIFIED). The Flutter version in use (3.29.x per the Progress file) predates it; a Flutter upgrade and a regression run may be needed | OPEN, needs a Mac |
| A7 | iOS minimum deployment target | Apps must target iOS 13 or later from 2026-09-09 (VERIFIED) | DONE in P-107 STEP 2 (13.0) |
| A8 | Google Play personal-account testing rule | New PERSONAL accounts (created after 2023-11-13) need 12 testers opted in continuously for 14 days in closed testing before applying for production access; organization accounts are exempt (VERIFIED) | OPEN: depends on the account type chosen in Section 7 item 8 |
| A9 | Demo accounts and live backend for reviewers | Apple 2.1(a): active demo account (or approved demo mode) and live backend services during review. Google: sign-in instructions in App access, up to 5 sets (VERIFIED) | OPEN: needs the live backend (Section 7 items 6 and 9) and seeded demo accounts for Customer, Business and (if reviewers should see it) Moderator |
| A10 | Payments policy risk (ADR-006) | The Featured subscription is sold on a separate Web Dashboard and the app only shows the badge. Apple 3.1.1 requires in-app purchase to unlock features inside the app; the plan itself flags App Store rejection risk | OPEN owner risk. The app has no purchase UI and no link to the web purchase; explain this in the review notes (section F). Do not add a link-out without a policy re-check |
| A11 | Push notifications | Real delivery needs a Firebase project and an APNs key (Section 7 item 4) | BLOCKED |
| A12 | Real brand assets | Icons are Flutter placeholders on both platforms (Section 7 item 5) | BLOCKED |
| A13 | EU distribution | Apple requires verified trader status for apps distributed in the EU App Store (VERIFIED, dated 2024-2025) | OPEN: decide target countries first |
| A14 | Minimum user age | The app has chat and user-generated content and collects no date of birth. Decide the minimum age and the target audience answer for Play | OPEN owner decision |
| A15 | Final application id and bundle id | Both are PROVISIONAL (`com.example.*`); see `RELEASE_SIGNING.md` section 5 | OPEN |

## B. Apple App Store Connect

| Item | Requirement | Status |
|---|---|---|
| Name | Required, localizable (character limit: verify) | `[ ]` provisional "Social Commerce App" |
| Subtitle | Optional (limit: verify) | `[ ]` |
| Bundle ID, SKU, primary language | Required, fixed after creation | `[ ]` waits for A15 |
| Primary category | Required (secondary optional) | `[ ]` suggestion: Shopping or Social Networking, owner decision |
| Age rating | Required. The updated questionnaire (deadline was 2026-01-31) applies; answers in section E (VERIFIED) | `[ ]` |
| Content rights | Required | `[ ]` |
| Support URL | Listed optional, but guideline 1.2 needs published contact information: provide one | `[ ]` |
| Privacy policy URL | Treat as required (see A4) | `[ ]` BLOCKER A4 |
| Marketing URL, copyright, privacy choices URL | Optional | `[ ]` |
| Description, keywords, promotional text | Required text fields (limits: verify; usually 4000 / 100 / 170) | `[ ]` drafts in section G |
| What's New | Required for every update | `[ ]` |
| Screenshots, iPhone | 1 to 10, .jpeg/.jpg/.png, NO alpha. 6.9" portrait 1260x2736, 1290x2796 or 1320x2868, OR 6.5" portrait 1284x2778 or 1242x2688 (6.5" is mandatory when 6.9" is not provided) (VERIFIED) | `[ ]` |
| Screenshots, iPad | Required because the project targets iPad (`TARGETED_DEVICE_FAMILY = "1,2"`): 13" portrait 2064x2752 or 2048x2732 (VERIFIED). Alternative: make the app iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) | `[ ]` owner decision |
| App preview video | Optional (specs on Apple's separate page) | `[ ]` |
| App Privacy details | Required for every new app and update; types, linked to user, tracking, purposes, third-party SDK data (VERIFIED). Draft in section D | `[ ]` |
| Export compliance | Answer in App Store Connect; `ITSAppUsesNonExemptEncryption` is not set in `Info.plist` (see `RELEASE_SIGNING.md` section 6) | `[ ]` owner decision |
| App Review information | Contact details, demo account credentials, review notes (A9, A10) | `[ ]` |
| Version number and build | From `pubspec.yaml` (see `RELEASE_SIGNING.md` section 2) | `[ ]` |
| Digital Services Act trader status | Only if distributing in the EU (A13) | `[ ]` |
| App icon 1024x1024, no alpha | Present as a placeholder in the asset catalog | `[ ]` real icon pending (A12) |

## C. Google Play Console

| Item | Requirement | Status |
|---|---|---|
| App name | Required (limit: verify, usually 30) | `[ ]` |
| Short description | Required, maximum 80 characters (VERIFIED) | `[ ]` draft in section G |
| Full description | Required (limit: verify, usually 4000) | `[ ]` draft in section G |
| App icon | 512 x 512 px, 32-bit PNG (alpha allowed), maximum 1024 KB (VERIFIED) | `[ ]` real icon pending (A12) |
| Feature graphic | 1024 x 500 px, JPEG or 24-bit PNG (no alpha), required to publish the listing (VERIFIED) | `[ ]` |
| Phone screenshots | Minimum 2 screenshots in total across device types, up to 8 phone screenshots, JPEG or 24-bit PNG (no alpha), each side 320 to 3840 px; recommended: at least 4 at 1080 px width, 9:16 portrait (minimum 1080x1920) (VERIFIED) | `[ ]` |
| Tablet screenshots (7" and 10") | Google's page states a minimum of 4 for tablets and Chromebooks, 1080 to 7680 px, 9:16 or 16:9 (VERIFIED; verify whether they are optional for a phone-first app) | `[ ]` |
| Promo video | Optional, YouTube URL, public or unlisted, ads off (VERIFIED) | `[ ]` |
| Category, tags, store contact email, website | Required: category and contact email (verify details in the Console) | `[ ]` |
| Privacy policy URL | Required (A4) | `[ ]` BLOCKER A4 |
| App access | Sign-in instructions for reviewers, up to 5 sets (VERIFIED, A9) | `[ ]` |
| Ads declaration | The app has no ad SDK: declare "No ads" (VERIFIED requirement exists) | `[ ]` |
| Target audience and content | Declare the age group (A14); not designed for children | `[ ]` |
| Content rating | IARC questionnaire, answers in section E; unrated apps can be removed (VERIFIED) | `[ ]` |
| Data safety form | Declare collection, sharing, encryption in transit, deletion practices; privacy policy link required (VERIFIED). Draft in section D | `[ ]` |
| Account deletion declarations | In-app path + web link + Data safety deletion answers (VERIFIED, A1) | `[ ]` BLOCKER A1 |
| Other declarations | Financial features, health, news, COVID-19 (VERIFIED list exists; expected answer for this app: none apply, verify in the Console) | `[ ]` |
| Release artifact | `.aab` built by `flutter build appbundle --release`, signed with the upload key (`RELEASE_SIGNING.md` section 3), target API 36 (A5), new `versionCode` on every upload | `[ ]` |
| Testing | Internal testing first; closed testing 12 testers / 14 days for personal accounts (A8) | `[ ]` |

## D. Data practices inventory (DRAFT for the privacy policy, App Privacy details and Data safety form)

Built from the Progress file and the code as of 2026-10-04. The owner must confirm every line; the privacy policy must match the shipped behaviour.

| Data | Source in the app | Linked to the user | Purpose | Shared with |
|---|---|---|---|---|
| Email address | Registration (email + password + account type Customer/Business) | Yes | Account, app functionality | Backend only |
| Password | Registration | Yes | Authentication (stored hashed on the backend) | Backend only |
| Phone number | Optional profile field, validated with country code | Yes | App functionality | Backend only |
| Profile data (names, business name, category, country and city typed by the user) | Profile and business setup | Yes | App functionality | Backend only |
| User content: photos, videos, posts, reels, stories, product listings, comments, ratings | Gallery picker (`image_picker`, gallery only) | Yes | App functionality | Backend and the object storage provider (Section 7 item 2) |
| Messages | Chat (text and media) | Yes | App functionality | Backend only |
| Reports submitted about content | Report flow | Yes | Safety and moderation | Backend, moderators |
| Identifiers: user id, push token (FCM) | Login and notifications | Yes | App functionality, notifications | Backend, Google Firebase Cloud Messaging |
| Usage data: first-party engagement events (views, likes, follows) | Backend analytics (traders' dashboard) | Yes | Analytics, app functionality | Backend only |
| Diagnostics: crash and error reports | Sentry, only in builds given a DSN; `sendDefaultPii = false`, no performance traces | Declare as linked unless verified otherwise | Diagnostics | Sentry |
| Payment records (amounts, order references) | Backend, Featured subscription bought on the Web Dashboard through Paymob hosted pages; the app and the backend never store card data | Business accounts | Payments | Paymob |

Not collected by the app: GPS or device location, contacts, health data, advertising identifiers, third-party advertising, cross-app tracking. Expected declaration: NO tracking, so no App Tracking Transparency prompt (verify again if any SDK is added). Encryption in transit: HTTPS/TLS through Nginx once deployed (P-106). Deletion and retention: NOT defined yet (see A1 and A4).

## E. Content rating questionnaire, draft answers (Apple and IARC)

- User-generated content: YES (posts, reels, stories, comments, products), reviewed through the moderation pipeline before publication according to the master plan.
- User-to-user communication: YES (1:1 chat with media).
- Unrestricted web access: NO. Gambling or contests: NO. Sexual or violent content created by the developer: NO.
- Location sharing between users: NO. Digital purchases inside the app: NO. Real-money commerce inside the app: NO (discovery and messaging only, ADR-006).
- Expected outcome: not the lowest rating, because of user-generated content and chat. Decide the minimum age together with A14, and answer the questionnaires after that decision.

## F. App Review notes (draft)

"Sign in with the demo accounts below (Customer and Business). The app is a discovery and messaging platform for businesses and customers. There is no purchase flow, cart or payment inside the app. Businesses can buy a Featured ranking placement on a separate web dashboard; the app only displays the resulting Featured badge and offers no purchase or link to it. User-generated content is moderated before it is published, users can report content [and block users: pending A2]." Add the demo credentials and the support contact when they exist.

## G. Listing text drafts (PLACEHOLDER brand assets; English only, localize later, Arabic is likely needed)

SHORT_DESCRIPTION_DRAFT: Discover businesses, follow their stories and reels, and message them directly.

Full description (draft):
Discover businesses and products you like, all in one place.
- Follow businesses and see their posts, reels and 24-hour stories.
- Explore products and categories, and search by city and category.
- Message businesses directly, with photos and videos.
- Business accounts: set up a profile, publish content and products, and see analytics.
Featured businesses are marked with a Featured badge.

Keywords (draft, Apple, 100 characters maximum, verify): social,commerce,business,shop,discover,reels,stories,products,chat

Screenshot plan (6 per platform): Home feed, Stories viewer, Reels, Product detail, Search and filters, Chat. Capture on a device or simulator with a seeded demo account, with real brand assets once Section 7 item 5 exists.

## H. Sources checked on 2026-10-04

- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Apple app properties: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- Apple upcoming requirements: https://developer.apple.com/news/upcoming-requirements/
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Google Play listing assets: https://support.google.com/googleplay/android-developer/answer/9866151
- Google Play target API level: https://support.google.com/googleplay/android-developer/answer/11926878
- Google Play testing requirement for new personal accounts: https://support.google.com/googleplay/android-developer/answer/14151465
- Google Play app content declarations: https://support.google.com/googleplay/android-developer/answer/9859455
- Google Play Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- Google Play user generated content policy: https://support.google.com/googleplay/android-developer/answer/9876937