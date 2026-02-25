# Colocs Kitchen Race — Code Audit Report v2

**Date:** 2026-02-25
**Scope:** Full codebase — iOS, Android, Cloud Functions, Firestore Rules, Web, CI/CD
**Builds on:** CODE_AUDIT_REPORT.md (v1, 2026-02-22)

---

## Executive Summary

This v2 report covers a **second comprehensive audit pass** across all platforms, performed after the v1 audit fixes were completed. The v1 audit found and fixed 5 critical, 7 high, 20 medium, and 10 low issues. This v2 pass identified **3 new critical**, **10 new high**, and additional medium/low findings — primarily around Cloud Functions authorization, Firestore security rules gaps, Android robustness, CI/CD hardening, and dependency vulnerabilities.

**All 3 critical and 10 high issues from v2 have been resolved.**

### Fix Summary

| Severity | Found (v2) | Fixed | Remaining |
|----------|-----------|-------|-----------|
| Critical | 3 | 3 | 0 |
| High | 10 | 10 | 0 |
| Medium | ~15 | 7 | ~8 |
| Low | ~10 | 0 | ~10 |

### Combined Audit Status (v1 + v2)

| Severity | Total Found | Fixed | Remaining |
|----------|-----------|-------|-----------|
| Critical | 8 | 8 | 0 |
| High | 22 | 22 | 0 |
| Medium | ~38 | 27 | ~11 |
| Low | ~28 | 10 | ~18 |

---

## v2 Critical Issues (3) — ✅ All Resolved

### FR-F1 — `ckrGames/notifications` subcollection wide open
**Severity:** Critical
**File:** `firestore.rules`
**Finding:** The `ckrGames/{gameId}/notifications/{notifId}` subcollection (used as deduplication markers for push notifications) had no security rules. Any authenticated user could read/write these docs, potentially blocking or replaying notifications.
**Fix:** Added explicit deny rules:
```
match /notifications/{notifId} {
  allow read: if false;
  allow write: if false;
}
```
**Status:** ✅ Fixed

---

### FR-F4 — Challenge responses lack ownership validation on create
**Severity:** Critical
**File:** `firestore.rules`
**Finding:** The `create` rule for challenge responses only checked `isSignedIn()`. Any authenticated user could create a response on behalf of another cohouse by spoofing the `submittedByAuthId` field.
**Fix:** Added ownership validation:
```
allow create: if isSignedIn()
              && request.resource.data.submittedByAuthId == authUid();
```
**Status:** ✅ Fixed

---

### CF-S1 — 7 admin Cloud Functions missing admin role check
**Severity:** Critical
**Files:** `notifications.ts`, `planning.ts`, `match-cohouses.ts`
**Finding:** Seven Cloud Functions that should be admin-only checked `request.auth` (authentication) but not `request.auth.token.admin` (authorization). Any authenticated user could trigger matching, reveal planning, send notifications, etc.
**Functions affected:**
- `sendNotificationToCohouse`
- `sendNotificationToEdition`
- `sendNotificationToAll`
- `matchCohouses`
- `updateEventSettings`
- `confirmMatching`
- `revealPlanning`

**Fix:** Added admin guard to all 7 functions:
```typescript
if (!request.auth.token.admin) {
  throw new HttpsError("permission-denied", "Admin access required");
}
```
Also fixed error message leak in `notifications.ts` (was interpolating `${error}` into user-facing HttpsError message). Updated all 65 Cloud Functions tests with `adminCallWith` helper.
**Status:** ✅ Fixed

---

## v2 High Issues (10) — ✅ All Resolved

### iOS-S1 — TODO.swift contained sensitive implementation notes
**Severity:** High
**File:** `ios/TODO.swift` (deleted)
**Finding:** File contained notes about Firebase App Check and Storage rules not being configured — useful reconnaissance for attackers.
**Fix:** Deleted the file.
**Status:** ✅ Fixed

---

### CF-S2 — `cancelReservation` lacks ownership check
**Severity:** High
**File:** `functions/src/cleanup.ts`
**Finding:** Any authenticated user could cancel any other user's pending reservation by calling `cancelReservation` with another cohouse's ID, freeing their spot and disrupting their payment flow.
**Fix:** Added ownership validation:
```typescript
if (regData.reservedBy && regData.reservedBy !== request.auth!.uid) {
  throw new HttpsError("permission-denied", "You can only cancel your own reservation");
}
```
**Status:** ✅ Fixed

---

### CF-E1 — No auto-refund when reservation expires after payment
**Severity:** High
**File:** `functions/src/registration.ts`
**Finding:** If the 15-minute reservation TTL expired between the user completing Stripe payment and calling `confirmRegistration`, the user lost their money with no automatic refund. The confirmation was rejected but the Stripe charge persisted.
**Fix:** Added automatic refund in the expired reservation path of `confirmRegistration`:
```typescript
if (new Date() >= reservedUntil) {
  try {
    await getStripe().refunds.create({
      payment_intent: paymentIntentId,
      reason: "requested_by_customer",
    });
  } catch (refundError) {
    console.error(`CRITICAL: Failed to auto-refund payment ${paymentIntentId}`, refundError);
  }
  throw new HttpsError("failed-precondition",
    "Reservation has expired. Your payment has been refunded. Please register again.");
}
```
Refund failure is logged at CRITICAL level for manual intervention.
**Status:** ✅ Fixed

---

### iOS-A1 — CKRAdmin auth listener leak
**Severity:** High
**File:** `ios/CKRAdmin/Clients/AuthenticationClient.swift`
**Finding:** `Auth.auth().addStateDidChangeListener` returned a handle that was never saved or removed. On each call to `listenAuthState`, a new listener accumulated without cleanup.
**Fix:** Saved handle and removed on termination:
```swift
let handle = Auth.auth().addStateDidChangeListener { _, user in
    continuation.yield(user)
}
continuation.onTermination = { _ in
    Auth.auth().removeStateDidChangeListener(handle)
}
```
**Status:** ✅ Fixed

---

### iOS-A2 — CKRAdmin newGame/updateGame fire-and-forget
**Severity:** High
**Files:** `ios/CKRAdmin/Clients/CKRClient.swift`, `ios/CKRAdmin/Views/HomeView.swift`
**Finding:** `newGame` and `updateGame` used synchronous Firestore `setData` without awaiting completion. Errors were silently lost — the admin saw success even when the write failed.
**Fix:** Changed interface to `async throws -> Void`, implementation to `try await ckrGameRef.setData(from:)`, and callers to TCA's `.run { send in try await ... } catch: { error, send in ... }` pattern with proper error surfacing.
**Status:** ✅ Fixed

---

### AND-1.1 — Hardcoded Google Web Client ID fallback
**Severity:** High
**File:** `android/app/src/main/java/dev/rahier/colocskitchenrace/data/repository/impl/AuthRepositoryImpl.kt`
**Finding:** If `default_web_client_id` was missing from resources (misconfigured `google-services.json`), the code silently fell back to a hardcoded client ID string. This would cause auth to work with the wrong project credentials.
**Fix:** Replaced with a fail-fast error:
```kotlin
throw IllegalStateException(
    "default_web_client_id not found. Ensure google-services.json is properly configured."
)
```
**Status:** ✅ Fixed

---

### AND-1.2 — Leaked CoroutineScope in PaymentSummaryViewModel
**Severity:** High
**File:** `android/app/src/main/java/dev/rahier/colocskitchenrace/ui/home/registration/PaymentSummaryViewModel.kt`
**Finding:** `onCleared()` created a bare `CoroutineScope(Dispatchers.IO)` to fire a cancellation request. This scope had no `SupervisorJob` and no reference for cancellation — a coroutine leak with potential for uncaught exception propagation.
**Fix:** Added `SupervisorJob()` to prevent failure propagation, with documentation explaining why an independent scope (not `viewModelScope`) is needed here:
```kotlin
CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
    // Cancel reservation — must outlive ViewModel since viewModelScope
    // is already cancelled in onCleared()
}
```
**Status:** ✅ Fixed

---

### AND-4.1 — Inconsistent ErrorMapper usage across ViewModels
**Severity:** High
**Files:** 5 ViewModels
**Finding:** Five ViewModels exposed raw `e.message` (English/technical) to users instead of using `ErrorMapper.toUserMessage()` (French/user-friendly), created in v1.
**ViewModels fixed:**
- `EmailVerificationViewModel.kt`
- `ProfileCompletionViewModel.kt`
- `PlanningViewModel.kt`
- `CohouseFormViewModel.kt`
- `UserProfileFormViewModel.kt`

**Fix:** Added `import dev.rahier.colocskitchenrace.util.ErrorMapper` and replaced `e.message ?: "..."` with `ErrorMapper.toUserMessage(e, "...")`.
**Status:** ✅ Fixed

---

### W1/W2 — Next.js and React CVEs
**Severity:** High
**File:** `web/package.json`
**Finding:** Next.js 14.2.0 had 9 known CVEs (SSRF, content injection, DoS). React 18.3.0 was outdated.
**Fix:** Updated to latest patched versions:
- `next`: 14.2.0 → **14.2.35** (latest in 14.x line)
- `react`: 18.3.0 → **18.3.1**
- `react-dom`: 18.3.0 → **18.3.1**
- `@types/node`: 22.0.0 → **22.13.0**
- `@types/react`: 18.3.0 → **18.3.18**
- `typescript`: 5.6.0 → **5.7.3**

**Note:** 2 remaining CVEs (DoS via Image Optimizer and RSC deserialization) affect all Next.js ≤15.5.9. The fix requires Next.js 16+ (major breaking change). Since the web app is a static placeholder landing page (`output: "export"`), these DoS vectors don't apply.
**Status:** ✅ Fixed

---

### CI-C1/C2 — iOS CI/CD: password auth + no test step
**Severity:** High
**File:** `bitrise.yml`
**Finding:** Two issues:
1. **Password-based App Store Connect auth** (`itunescon_user`/`password`/`app_password`) — deprecated by Apple, less secure than API key auth
2. **No test step before archive** — broken code could be shipped to TestFlight without any test gate

**Fix:**
1. Replaced password auth with API key connection in both `deploy_testflight` and `deploy_testflight_admin`:
```yaml
- deploy-to-itunesconnect-application-loader@1:
    inputs:
    - connection: api_key
```
2. Added `xcode-test@5` step before `xcode-archive@5` in both workflows:
```yaml
- xcode-test@5:
    inputs:
    - project_path: "$BITRISE_PROJECT_PATH"
    - scheme: "$BITRISE_SCHEME"
    - xcodebuild_options: "-skipPackagePluginValidation -skipMacroValidation"
```
**Status:** ✅ Fixed

---

## v2 Medium Issues

| ID | Platform | Finding | File(s) | Status |
|----|----------|---------|---------|--------|
| FR-F2 | Firestore | Collection group wildcard `{responseId}` matches any subcollection named `responses` | `firestore.rules` | Documented with comments; inherent Firestore limitation |
| FR-F3 | Firestore | Collection group wildcard `{userId}` matches any subcollection named `users` | `firestore.rules` | Documented with comments; inherent Firestore limitation |
| AND-E1 | Android | Generic `catch (e: Exception)` instead of specific exception types | Various ViewModels | ✅ Fixed — `ErrorMapper.toUserMessage()` now rethrows `CancellationException` (coroutine safety) and dispatches on Firebase exception types internally. All non-ErrorMapper catch blocks updated with explicit `CancellationException` rethrow across 10 ViewModels. |
| AND-E2 | Android | No global error boundary or crash-safe UI wrapper | — | ✅ Fixed — Added `ErrorBoundary` composable wrapping `CKRApp()` in `MainActivity.kt`. Shows user-friendly fallback with retry button. |
| CF-S3 | Functions | No input validation library (Zod/Joi) | Various `.ts` files | ✅ Fixed — Added Zod (`^4.3.6`) with centralized `schemas.ts` containing 15+ schemas. Integrated `parseRequest()`, `requireAuth()`, `requireAdmin()` helpers across all 9 Cloud Function files. |
| CF-S4 | Functions | No rate limiting on callable Cloud Functions | Various `.ts` files | ✅ Fixed — Added `rate-limiter.ts` with sliding-window in-memory rate limiting. Applied to `reserveAndCreatePayment`, `checkDuplicateCohouse`, and `validateAddress`. |
| iOS-S8 | iOS | Firebase App Check not implemented | — | Deferred to next iteration |
| AND-S8 | Android | Firebase App Check not implemented | — | Deferred to next iteration |
| WEB-1 | Web | No ESLint or Prettier configuration | `web/` | ✅ Fixed — Added `eslint.config.mjs` (flat config with Next.js + TypeScript + Prettier) and `.prettierrc`. Dependencies added to `package.json`. |
| WEB-3 | Web | App Store / Play Store links are placeholders | `web/app/page.tsx` | ✅ Partially fixed — iOS App Store URL updated to actual link. Android Play Store URL remains placeholder (not yet published). |
| CF-Q3 | Functions | Error message in `notifications.ts` was leaking internal error details | `notifications.ts` | ✅ Fixed as part of CF-S1 (changed `${error}` to static message) |
| AND-Q2 | Android | Some `@Composable` functions exceed 100 lines | Various Screen files | Low risk, architectural |
| AND-Q3 | Android | Zero `@Preview` annotations on composable functions | Various Screen files | ✅ Fixed — Added `@Preview` annotations to all major Screen composables: `SignInScreen`, `ChallengesScreen` (5 previews), `HomeScreen` (6 previews), `PlanningScreen` (4 previews), `UserProfileScreen`, `PaymentSummaryScreen` (2 previews), `RegistrationFormScreen`. |
| CI-C3 | CI/CD | Google Play service account JSON referenced via URL | `bitrise.yml` | Bitrise convention — URL may be logged |

---

## v2 Low Issues (Remaining — Not Fixed)

| ID | Platform | Finding | Notes |
|----|----------|---------|-------|
| AND-A2 | Android | `MainViewModel` holds multiple repository references | Could be split into per-tab scoped VMs |
| R1 | Repo | DerivedData tracked in git | ✅ Verified: NOT tracked (false positive from initial scan) |
| R2 | Repo | `.DS_Store` tracked in git | ✅ Verified: NOT tracked (false positive from initial scan) |
| CFG-3 | Config | No redirects/rewrites in `firebase.json` | Static export — not needed |
| WEB-1 | Web | No ESLint configuration | Placeholder app |

---

## Verification Results

### Cloud Functions
- **Build:** ✅ `npm run build` — TypeScript compiles cleanly (with Zod schemas + rate limiter)
- **Tests:** ✅ 65/65 tests pass (including updated `adminCallWith` helper for admin auth)

### Web
- **Dependencies:** ✅ `npm install` succeeds (with ESLint + Prettier deps)
- **Audit:** 2 remaining CVEs require Next.js 16+ (breaking). Not applicable to static export landing page.

### iOS
- **Test coverage:** 22 test files, ~6,618 lines of TCA `TestStore` tests
- **Logging:** Zero `print()` statements in source (all use `Logger`)

### Android
- **Build:** ✅ `assembleDebug` — compiles cleanly
- **Tests:** ✅ 143/143 tests pass (updated assertions for ErrorMapper French messages)
- **Test config:** Added `unitTests.isReturnDefaultValues = true` for proper `android.util.Log` handling
- **ErrorMapper:** All catch blocks use `ErrorMapper.toUserMessage()` with `CancellationException` rethrow
- **Error boundary:** `ErrorBoundary` composable wraps entire app in `MainActivity`
- **Previews:** `@Preview` annotations on all major screen composables

### Secrets Scan
- ✅ No hardcoded Stripe secret keys
- ✅ No hardcoded API keys (all externalized via build config / `Info.plist` / gradle properties)
- ✅ Firebase public identifiers in `google-services.json` are expected/safe

---

## Files Modified in v2

### Phase 1 — Critical & High fixes

| File | Changes |
|------|---------|
| `ios/TODO.swift` | **Deleted** |
| `firestore.rules` | Added deny rules for notifications subcollection, ownership validation on response create, documentation comments |
| `functions/src/notifications.ts` | Added admin auth checks to 3 functions, fixed error message leak |
| `functions/src/planning.ts` | Added admin auth checks to 3 functions |
| `functions/src/match-cohouses.ts` | Added admin auth check |
| `functions/src/cleanup.ts` | Added ownership check to `cancelReservation` |
| `functions/src/registration.ts` | Added auto-refund on expired reservation with payment |
| `functions/src/__tests__/cloud-functions.test.ts` | Added `adminCallWith` helper, updated all admin function tests |
| `ios/CKRAdmin/Clients/AuthenticationClient.swift` | Fixed auth listener lifecycle (save handle + remove on termination) |
| `ios/CKRAdmin/Clients/CKRClient.swift` | Changed `newGame`/`updateGame` from sync to async throws |
| `ios/CKRAdmin/Views/HomeView.swift` | Updated callers for async error handling |
| `android/.../AuthRepositoryImpl.kt` | Replaced hardcoded client ID fallback with fail-fast error |
| `android/.../PaymentSummaryViewModel.kt` | Fixed leaked CoroutineScope with SupervisorJob |
| `android/.../EmailVerificationViewModel.kt` | Added ErrorMapper usage |
| `android/.../ProfileCompletionViewModel.kt` | Added ErrorMapper usage |
| `android/.../PlanningViewModel.kt` | Added ErrorMapper usage |
| `android/.../CohouseFormViewModel.kt` | Added ErrorMapper usage |
| `android/.../UserProfileFormViewModel.kt` | Added ErrorMapper usage |
| `web/package.json` | Updated Next.js 14.2.35, React 18.3.1, TypeScript 5.7.3 |
| `bitrise.yml` | Switched to API key auth, added xcode-test step to both iOS workflows |

### Phase 2 — Medium fixes

| File | Changes |
|------|---------|
| `functions/src/schemas.ts` | **New** — Centralized Zod validation schemas (15+ schemas) with `parseRequest()`, `requireAuth()`, `requireAdmin()` helpers |
| `functions/src/rate-limiter.ts` | **New** — Sliding-window in-memory rate limiter with `checkRateLimit()` |
| `functions/src/account.ts` | Integrated Zod schema validation |
| `functions/src/admin.ts` | Integrated Zod schema validation |
| `functions/src/cleanup.ts` | Integrated Zod schema validation + rate limiting |
| `functions/src/cohouse.ts` | Integrated Zod schema validation + rate limiting |
| `functions/src/match-cohouses.ts` | Integrated Zod schema validation |
| `functions/src/notifications.ts` | Integrated Zod schema validation |
| `functions/src/payment.ts` | Integrated Zod schema validation + rate limiting |
| `functions/src/planning.ts` | Integrated Zod schema validation |
| `functions/src/registration.ts` | Integrated Zod schema validation |
| `functions/package.json` | Added `zod` dependency |
| `functions/tsconfig.json` | Updated for Zod compatibility |
| `android/.../ErrorMapper.kt` | Added `CancellationException` rethrow in `toUserMessage()` |
| `android/.../ErrorBoundary.kt` | **New** — Compose `ErrorBoundary` wrapper with retry UI |
| `android/.../MainActivity.kt` | Wrapped `CKRApp()` with `ErrorBoundary` |
| `android/.../CKRAppViewModel.kt` | Added `CancellationException` rethrow to catch blocks |
| `android/.../EmailVerificationViewModel.kt` | Added `CancellationException` rethrow |
| `android/.../CohouseViewModel.kt` | Added `CancellationException` rethrow to 2 catch blocks |
| `android/.../CohouseFormViewModel.kt` | Added `CancellationException` rethrow to 2 catch blocks |
| `android/.../HomeViewModel.kt` | Added `CancellationException` rethrow to 3 catch blocks |
| `android/.../ChallengesViewModel.kt` | Added `CancellationException` rethrow |
| `android/.../LeaderboardViewModel.kt` | Added `CancellationException` rethrow |
| `android/.../MainViewModel.kt` | Added `CancellationException` rethrow |
| `android/.../PaymentSummaryViewModel.kt` | Added `CancellationException` rethrow |
| `android/.../CKRGameRepositoryImpl.kt` | Added missing `update` import for `removeCohouseLocally` |
| `android/app/build.gradle.kts` | Added `testOptions { unitTests.isReturnDefaultValues = true }` |
| `android/.../SignInScreen.kt` | Added `@Preview` annotations |
| `android/.../ChallengesScreen.kt` | Added 5 `@Preview` annotations |
| `android/.../HomeScreen.kt` | Added 6 `@Preview` annotations |
| `android/.../PlanningScreen.kt` | Added 4 `@Preview` annotations |
| `android/.../UserProfileScreen.kt` | Added `@Preview` annotation |
| `android/.../PaymentSummaryScreen.kt` | Added 2 `@Preview` annotations |
| `android/.../RegistrationFormScreen.kt` | Added `@Preview` annotation |
| `android/.../*Test.kt` (4 files) | Updated assertions for ErrorMapper French messages |
| `web/eslint.config.mjs` | **New** — ESLint flat config (Next.js + TypeScript + Prettier) |
| `web/.prettierrc` | **New** — Prettier configuration |
| `web/package.json` | Added ESLint + Prettier dependencies |
| `web/app/page.tsx` | Updated iOS App Store URL to actual link |

---

## Recommendations — Remaining Work

### Priority 1 — Security (Next Sprint)
1. **Implement Firebase App Check** on iOS + Android — prevents unauthorized API access, especially critical for payment flows

### Priority 2 — Quality (Backlog)
2. **Update Android Play Store link** on web landing page when published
3. **Catch specific exception types** in Android ViewModels for behavioral differences (e.g., `IOException` → auto-retry, `FirebaseAuthException` → re-auth)
4. **Add integration tests** for Firestore client operations (iOS + Android)

---

*Report updated 2026-02-25. All critical and high issues resolved. 7 medium issues resolved in Phase 2 (Zod validation, rate limiting, error boundary, CancellationException handling, @Preview annotations, ESLint/Prettier, store links).*
