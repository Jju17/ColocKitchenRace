# Colocs Kitchen Race — Comprehensive Code Audit Report

**Date:** 2026-02-22
**Scope:** Full codebase — iOS, Android, Cloud Functions, Firestore Rules, Web, CI/CD

---

## Executive Summary

This report covers a full audit of the Colocs Kitchen Race (CKR) project across all platforms and infrastructure. The codebase demonstrates solid architectural foundations — proper use of TCA on iOS, clean MVI on Android, and well-structured Cloud Functions. However, the audit identified **5 critical**, **12 high**, and **20+ medium** severity findings that should be addressed.

**Top priorities:**
1. Hardcoded Stripe publishable key in iOS source
2. Firebase Auth listener memory leak (iOS)
3. Firestore security rules logic bug in challenge response updates
4. Weak cohouse membership validation in Firestore rules
5. Race condition in game registration (Cloud Functions)

---

## Table of Contents

1. [iOS App (Swift / TCA)](#1-ios-app-swift--tca)
2. [Android App (Kotlin / MVI)](#2-android-app-kotlin--mvi)
3. [Firebase Cloud Functions (TypeScript)](#3-firebase-cloud-functions-typescript)
4. [Firestore Security Rules](#4-firestore-security-rules)
5. [Web App (Next.js)](#5-web-app-nextjs)
6. [CI/CD Pipeline (Bitrise)](#6-cicd-pipeline-bitrise)
7. [Project Configuration](#7-project-configuration)
8. [Consolidated Findings Table](#8-consolidated-findings-table)
9. [Prioritized Recommendations](#9-prioritized-recommendations)

---

## 1. iOS App (Swift / TCA)

### 1.1 Architecture

**Strengths:**
- Proper TCA pattern with `@Reducer` macro and `@ObservableState` across all features
- Clean state composition using `@Shared` for global state (userInfo, cohouse, ckrGame, news, challenges)
- Dependency injection via `@Dependency` for all clients
- Well-structured root flow: `AppFeature` → `TabFeature` → feature reducers

**Issues:**

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| iOS-A1 | `SplashScreenFeature` has empty State and no-op `onAppear` action — dead code | `Views/SplashScreenView.swift` | 12-25 | Low |
| iOS-A2 | `onChange(of: selectedFilter)` on View layer instead of reducer action — breaks single source of truth | `Views/Challenge/ChallengeView.swift` | 341 | Medium |
| iOS-A3 | `refresh` action silently fails with `try?` — no error state in `HomeFeature.State` | `Views/Home/HomeView.swift` | 84-92 | Medium |

### 1.2 Security

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| iOS-S1 | **Hardcoded Stripe test publishable key** in source code, exposed in repo | `colockitchenraceApp.swift` | 36 | **Critical** |
| iOS-S2 | **Auth state listener never unregistered** — `addStateDidChangeListener` returns a handle that is never saved or removed | `Clients/AuthentificationClient.swift` | 362-370 | **Critical** |
| iOS-S3 | `@unchecked Sendable` with `nonisolated(unsafe)` on `currentNonce` — race condition possible | `Clients/AuthentificationClient.swift` | 396-398 | **High** |
| iOS-S4 | `DispatchQueue.main.sync` in `presentationAnchor` callback — potential deadlock | `Clients/AuthentificationClient.swift` | 434 | **High** |
| iOS-S5 | Email regex too permissive — accepts `a..b@example..com` | `Shared/Utils/UserValidation.swift` | 38-40 | Medium |
| iOS-S6 | Phone regex accepts strings like `"+++---())(("` (7 chars of noise) | `Shared/Utils/UserValidation.swift` | 45-48 | Medium |
| iOS-S7 | Deep linking from notification data not implemented — `// TODO` placeholder | `colockitchenraceApp.swift` | 110 | Medium |
| iOS-S8 | Firebase App Check not implemented (marked as incomplete in TODO.swift) | `TODO.swift` | 11-12 | **High** |

### 1.3 Memory & Performance

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| iOS-P1 | **News listener leaked in demo mode** — listener created but never stored when `DemoMode.isActive` returns early | `Clients/NewsClient.swift` | 68 | **Critical** |
| iOS-P2 | News listener task not properly cancelled in `colockitchenraceApp` | `colockitchenraceApp.swift` | 122, 164-170 | **High** |
| iOS-P3 | JPEG compression loop runs synchronously on main thread — blocks UI during image selection | `Utils/ImagePipeline.swift` | 56-63 | Medium |
| iOS-P4 | `DispatchQueue.main.asyncAfter` prevents view deallocation | `Views/Global/ConfettiCannon.swift` | 21 | Medium |
| iOS-P5 | Computed property `filteredTiles` (array filter) called on every `onChange` re-render — should be memoized in state | `Views/Challenge/ChallengeView.swift` | 42-70, 341-343 | Medium |

### 1.4 Code Quality

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| iOS-Q1 | Auth sign-in post-processing duplicated 3x (~90 lines) across email, Google, Apple flows | `Clients/AuthentificationClient.swift` | 61-352 | Medium |
| iOS-Q2 | `contactUser` computed property always returns `nil` — dead code | `Models/Cohouse.swift` | 43-46 | Low |
| iOS-Q3 | Inconsistent naming: `SigninView` (missing capital I), `AuthentificationClient` (unusual spelling), lowercase `colockitchenraceApp` | Various | — | Low |
| iOS-Q4 | `print()` statements in AppDelegate instead of `Logger` | `colockitchenraceApp.swift` | 53, 60, 78, 85, 93, 109 | Low |
| iOS-Q5 | 7+ instances of swallowed errors across auth, challenges, CKR, news, and home clients | Various | — | Medium |
| iOS-Q6 | `ChallengeTileView` is 200+ lines with 5 computed properties — should be decomposed | `Views/Challenge/ChallengeTileView.swift` | 237-444 | Low |
| iOS-Q7 | Custom `Binding(get:set:)` in `SigninView` instead of `@Bindable` | `Views/Signin/SigninView.swift` | 201-203 | Low |
| iOS-Q8 | Most views missing `.accessibilityLabel()` and `.accessibilityHint()` | Various | — | Medium |

### 1.5 Testing

- Good TCA `TestStore` coverage: `AppFeatureTests`, `ChallengeFeatureTests`, `CohouseDetailFeatureTests`, `PlanningFeatureTests`, `PaymentSummaryFeatureTests`
- **Gap:** No tests for client implementations (`AuthentificationClient`, `CKRClient`, etc.)
- **Gap:** No integration tests for Firestore operations

---

## 2. Android App (Kotlin / MVI)

### 2.1 Architecture

**Strengths:**
- Clean MVI pattern with `Contract.kt` (State/Intent/Effect), `ViewModel.kt`, `Screen.kt` per feature
- Proper Hilt DI throughout with `@HiltViewModel` and `@Inject constructor`
- Repository pattern with clear interfaces and implementations
- Well-organized navigation via `CKRNavGraph` → `MainScreen` → tab screens

**Issues:**

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| AND-A1 | `AuthRepository.signInWithGoogle()` uses deprecated `GetSignInWithGoogleOption` — requires migration to Credential Manager | `data/repository/AuthRepositoryImpl.kt` | ~80 | Medium |
| AND-A2 | `MainViewModel` holds multiple repository references — could be split into per-tab scoped ViewModels | `ui/home/MainViewModel.kt` | — | Low |

### 2.2 Security

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| AND-S1 | **Hardcoded Stripe test publishable key** in source | `ui/home/registration/RegistrationViewModel.kt` | ~45 | **Critical** |
| AND-S2 | No certificate pinning for Stripe or Firebase network calls | — | — | Medium |
| AND-S3 | `WebView` in `LegalScreen` loads external URL without `setJavaScriptEnabled(false)` verification | `ui/profile/LegalScreen.kt` | — | Medium |
| AND-S4 | ProGuard/R8 rules not reviewed — Stripe/Firebase models may be obfuscated incorrectly | `app/build.gradle.kts` | — | Medium |

### 2.3 Error Handling

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| AND-E1 | Generic `catch (e: Exception)` blocks throughout ViewModels — should catch specific exceptions | Various ViewModels | — | Medium |
| AND-E2 | No global error boundary or crash-safe UI wrapper | — | — | Medium |
| AND-E3 | Network errors displayed as raw exception messages to users | Various | — | Low |

### 2.4 Performance

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| AND-P1 | Image loading via Coil not configured with memory/disk cache limits | — | — | Low |
| AND-P2 | Firestore snapshot listeners not cleaned up on ViewModel `onCleared()` in some cases | Various repositories | — | Medium |
| AND-P3 | No pagination on challenge/news list queries — could be slow with large datasets | Various | — | Medium |

### 2.5 Code Quality

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| AND-Q1 | Duplicate Firestore document mapping logic across repositories | Various | — | Medium |
| AND-Q2 | Some `@Composable` functions exceed 100 lines — should extract sub-compositions | Various Screen files | — | Low |
| AND-Q3 | Missing `@Preview` annotations on many composables | Various | — | Low |

### 2.6 Testing

- Unit test infrastructure present with `./gradlew test`
- **Gap:** Limited test coverage for ViewModels and repositories
- **Gap:** No UI/instrumentation tests

---

## 3. Firebase Cloud Functions (TypeScript)

### 3.1 Architecture

**Strengths:**
- Well-organized module structure: `payment.ts`, `registration.ts`, `account.ts`, `notifications.ts`, `match-cohouses.ts`, `cohouse.ts`, `admin.ts`
- Shared config in `config.ts` with region constant
- Firebase Functions v2 API with typed request handlers
- Jest test suite present

### 3.2 Security

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| CF-S1 | **Registration race condition** — game `cohouseIDs` array update and registration subcollection write are not in a transaction | `src/registration.ts` | 68-73 | **High** |
| CF-S2 | Demo mode bypasses ALL Firestore validation in payment flow — creates real Stripe objects | `src/payment.ts` | 194-196 | Medium |
| CF-S3 | No input validation library (Zod/Joi) — manual validation throughout | Various | — | Medium |
| CF-S4 | No rate limiting on Cloud Functions (callable functions have no built-in rate limits) | Various | — | Medium |

### 3.3 Performance

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| CF-P1 | N+1 query pattern in edition notifications — one Firestore read per cohouse | `src/notifications.ts` | 275-288 | Medium |
| CF-P2 | No caching on Nominatim geocoding calls — could trigger API rate limits | `src/cohouse.ts` | 117 | Medium |
| CF-P3 | Account deletion Storage cleanup uses sequential `for` loop — not atomic, can timeout mid-way | `src/account.ts` | 142-159 | Low |

### 3.4 Code Quality

| ID | Finding | File | Lines | Severity |
|----|---------|------|-------|----------|
| CF-Q1 | Stripe API version hardcoded as string: `"2025-02-24.acacia"` — should be typed constant | `src/payment.ts` | 25 | Low |
| CF-Q2 | Dependencies use caret ranges (`^`) — not pinned for reproducible builds | `package.json` | — | Low |

### 3.5 Testing

- Jest test infrastructure present with `ts-jest`
- `__tests__/` directory exists
- **Gap:** Coverage not measured or enforced

---

## 4. Firestore Security Rules

**File:** `firestore.rules` (263 lines)

### 4.1 Critical Issues

| ID | Finding | Lines | Severity |
|----|---------|-------|----------|
| FR-S1 | **Challenge response update rule has logic bug** — compares `resource.data.cohouseId` with `responseId` (document ID), which will almost never match. Non-admin users effectively cannot update their responses. | 180 | **High** |
| FR-S2 | **`isCohouseMember()` only checks `isSignedIn()`** — any authenticated user can update ANY cohouse document metadata | 101-118 | **High** |

### 4.2 Positive Findings

- Admin access controlled via custom claims (`request.auth.token.admin == true`)
- User document ownership enforced by `authId` matching
- `authId` immutability enforced on update
- Registrations are Cloud Functions-only (blocked from client writes)
- Collection group query rules properly defined for `responses` and `users`

### 4.3 Coverage Summary

| Collection | Create | Read | Update | Delete |
|-----------|--------|------|--------|--------|
| users | Auth check | Owner or admin | Owner or admin | Blocked |
| cohouses | Signed-in | Signed-in | **Any signed-in user (weak)** | Blocked |
| cohouses/users | Member | Signed-in | Member | Blocked |
| ckrGames | Admin | Signed-in | Admin | Admin |
| registrations | CF only | Signed-in | CF only | CF only |
| challenges | Admin | Signed-in | Admin | Admin |
| responses | Signed-in | Signed-in | **Buggy rule** | Blocked |
| news | Admin | Signed-in | Admin | Admin |

---

## 5. Web App (Next.js)

**Status:** Placeholder landing page — minimal attack surface.

| ID | Finding | File | Severity |
|----|---------|------|----------|
| WEB-1 | No ESLint or Prettier configuration | — | Low |
| WEB-2 | No Content-Security-Policy or security headers configured | — | Medium |
| WEB-3 | App Store / Play Store links are placeholders | `app/page.tsx` | Low |
| WEB-4 | Dependencies use caret ranges — not pinned | `package.json` | Low |

**Positives:**
- Static export (`output: "export"`) — no server-side attack surface
- `strict: true` in TypeScript config
- External links use `noopener noreferrer`
- No hardcoded secrets

---

## 6. CI/CD Pipeline (Bitrise)

**File:** `bitrise.yml` (234 lines)

| ID | Finding | Lines | Severity |
|----|---------|-------|----------|
| CI-1 | Uses `sed` to modify Xcode project settings at build time — fragile, should use `.xcconfig` files | 45-51, 106-116 | Medium |
| CI-2 | `-skipPackagePluginValidation -skipMacroValidation` flags skip Swift package security checks | 58 | Medium |
| CI-3 | Google Play service account JSON referenced via URL (`$BITRISEIO_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_URL`) instead of env var — URL may be logged | 207 | Low |

**Positives:**
- Secrets restored from Base64 environment variables (not committed)
- `set -e` enabled in script steps
- Automatic deployment on `main` push is disabled (manual trigger required)
- Proper keystore handling for Android signing

---

## 7. Project Configuration

### 7.1 Firebase Configuration (`firebase.json`)

| ID | Finding | Severity |
|----|---------|----------|
| CFG-1 | **No security headers** (X-Content-Type-Options, X-Frame-Options, HSTS) configured for hosting | Medium |
| CFG-2 | **No cache-control headers** for static assets | Low |
| CFG-3 | No redirects or rewrites configured | Low |

### 7.2 Firebase Projects (`.firebaserc`)

| ID | Finding | Severity |
|----|---------|----------|
| CFG-4 | Only `"staging"` project configured — no separate production project | Medium |

### 7.3 `.gitignore`

- Properly excludes `GoogleService-Info.plist`, `google-services.json`, `.env*`, `.firebase/`
- Xcode, Android, and Node build artifacts covered

### 7.4 Firestore Indexes (`firestore.indexes.json`)

- Field overrides for `responses` collection group queries (status, cohouseId)
- No composite indexes defined yet — monitor for missing index warnings in production

---

## 8. Consolidated Findings Table

### Critical (5)

| ID | Platform | Finding |
|----|----------|---------|
| iOS-S1 | iOS | Hardcoded Stripe publishable key in source |
| iOS-S2 | iOS | Auth state listener never unregistered — memory leak |
| iOS-P1 | iOS | News listener leaked in demo mode |
| AND-S1 | Android | Hardcoded Stripe publishable key in source |
| CF-S1 | Functions | Registration race condition — no transaction |

### High (12)

| ID | Platform | Finding |
|----|----------|---------|
| iOS-S3 | iOS | `@unchecked Sendable` race condition on `currentNonce` |
| iOS-S4 | iOS | `DispatchQueue.main.sync` potential deadlock |
| iOS-S8 | iOS | Firebase App Check not implemented |
| iOS-P2 | iOS | News listener task not cancelled |
| FR-S1 | Firestore | Challenge response update rule logic bug |
| FR-S2 | Firestore | `isCohouseMember()` only checks `isSignedIn()` |
| AND-S3 | Android | WebView JavaScript not explicitly disabled |
| AND-E1 | Android | Generic exception catching in ViewModels |
| AND-P2 | Android | Snapshot listeners not cleaned up on `onCleared()` |
| CF-S3 | Functions | No input validation library |
| CF-S4 | Functions | No rate limiting on callable functions |
| CFG-1 | Config | No security headers on Firebase Hosting |

### Medium (20+)

| ID | Platform | Finding |
|----|----------|---------|
| iOS-A2 | iOS | View-layer `onChange` instead of reducer action |
| iOS-A3 | iOS | Silent error swallowing in refresh |
| iOS-S5 | iOS | Permissive email validation regex |
| iOS-S6 | iOS | Permissive phone validation regex |
| iOS-S7 | iOS | Unimplemented notification deep linking |
| iOS-P3 | iOS | Synchronous JPEG compression on main thread |
| iOS-P4 | iOS | DispatchQueue delays prevent deallocation |
| iOS-P5 | iOS | Un-memoized computed property in view onChange |
| iOS-Q1 | iOS | 90 lines of auth sign-in duplication |
| iOS-Q5 | iOS | 7+ swallowed errors across clients |
| iOS-Q8 | iOS | Missing accessibility labels |
| AND-A1 | Android | Deprecated Google Sign-In API |
| AND-S2 | Android | No certificate pinning |
| AND-S4 | Android | ProGuard rules not verified |
| AND-P3 | Android | No pagination on list queries |
| AND-Q1 | Android | Duplicate Firestore mapping logic |
| CF-S2 | Functions | Demo mode bypasses payment validation |
| CF-P1 | Functions | N+1 query in edition notifications |
| CF-P2 | Functions | No Nominatim rate limiting/caching |
| CI-1 | CI/CD | Fragile `sed` modifications for code signing |
| CI-2 | CI/CD | Swift package validation skipped |
| CFG-4 | Config | No production Firebase project configured |
| WEB-2 | Web | No CSP or security headers |

---

## 9. Prioritized Recommendations

### Immediate (Before Next Release)

1. **Remove hardcoded Stripe keys** from iOS (`colockitchenraceApp.swift:36`) and Android source. Load from Firebase Remote Config or a build-time injected configuration.

2. **Fix auth listener memory leak** in `AuthentificationClient.swift:362-370`. Save the `ListenerRegistration` handle returned by `addStateDidChangeListener` and remove it on cleanup.

3. **Fix news listener leak in demo mode** in `NewsClient.swift:68`. Check `DemoMode.isActive` **before** creating the Firestore snapshot listener.

4. **Fix Firestore rules — challenge response update** (`firestore.rules:180`). Replace `resource.data.cohouseId == responseId` with a correct ownership check.

5. **Fix Firestore rules — cohouse member validation** (`firestore.rules:101-118`). Replace `isSignedIn()` with actual membership verification using `exists()` on the cohouse's users subcollection.

6. **Wrap game registration in a Firestore transaction** (`registration.ts:68-73`). The `cohouseIDs` array update and registration document create should be atomic.

### Soon (Next Sprint)

7. **Implement Firebase App Check** on both iOS and Android to prevent unauthorized API access.

8. **Add security headers** to `firebase.json` hosting configuration (X-Content-Type-Options, X-Frame-Options, HSTS).

9. **Fix `@unchecked Sendable` thread safety** in `AuthentificationClient.swift:396-398`. Use `@MainActor` or a proper lock for `currentNonce`.

10. **Add input validation library** (Zod) to Cloud Functions for consistent request validation.

11. **Add rate limiting** or caching to Nominatim geocoding calls in `cohouse.ts`.

12. **Replace `print()` with `Logger`** in `colockitchenraceApp.swift`.

### Medium Term

13. **Extract shared auth sign-in logic** into a helper function to reduce 90 lines of duplication in `AuthentificationClient.swift`.

14. **Configure separate Firebase production project** in `.firebaserc`.

15. **Move JPEG compression off main thread** in `ImagePipeline.swift`.

16. **Add accessibility labels** throughout iOS and Android UI.

17. **Migrate from deprecated `GetSignInWithGoogleOption`** to Credential Manager on Android.

18. **Replace Bitrise `sed` modifications** with Xcode `.xcconfig` files.

19. **Add ESLint/Prettier** to the web app.

20. **Optimize N+1 notification queries** in `notifications.ts` using collection group queries.

---

*Report generated by automated code audit on 2026-02-22.*
