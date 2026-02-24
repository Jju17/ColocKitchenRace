# Android App Audit — Comparison with iOS

**Date:** 2026-02-25

---

## Critical Issues

### 1. Google Sign-In Broken
- **File:** `AuthRepositoryImpl.kt` — `getWebClientId()` returns `"YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"`
- **Impact:** Google Sign-In crashes at runtime; users cannot sign in via Google
- **Fix:** Extract the Web Client ID from `google-services.json` (client_type 3): `1030034975653-r9beetrg8e3ijj43a30k3uan4oj5ifdc.apps.googleusercontent.com`

### 2. Stripe PaymentSheet Never Presented
- **File:** `MainScreen.kt` — `onPaymentSheet = { _, _, _ -> }` is a no-op
- **Impact:** After creating a PaymentIntent, the Stripe PaymentSheet is never shown. Users cannot pay.
- **Fix:** Initialize `PaymentConfiguration` in `MainActivity`, set up `PaymentSheet` in `MainScreen`, and wire the callback to the `PaymentSummaryViewModel` flow.

### 3. Demo Mode Not Integrated
- **Files:** `DemoMode.kt` exists with full mock data, but NO repository implementation checks `DemoMode.isActive`
- **Impact:** Play Store reviewer account gets no mock data; screens appear empty or crash on Firestore calls
- **Fix:** Add `DemoMode.isActive` checks in all repository impls (CKRGame, Challenge, Cohouse, News, Stripe, Auth)

### 4. Foreground Notifications Not Displayed
- **File:** `CKRFirebaseMessagingService.kt` — `onMessageReceived()` is empty
- **Impact:** When app is in foreground, FCM notifications are silently dropped (system only auto-displays in background)
- **Fix:** Build and display a local notification from `onMessageReceived()` when the app is in the foreground

---

## Important Issues

### 5. Quit Cohouse Missing Firestore Cleanup
- **File:** `CohouseRepositoryImpl.kt`
- **Issue:** `quitCohouse()` updates local state but doesn't remove the user from the cohouse's Firestore subcollection or clear the user's `cohouseId` field
- **iOS Reference:** iOS calls `cohouseClient.quitCohouse()` which removes from subcollection and clears user doc

### 6. No Real-Time Listeners for Challenge Responses
- **File:** `ChallengesViewModel.kt`
- **Issue:** Challenge responses loaded once on screen init; admin validation doesn't update until user navigates away and back
- **iOS Reference:** iOS uses per-tile `watchStatus(challengeId, cohouseId)` real-time listeners

### 7. Planning Tab — No Retry on Error
- **File:** `PlanningViewModel.kt`
- **Issue:** If `getMyPlanning()` fails, there's no retry button; the error state is shown permanently
- **iOS Reference:** iOS shows error with a "Reessayer" button

### 8. Image URL vs Storage Path
- **File:** `ChallengeResponseRepositoryImpl.kt`
- **Issue:** `uploadImage()` returns the Firebase Storage *path* (e.g., `challenges/xxx/responses/yyy.jpg`), not the download URL
- **Impact:** If any code tries to display the image using this path as a URL, it won't work. Currently, submitted responses just show the path as-is.

### 9. showCopied Never Reset
- **File:** `CohouseViewModel.kt`
- **Issue:** `showCopied` state is set to `true` when invite code is copied, but never reset to `false`
- **Impact:** The "Copied!" indicator stays visible permanently after first copy

### 10. Email Change Not Supported
- **Issue:** Android `UserProfileFormScreen` shows the email field but doesn't offer email change functionality
- **iOS Reference:** iOS has `updateEmailTapped` action with Firebase `updateEmail()` + re-verification flow

### 11. ValidationUtils Unused
- **File:** `ValidationUtils.kt` exists with proper phone/email validation
- **Issue:** Sign-in and profile forms do not use `ValidationUtils` — no client-side validation before network calls
- **iOS Reference:** iOS validates all fields before allowing form submission

---

## Feature Gaps vs iOS

### Missing Screens / Features
| Feature | iOS | Android |
|---------|-----|---------|
| Onboarding / Welcome screens | `OnboardingFeature` with 3-page carousel | None |
| News detail screen | `NewsDetailView` | Truncated text only in card |
| Settings screen | Dedicated settings (notifications toggle, etc.) | None |
| Admin app (CKRAdmin) | Separate target with challenge validation, game mgmt | N/A (not planned) |

### Missing UI Polish
| Item | iOS | Android |
|------|-----|---------|
| Pull-to-refresh | Available on Home, Challenges, Planning | None |
| Animated transitions | Custom TCA navigation animations | Default Compose transitions |
| Confetti / celebration | Confetti on registration success | None |
| Skeleton loading | Shimmer placeholders | Simple `CircularProgressIndicator` |
| Haptic feedback | On button presses, copy actions | None |
| Cover image on home | Async image with shimmer | Static aspect ratio placeholder |
| Error illustrations | Custom error illustrations | Plain text errors |

### Missing Data Layer
| Feature | iOS | Android |
|---------|-----|---------|
| Real-time game updates | `watchGame()` Firestore listener | One-time `getLatest()` fetch |
| Real-time cohouse updates | `watchCohouse()` listener | One-time fetch |
| Offline caching | Some TCA `@Shared` persistence | None |

---

## Code Quality Issues

### Duplicate Code
- `AuthRepositoryImpl.kt` has both `isLoggedIn` (line 40) and `listenAuthState()` (line 167) — identical flows
- Multiple `mapToUser()` patterns scattered vs centralized

### Safety Concerns
- `restoreSession()` line 196: `snapshot.documents[0].data!!` force-unwrap — NPE risk if document has no data
- Several `as Map<String, Any>` casts without null checks across repository impls
- `BuildConfig.STRIPE_PUBLISHABLE_KEY` defaults to `"pk_test_placeholder"` in debug — will fail at Stripe SDK init

### Missing Tests
- Zero unit tests exist (test dependencies are in `build.gradle.kts` but no test files found)
- iOS has a full test suite with `TestStore` for every feature reducer

---

## Priority Order for Fixes

1. **Google Sign-In** (P0 — app is unusable for Google users)
2. **Stripe PaymentSheet** (P0 — registration flow is broken)
3. **Demo Mode integration** (P0 — Play Store review will fail)
4. **Foreground notifications** (P1 — important UX gap)
5. **Misc bugs** (P2 — quit cohouse, showCopied, validation, etc.)
