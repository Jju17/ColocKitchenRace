# CLAUDE.md - Colocs Kitchen Race

## Project Overview

Colocs Kitchen Race (CKR) is a mobile app for organizing community dining events in Brussels, Belgium. Cohouses (shared living communities) register for game editions and get matched into groups rotating through apero, dinner, and party events. Users earn points via challenges and compete on leaderboards.

**Repo:** https://github.com/Jju17/ColocKitchenRace
**Bundle IDs:** `dev.rahier.colocskitchenrace` (iOS main + Android), `dev.rahier.ckradmin` (iOS admin)

## Tech Stack

### iOS (Main App + CKRAdmin)
- **Language:** Swift (6.1+)
- **UI:** SwiftUI
- **Architecture:** The Composable Architecture (TCA) with `@Reducer` macro
- **State:** `@ObservableState`, `@Shared` for global state, `@Dependency` for DI
- **Auth:** Firebase Auth (Google Sign-In + Apple Sign-In)
- **Database:** Firestore (real-time listeners)
- **Storage:** Firebase Storage (images)
- **Payments:** Stripe (PaymentSheet)
- **Notifications:** Firebase Cloud Messaging (FCM)
- **Crash reporting:** Firebase Crashlytics
- **Modals:** MijickPopups

### Android
- **Language:** Kotlin
- **UI:** Jetpack Compose + Material 3
- **Architecture:** MVI (ViewModel + State + Intent + Effect)
- **DI:** Hilt
- **Auth:** Firebase Auth (Credential Manager for Google, OAuthProvider for Apple)
- **Database:** Firestore
- **Storage:** Firebase Storage
- **Payments:** Stripe Android SDK (PaymentSheet)
- **Notifications:** Firebase Cloud Messaging (FCM)
- **Crash reporting:** Firebase Crashlytics
- **Image loading:** Coil

### Web (Next.js)
- **Language:** TypeScript
- **Framework:** Next.js 14+ (App Router)
- **Status:** Placeholder / landing page

### Backend (Firebase Cloud Functions)
- **Language:** TypeScript, Node 22
- **Runtime:** Firebase Cloud Functions v2 (region: `europe-west1`)
- **Database:** Firestore
- **Payments:** Stripe server-side integration
- **Package manager:** npm

## Project Structure

```
ColocKitchenRace/
├── ios/                              # iOS apps
│   ├── ColocKitchenRace/             # Main iOS app
│   │   ├── App.swift                 # TCA root reducer (AppFeature)
│   │   ├── Views/                    # Feature-based UI
│   │   ├── Models/                   # App-specific models
│   │   ├── Clients/                  # Service layer
│   │   └── Utils/                    # Helpers
│   ├── CKRAdmin/                     # Admin iOS app
│   ├── Shared/                       # Code shared between iOS targets
│   │   ├── Models/                   # Common models
│   │   ├── Clients/                  # Shared client logic
│   │   └── Utils/                    # Common utilities
│   ├── ColocsKitchenRace.xcodeproj/  # Xcode project
│   └── ColocsKitchenRaceTests/       # iOS XCTest suite
├── android/                          # Android app
│   ├── app/src/main/java/dev/rahier/colocskitchenrace/
│   │   ├── data/model/               # Data models (Kotlin)
│   │   ├── data/repository/          # Repository interfaces + implementations
│   │   ├── di/                       # Hilt DI modules
│   │   ├── ui/                       # Compose screens (MVI pattern)
│   │   │   ├── auth/                 # Sign-in, email verification, profile completion
│   │   │   ├── home/                 # Home tab + registration
│   │   │   ├── challenges/           # Challenges tab + leaderboard
│   │   │   ├── planning/             # Planning tab
│   │   │   ├── cohouse/              # Cohouse tab
│   │   │   ├── profile/              # User profile
│   │   │   └── components/           # Shared UI components
│   │   └── util/                     # Utilities
│   └── app/build.gradle.kts
├── web/                              # Next.js web app
│   ├── app/                          # App Router pages
│   └── package.json
├── functions/                        # Firebase Cloud Functions
│   ├── src/                          # TypeScript source
│   └── __tests__/                    # Jest tests
├── firestore.rules                   # Firestore security rules
├── firestore.indexes.json            # Firestore composite indexes
└── firebase.json                     # Firebase project config
```

## Build & Run

### iOS App
```bash
cd ios
open ColocsKitchenRace.xcodeproj

# Build from CLI
xcodebuild -project ios/ColocsKitchenRace.xcodeproj -scheme colocskitchenrace -destination generic/platform=iOS build
```

Schemes: `colocskitchenrace` (main app), `CKRAdmin` (admin app)

### Android App
```bash
cd android
./gradlew assembleDebug

# Run tests
./gradlew test
```

### Web App
```bash
cd web
npm install
npm run dev      # Dev server on port 3000
npm run build    # Production build
```

### Backend
```bash
cd functions
npm install
npm run build          # Compile TypeScript
npm test               # Run Jest tests
npm run serve          # Build + start Firebase emulators
firebase deploy --only functions  # Deploy to production
```

### iOS Tests
```bash
xcodebuild -project ios/ColocsKitchenRace.xcodeproj -scheme colocskitchenrace -derivedDataPath DerivedData test
```

## Architecture & Conventions

### iOS - TCA Pattern
- Each feature has a `*Feature.swift` reducer and a `*View.swift` view
- Root flow: `AppFeature` -> `TabFeature` -> individual feature reducers
- Clients use `@DependencyClient` for testability
- Tests use TCA's `TestStore` for exhaustive action/state verification
- Naming: `FeatureNameFeature.swift` (reducer), `FeatureNameView.swift` (view), `ServiceNameClient.swift` (client)
- Shared components go in `Views/Global/`

### Android - MVI Pattern
- Each feature has a `*Contract.kt` (State/Intent/Effect), `*ViewModel.kt`, and `*Screen.kt`
- Root flow: `CKRNavGraph` -> `MainScreen` (tabs) -> individual screens
- Repository pattern for data layer, injected via Hilt
- `@HiltViewModel` for all ViewModels
- Naming: `FeatureNameScreen.kt` (UI), `FeatureNameViewModel.kt` (logic), `FeatureNameContract.kt` (MVI contract)

### Demo Mode
- Test account: `test_apple@colocskitchenrace.be`
- `DemoMode` provides mock data for App Store / Play Store review
- Bypasses Firestore/Cloud Functions when active
- Uses stable UUIDs for cross-model references

### Logging
- iOS: Custom `Logger` extension with domain-specific loggers: `Logger.authLog`, `Logger.ckrLog`, etc.
- Android: Android `Log` with tag-based logging

## Cloud Functions (Key Endpoints)

### Registration & Payment
- `reserveAndCreatePayment` - Atomically reserves a spot (Firestore transaction) + creates Stripe PaymentIntent
- `confirmRegistration` - Confirms a pending registration after Stripe payment succeeds
- `releaseExpiredReservation` - Cloud Task handler that frees expired pending reservations
- `cancelReservation` - Immediately cancels a pending reservation (called on PaymentSheet dismiss)

### Game Management
- `matchCohouses` - Runs matching algorithm (groups of 4)
- `updateEventSettings` - Saves event time slots + party info
- `confirmMatching` - Assigns A/B/C/D roles within each group
- `revealPlanning` - Makes matching results visible + schedules event reminder Cloud Tasks
- `getMyPlanning` - Returns personalized event schedule for a cohouse
- `deleteCKRGame` - Admin-only: deletes a game + all subcollections (registrations, notification markers)

### Push Notifications
- `onCKRGameCreated` - Firestore trigger: sends "registrations open" + schedules game start reminders
- `sendGameReminder24h` - Cloud Task: "La CKR, c'est demain !" (24h before)
- `sendGameReminder1h` - Cloud Task: "La CKR, c'est dans 1 heure !" (1h before)
- `sendAperoReminder` - Cloud Task: personalized host/visitor apero reminder (15 min before)
- `sendDinerReminder` - Cloud Task: personalized host/visitor dinner reminder (15 min before)
- `sendPartyReminder` - Cloud Task: party reminder to all registered (15 min before)
- `onNewsCreated` - Firestore trigger: notifies all users when news is published
- `onChallengeCreated` - Firestore trigger: notifies all users when a challenge is created
- `checkChallengeSchedules` - Scheduler (every 5 min): challenge start/end reminders
- `sendNotificationToCohouse` / `sendNotificationToEdition` / `sendNotificationToAll` - Admin manual FCM distribution

### Other
- `deleteAccount` - User account cleanup
- `checkDuplicateCohouse` - Duplicate detection
- `validateAddress` - Geocoding via OpenStreetMap
- `setCohouseClaim` / `setAdminClaim` - Custom claims management

## Registration Flow (Reserve-Then-Pay)

The registration flow uses a **reserve-then-pay** pattern to prevent race conditions when many cohouses register simultaneously (~300 concurrent registrations). A spot is atomically reserved before any payment is attempted, guaranteeing that a paying user will never be refused a place.

### Flow Overview

```
Client                          Backend                              Stripe
  │                               │                                    │
  │  1. reserveAndCreatePayment   │                                    │
  │──────────────────────────────▶│                                    │
  │                               │── Firestore Transaction ──────┐   │
  │                               │  • Validate deadline/capacity │   │
  │                               │  • Create registration (pending)  │
  │                               │  • Reserve participant slots  │   │
  │                               │◀───────────────────────────────┘   │
  │                               │                                    │
  │                               │  2. Create PaymentIntent           │
  │                               │───────────────────────────────────▶│
  │                               │◀───────────────────────────────────│
  │                               │                                    │
  │                               │  3. Schedule Cloud Task (+15min)   │
  │                               │                                    │
  │  ◀── PaymentIntent result ────│                                    │
  │                               │                                    │
  │  4. Present PaymentSheet ─────────────────────────────────────────▶│
  │  ◀── Payment succeeded ───────────────────────────────────────────│
  │                               │                                    │
  │  5. confirmRegistration       │                                    │
  │──────────────────────────────▶│                                    │
  │                               │── Verify payment with Stripe ────▶│
  │                               │◀──────────────────────────────────│
  │                               │── Transaction: pending → confirmed │
  │  ◀── success ─────────────────│                                    │
```

### Key Mechanisms

- **Atomic reservation** (`reserveAndCreatePayment`): A Firestore transaction validates game constraints (deadline, capacity, duplicate) and creates a `pending` registration with a 15-minute TTL, all atomically. If Stripe PaymentIntent creation fails afterward, the reservation is rolled back immediately.

- **Confirmation** (`confirmRegistration`): After the Stripe PaymentSheet completes, the client calls this to transition the registration from `pending` to `confirmed`. Verifies payment status via Stripe API. If the 15-minute TTL has expired, the confirmation is rejected.

- **Automatic cleanup** (`releaseExpiredReservation`): A Cloud Task is scheduled for each reservation to fire 15 minutes later. If the registration is still `pending` (payment never completed), it deletes the registration doc and frees the reserved spots. Idempotent — skips if already confirmed or deleted.

- **Matching guard**: `matchCohouses` refuses to run if any registrations are still in `pending` status, ensuring all participants have completed payment before groups are formed.

### Registration Document States

| Status | Meaning |
|--------|---------|
| `pending` | Spot reserved, awaiting payment. Has `reservedUntil` timestamp. |
| `confirmed` | Payment verified, registration complete. Cleanup fields removed. |
| *(deleted)* | Reservation expired or was rolled back. Spots freed on game doc. |

### Files Involved

| Layer | Files |
|-------|-------|
| **Backend** | `functions/src/payment.ts`, `functions/src/registration.ts`, `functions/src/cleanup.ts` |
| **iOS** | `StripeClient.swift` → `CKRClient.swift` → `PaymentSummaryView.swift` |
| **Android** | `StripeRepository.kt` → `CKRGameRepository.kt` → `PaymentSummaryViewModel.kt` |

## Push Notifications System

The app uses **Firebase Cloud Messaging (FCM)** with two delivery patterns:
- **Topic-based** (`"all_users"`) — for broadcast notifications (news, challenge, registration open)
- **Token-based** (`sendToTokens`) — for targeted per-cohouse notifications (game reminders, event step reminders)

All scheduled notifications use **Cloud Tasks** (one-shot, fire-and-forget) rather than a permanently running scheduler. This is the same pattern as `releaseExpiredReservation`.

### Notification Types

| # | Type | Trigger | Target | Timing |
|---|------|---------|--------|--------|
| 1 | Registration open | `onCKRGameCreated` (Firestore trigger) | All users (topic) | Immediate |
| 2 | Game in 24h | `sendGameReminder24h` (Cloud Task) | Registered users (tokens) | 24h before `nextGameDate` |
| 3 | Game in 1h | `sendGameReminder1h` (Cloud Task) | Registered users (tokens) | 1h before `nextGameDate` |
| 4 | Apero reminder | `sendAperoReminder` (Cloud Task) | Per-cohouse, personalized host/visitor (tokens) | 15 min before `aperoStartTime` |
| 5 | Diner reminder | `sendDinerReminder` (Cloud Task) | Per-cohouse, personalized host/visitor (tokens) | 15 min before `dinerStartTime` |
| 6 | Party reminder | `sendPartyReminder` (Cloud Task) | Registered users (tokens) | 15 min before `partyStartTime` |
| 7 | News published | `onNewsCreated` (Firestore trigger) | All users (topic) | Immediate |
| 8 | Challenge created | `onChallengeCreated` (Firestore trigger) | All users (topic) | Immediate |
| 9 | Challenge started | `checkChallengeSchedules` (Scheduler) | All users (topic) | Within 5 min of `startDate` |
| 10 | Challenge ending soon | `checkChallengeSchedules` (Scheduler) | All users (topic) | ~30 min before `endDate` |

### Cloud Tasks Scheduling Flow

```
Game created (onCKRGameCreated)
  ├── Send "registration open" notification (immediate, topic)
  ├── Schedule sendGameReminder24h (Cloud Task, 24h before nextGameDate)
  └── Schedule sendGameReminder1h  (Cloud Task, 1h before nextGameDate)

Planning revealed (revealPlanning)
  └── scheduleEventReminders()
        ├── Schedule sendAperoReminder (Cloud Task, 15 min before aperoStartTime)
        ├── Schedule sendDinerReminder (Cloud Task, 15 min before dinerStartTime)
        └── Schedule sendPartyReminder (Cloud Task, 15 min before partyStartTime)
```

Cloud Tasks are scheduled via `getFunctions().taskQueue("taskName").enqueue(data, { scheduleDelaySeconds })`. Max delay: 30 days.

### Personalized Event Reminders (Host/Visitor)

Apero and diner reminders are **personalized per cohouse** based on the A/B/C/D role schema:

| Step | Host pairs | Host message | Visitor message |
|------|-----------|--------------|-----------------|
| Apero | B hosts A, D hosts C | "Vous recevez {visitor} chez vous" | "Direction chez {host} pour l'apero !" |
| Diner | A hosts C, B hosts D | "Vous recevez {visitor} chez vous" | "Direction chez {host} pour le diner !" |
| Party | *(all users)* | — | "Direction {partyName} pour la suite !" |

### Deduplication Strategy

| Notification type | Deduplication method |
|---|---|
| Registration open, News, Challenge created | `onDocumentCreated` fires exactly once |
| Game 24h/1h, Apero/Diner/Party reminders | Cloud Tasks fire exactly once (no marker needed) |
| Challenge started/ending soon | Marker documents in `challenges/{id}/notifications/{type}` |

### Deletion Safety

All Cloud Task handlers check `if (!gameDoc.exists) return;` at the start. If a CKR game is deleted, any previously scheduled tasks become **no-ops** — no stale notifications are ever sent.

### Files Involved

| Layer | Files |
|-------|-------|
| **Backend (game notifications)** | `functions/src/pushNotifications.ts` |
| **Backend (challenge/news notifications)** | `functions/src/triggers.ts` |
| **Backend (manual admin notifications)** | `functions/src/notifications.ts` |
| **Backend (barrel exports)** | `functions/src/index.ts` |

## CKR Game Deletion

Game deletion is handled **server-side** via the `deleteCKRGame` Cloud Function to ensure complete cleanup. The iOS admin app calls this function instead of deleting the Firestore document directly.

### What Gets Cleaned Up

| Data | Path | Method |
|------|------|--------|
| Registration documents | `ckrGames/{gameId}/registrations/*` | Batched delete (500/batch) |
| Notification markers | `ckrGames/{gameId}/notifications/*` | Batched delete (500/batch) |
| Game document | `ckrGames/{gameId}` | Single delete |
| Scheduled Cloud Tasks | *(game reminders, event reminders)* | Graceful no-op (handlers check `gameDoc.exists`) |

### Flow

```
CKRAdmin (iOS)                          Cloud Function
  │                                        │
  │  deleteCKRGame({ gameId })             │
  │───────────────────────────────────────▶│
  │                                        │── Verify admin claim
  │                                        │── Delete registrations subcollection
  │                                        │── Delete notifications subcollection
  │                                        │── Delete game document
  │  ◀── { success: true } ───────────────│
  │                                        │
  │  (Later: scheduled Cloud Tasks fire)   │
  │                                        │── gameDoc.exists? → false → return (no-op)
```

### Files Involved

| Layer | Files |
|-------|-------|
| **Backend** | `functions/src/cleanup.ts` (`deleteCKRGame`) |
| **iOS Admin** | `CKRAdmin/Clients/CKRClient.swift` (`deleteGame`), `CKRAdmin/Views/HomeView.swift` |

## Challenge Participation Flow

Challenges are community tasks that cohouses can complete to earn points. Each challenge has a type that determines the UI and submission content. Participation is **inline on the challenge card** — no separate modal or screen.

### Challenge Types

| Type | Content Model | User Input | Response Content |
|------|---------------|------------|------------------|
| `NoChoice` | No extra data | Single "I've done it!" button tap | `ChallengeResponseContent.NoChoice` |
| `SingleAnswer` | No extra data | Free-text input field | `ChallengeResponseContent.SingleAnswer(text)` |
| `MultipleChoice` | `choices: [String]`, `correctAnswerIndex?`, `shuffleAnswers` | Select one choice from a grid/list | `ChallengeResponseContent.MultipleChoice([selectedIndex])` |
| `Picture` | No extra data | Camera or gallery photo | `ChallengeResponseContent.Picture(storagePath)` |

### Card States (Inline on Challenge Tile)

```
1. Challenge not yet started     → "A venir" badge, no action
2. Challenge active, no response → "Participer" button
3. Participating (form visible)  → Inline form based on challenge type + Submit + Cancel
4. Response submitted, waiting   → Hourglass icon + "En attente de validation"
5. Validated by admin            → Checkmark icon + "Valide !"
6. Invalidated by admin          → X icon + "Invalide"
7. Challenge ended               → "Termine" badge
```

### Submission Flow

```
User taps "Participer"
  ↓
Inline form appears on card (type-specific UI)
  ↓
User fills form + taps "Envoyer"
  ↓
[Picture only] Upload image to Firebase Storage
  → Path: challenges/{challengeId}/responses/{cohouseId}.jpg
  → Image compressed to <1MB JPEG before upload
  ↓
Create ChallengeResponse document in Firestore
  → Path: /challenges/{challengeId}/responses/{cohouseId}
  → Status: "waiting"
  ↓
Card switches to "En attente de validation" state
  ↓
Admin validates/invalidates via CKRAdmin app
  ↓
[iOS] Real-time listener updates card status instantly
[Android] Status reflected on next load
```

### iOS Implementation (TCA)

- **`ChallengeTileFeature.swift`** — TCA Reducer managing the full participation lifecycle per tile. Handles `startTapped`, `submitTapped(ChallengeSubmitPayload)`, real-time status watching via `responseClient.watchStatus()`, and nested `PictureChoiceFeature` for camera/gallery.
- **`ChallengeContentView.swift`** — Router view switching between `NoChoiceView`, `SingleAnswerView`, `MultipleChoiceView`, `PictureChoiceView`.
- **`PictureChoiceFeature.swift`** — Nested TCA reducer for image picking (UIImagePickerController) + compression (`ImagePipeline.compress`).
- **`WaitingReviewView.swift`** / **`FinalStatusView.swift`** — Status display composables.
- **State fields:** `response: ChallengeResponse?`, `isSubmitting`, `submitError`, `liveStatus` (real-time from Firestore listener).
- **Real-time updates:** Each tile watches `responseClient.watchStatus(challengeId, cohouseId)` for instant admin decisions.

### Android Implementation (MVI)

- **`ChallengesViewModel.kt`** — Single ViewModel manages all challenges + participation state. Shared state fields: `participatingChallengeId`, `selectedChoiceIndex`, `textAnswer`, `capturedImageData: ByteArray?`, `isSubmitting`, `submitError`.
- **`ChallengesScreen.kt`** — `ChallengeTileCard` composable renders inline forms: `NoChoiceForm`, `SingleAnswerForm`, `MultipleChoiceForm`, `PictureForm`, `WaitingReviewSection`, `FinalStatusSection`.
- **`ChallengeResponseRepository.kt`** — `submit(response)` writes to Firestore, `uploadImage(challengeId, cohouseId, imageData)` uploads to Firebase Storage.
- **Photo handling:** `ActivityResultContracts.TakePicture` (camera via FileProvider) + `ActivityResultContracts.GetContent` (gallery). Images compressed in ViewModel before storage in state.
- **Intents:** `StartChallenge(id)`, `CancelParticipation`, `SelectChoice(index)`, `TextAnswerChanged(text)`, `PhotoCaptured(bytes)`, `SubmitResponse`.

### Key Differences iOS vs Android

| Aspect | iOS | Android |
|--------|-----|---------|
| Architecture | Per-tile TCA reducer (`ChallengeTileFeature`) | Shared `ChallengesViewModel` with `participatingChallengeId` |
| Real-time status | `watchStatus()` listener per tile | Loaded on screen init (no real-time listener yet) |
| Image picker | UIImagePickerController (camera/library) | `ActivityResultContracts.TakePicture` / `GetContent` |
| Image compression | `ImagePipeline.compress` (custom) | `Bitmap.compress(JPEG, quality, stream)` loop |
| Text input | Bottom sheet modal for SingleAnswer | Inline `OutlinedTextField` |

### Files Involved

| Layer | Files |
|-------|-------|
| **Firestore** | `/challenges/{challengeId}/responses/{cohouseId}` |
| **Storage** | `challenges/{challengeId}/responses/{cohouseId}.jpg` (pictures only) |
| **iOS** | `ChallengeTileFeature.swift`, `ChallengeContentView.swift`, `NoChoiceView.swift`, `SingleAnswerView.swift`, `MultipleChoiceView.swift`, `PictureChoiceView.swift` |
| **Android** | `ChallengesViewModel.kt`, `ChallengesScreen.kt`, `ChallengeResponseRepository.kt`, `ChallengeResponseRepositoryImpl.kt` |
| **Models** | `Challenge.kt`/`Challenge.swift`, `ChallengeContent.kt`/`ChallengeContent.swift`, `ChallengeResponse.kt`/`ChallengeResponse.swift` |

## Firestore Collections
- `/users/{userId}` - User profiles (authId-bound)
- `/cohouses/{cohouseId}` - Communities with `/users` subcollection
- `/ckrGames/{gameId}` - Game editions with `/registrations` and `/notifications` subcollections
- `/challenges/{challengeId}` - Challenges with `/responses` and `/notifications` subcollections
- `/news/{newsId}` - In-app news
- `/notificationHistory/{docId}` - Admin notification logs

## CI/CD (Bitrise)
Config: `bitrise.yml` at project root.

### iOS
- `deploy_testflight` workflow: builds main app -> TestFlight
- `deploy_testflight_admin` workflow: builds CKRAdmin -> TestFlight
- `GoogleService-Info.plist` restored from Base64 secrets at build time

### Android
- `android_test` workflow: runs unit tests (debug variant)
- `deploy_play_store` workflow: builds signed release AAB -> Play Store internal track
- `google-services.json` restored from Base64 secret (`GOOGLE_SERVICES_JSON_BASE64`)
- Keystore restored from Base64 secret (`ANDROID_KEYSTORE_BASE64`)
- Required secrets: `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`

## Important Notes
- All Firebase resources are in `europe-west1` (Belgium)
- Security-sensitive operations (registration, payments, matching) go through Cloud Functions
- Firestore security rules use custom claims (`request.auth.token.admin`) for admin access
- Account deletion must go through Cloud Functions for proper cleanup
- The `DemoMode.swift` file is excluded from the CKRAdmin target
