# Android App Audit — Comparison with iOS

**Date:** 2026-02-25
**Last updated:** 2026-02-25

---

## Critical Issues

### ✅ 1. Google Sign-In Broken — FIXED
- **File:** `AuthRepositoryImpl.kt`
- **Was:** `getWebClientId()` returned `"YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"`
- **Fix applied:** Reads `default_web_client_id` from resources (auto-generated from google-services.json) with hardcoded fallback. Added `@ApplicationContext context: Context` to constructor. Fixed NPE risks in `restoreSession()` and `loadOrCreateProfile()`. Simplified duplicate `listenAuthState()`.

### ✅ 2. Stripe PaymentSheet Never Presented — FIXED
- **Files:** `PaymentSummaryScreen.kt`, `MainScreen.kt`, `MainActivity.kt`
- **Was:** `onPaymentSheet = { _, _, _ -> }` no-op in MainScreen — PaymentSheet never shown
- **Fix applied:** Rewrote `PaymentSummaryScreen` with `rememberPaymentSheet` + `presentWithPaymentIntent()`. Removed broken callback chain. Added `PaymentConfiguration.init()` in `MainActivity`.

### ✅ 3. Demo Mode Not Integrated — FIXED
- **Files:** All repository implementations
- **Was:** `DemoMode.kt` existed but no repo checked `DemoMode.isActive`
- **Fix applied:** Added `DemoMode.isActive` checks in: `CKRGameRepositoryImpl`, `ChallengeRepositoryImpl`, `ChallengeResponseRepositoryImpl`, `NewsRepositoryImpl`, `StripeRepositoryImpl`, `CohouseRepositoryImpl`, `AuthRepositoryImpl`. Demo mode activated/deactivated based on test email in auth flow.

### ✅ 4. Foreground Notifications Not Displayed — FIXED
- **File:** `CKRFirebaseMessagingService.kt`
- **Was:** `onMessageReceived()` was empty
- **Fix applied:** Full notification handling with notification channel creation, PendingIntent for app launch, NotificationCompat with title/body/bigText style.

---

## Important Issues

### ✅ 5. Quit Cohouse Missing Firestore Cleanup — FIXED
- **Files:** `CohouseRepository.kt`, `CohouseRepositoryImpl.kt`, `CohouseViewModel.kt`
- **Fix applied:** Added `removeUser()` to interface + impl. `quitCohouse()` now removes user from Firestore subcollection before clearing cohouseId.

### ✅ 6. Real-Time Listeners for Challenge Responses — FIXED
- **File:** `ChallengeResponseRepositoryImpl.kt`
- **Fix applied:** `watchStatus()`, `watchAllResponses()`, `watchAllValidatedResponses()` use Firestore snapshot listeners for real-time updates.

### ✅ 7. Planning Tab — Retry on Error — FIXED
- **Files:** `PlanningViewModel.kt`, `PlanningScreen.kt`
- **Fix applied:** Added `PlanningIntent.Retry` + `onIntent()` handler. Error state shows "Reessayer" button.

### ⚠️ 8. Image URL vs Storage Path — ACCEPTED AS-IS
- **File:** `ChallengeResponseRepositoryImpl.kt`
- **Status:** `uploadImage()` returns the storage path (not the download URL). This matches iOS behavior where paths are stored and download URLs are resolved on-demand.

### ✅ 9. showCopied Never Reset — FIXED
- **File:** `CohouseScreen.kt`
- **Fix applied:** Added `LaunchedEffect(showCopied)` with 2-second delay to reset the flag.

### ❌ 10. Email Change Not Supported — NOT DONE
- **Issue:** Android `UserProfileFormScreen` shows the email field but doesn't offer email change functionality
- **iOS Reference:** iOS has `updateEmailTapped` action with Firebase `updateEmail()` + re-verification flow
- **Priority:** Low — rare user action

### ❌ 11. ValidationUtils Unused — NOT DONE
- **File:** `ValidationUtils.kt` exists with proper phone/email validation
- **Issue:** Sign-in and profile forms do not use `ValidationUtils` — no client-side validation before network calls
- **Priority:** Medium — improves UX but server validates anyway

---

## Feature Gaps vs iOS

### Missing Screens / Features
| Feature | iOS | Android | Status |
|---------|-----|---------|--------|
| Onboarding / Welcome screens | `OnboardingFeature` with 3-page carousel | None | ❌ Not done |
| News detail screen | `NewsDetailView` | Truncated text only in card | ❌ Not done |
| Settings screen | Dedicated settings (notifications toggle, etc.) | None | ❌ Not done |
| Admin app (CKRAdmin) | Separate target with challenge validation, game mgmt | N/A | N/A (not planned) |

### Missing UI Polish
| Item | iOS | Android | Status |
|------|-----|---------|--------|
| Pull-to-refresh | Available on Home, Challenges, Planning | None | ❌ Not done |
| Animated transitions | Custom TCA navigation animations | Default Compose transitions | ❌ Not done |
| Confetti / celebration | Confetti on registration success | None | ❌ Not done |
| Skeleton loading | Shimmer placeholders | Simple `CircularProgressIndicator` | ❌ Not done |
| Haptic feedback | On button presses, copy actions | None | ❌ Not done |
| Cover image on home | Async image with shimmer | Static aspect ratio placeholder | ❌ Not done |
| Error illustrations | Custom error illustrations | Plain text errors | ❌ Not done |
| Consistent background colors | Uniform styling | TopAppBar matches background | ✅ Fixed |

### Missing Data Layer
| Feature | iOS | Android | Status |
|---------|-----|---------|--------|
| Real-time game updates | `watchGame()` Firestore listener | One-time `getLatest()` fetch | ❌ Not done |
| Real-time cohouse updates | `watchCohouse()` listener | One-time fetch | ❌ Not done |
| Real-time challenge responses | `watchStatus()` per tile | `watchStatus()` + `watchAllResponses()` | ✅ Fixed |
| Offline caching | Some TCA `@Shared` persistence | None | ❌ Not done |

---

## Code Quality Issues

### ✅ Duplicate Code — FIXED
- `listenAuthState()` now delegates to `isLoggedIn` (no duplication)

### ✅ Safety Concerns — PARTIALLY FIXED
- `restoreSession()` NPE risk: **Fixed** — safe null checks, no more `!!` on document data
- `as Map<String, Any>` casts: **Not addressed** — scattered across repos
- `BuildConfig.STRIPE_PUBLISHABLE_KEY` placeholder: **N/A** — real key set via build config

### ❌ Missing Tests
- Zero unit tests exist (test dependencies are in `build.gradle.kts` but no test files found)
- iOS has a full test suite with `TestStore` for every feature reducer

---

## Priority Order for Fixes

1. ~~**Google Sign-In** (P0 — app is unusable for Google users)~~ ✅
2. ~~**Stripe PaymentSheet** (P0 — registration flow is broken)~~ ✅
3. ~~**Demo Mode integration** (P0 — Play Store review will fail)~~ ✅
4. ~~**Foreground notifications** (P1 — important UX gap)~~ ✅
5. ~~**Misc bugs** (P2 — quit cohouse, showCopied, planning retry)~~ ✅

### Remaining work (by priority)
1. **ValidationUtils integration** — wire phone/email validation to profile forms
2. **Email change support** — Firebase `updateEmail()` + re-verification
3. **Real-time game/cohouse listeners** — replace one-time fetches with Firestore listeners
4. **Pull-to-refresh** — on Home, Challenges, Planning tabs
5. **UI polish** — skeleton loading, haptics, transitions, confetti
6. **Onboarding screens** — 3-page welcome carousel
7. **Unit tests** — at least for ViewModels and repositories
