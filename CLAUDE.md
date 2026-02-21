# CLAUDE.md - Colocs Kitchen Race

## Project Overview

Colocs Kitchen Race (CKR) is a mobile app for organizing community dining events in Brussels, Belgium. Cohouses (shared living communities) register for game editions and get matched into groups rotating through apero, dinner, and party events. Users earn points via challenges and compete on leaderboards.

**Repo:** https://github.com/Jju17/ColocKitchenRace
**Bundle IDs:** `dev.rahier.colockitchenrace` (iOS main + Android), `dev.rahier.ckradmin` (iOS admin)

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
│   ├── app/src/main/java/dev/rahier/colockitchenrace/
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
xcodebuild -project ios/ColocsKitchenRace.xcodeproj -scheme colockitchenrace -destination generic/platform=iOS build
```

Schemes: `colockitchenrace` (main app), `CKRAdmin` (admin app)

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
xcodebuild -project ios/ColocsKitchenRace.xcodeproj -scheme colockitchenrace -derivedDataPath DerivedData test
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
- `registerForGame` - Game registration + Stripe PaymentIntent creation
- `createPaymentIntent` - Server-side price validation
- `getMyPlanning` - Returns personalized event schedule
- `matchCohouses` - Runs matching algorithm (groups of 4)
- `revealPlanning` - Makes matching results visible to users
- `sendNotification*` - FCM notification distribution
- `deleteAccount` - User account cleanup
- `checkDuplicateCohouse` - Duplicate detection
- `validateAddress` - Geocoding via OpenStreetMap

## Firestore Collections
- `/users/{userId}` - User profiles (authId-bound)
- `/cohouses/{cohouseId}` - Communities with `/users` subcollection
- `/ckrGames/{gameId}` - Game editions with `/registrations` subcollection
- `/challenges/{challengeId}` - Challenges with `/responses` subcollection
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
