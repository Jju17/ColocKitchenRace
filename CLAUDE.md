# CLAUDE.md - Colocs Kitchen Race

## Project Overview

Colocs Kitchen Race (CKR) is an iOS app for organizing community dining events in Brussels, Belgium. Cohouses (shared living communities) register for game editions and get matched into groups rotating through apero, dinner, and party events. Users earn points via challenges and compete on leaderboards.

**Repo:** https://github.com/Jju17/ColocKitchenRace
**Bundle IDs:** `dev.rahier.colockitchenrace` (main), `dev.rahier.ckradmin` (admin)

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

### Backend (Firebase Cloud Functions)
- **Language:** TypeScript, Node 22
- **Runtime:** Firebase Cloud Functions v2 (region: `europe-west1`)
- **Database:** Firestore
- **Payments:** Stripe server-side integration
- **Package manager:** npm

## Project Structure

```
ColocKitchenRace/
├── ColocKitchenRace/         # Main iOS app
│   ├── App.swift             # TCA root reducer (AppFeature)
│   ├── Views/                # Feature-based UI (Home, Planning, Challenge, Cohouse, Signin, Signup, UserProfile)
│   ├── Models/               # App-specific models
│   ├── Clients/              # Service layer (CKRClient, AuthentificationClient, ChallengesClient, etc.)
│   └── Utils/                # Helpers (Logger, Date, View extensions)
├── CKRAdmin/                 # Admin iOS app (separate target, same Xcode project)
├── Shared/                   # Code shared between main app and admin
│   ├── Models/               # Common models (Challenge, CKRGame, User, Cohouse, etc.)
│   ├── Clients/              # Shared client logic
│   └── Utils/                # Common utilities
├── functions/                # Firebase Cloud Functions (TypeScript)
│   ├── src/                  # Source (index.ts, registration.ts, planning.ts, payment.ts, matching.ts, etc.)
│   └── __tests__/            # Jest tests
├── ColocsKitchenRaceTests/   # iOS XCTest suite (23 test files)
├── firestore.rules           # Firestore security rules
├── firestore.indexes.json    # Firestore composite indexes
├── firebase.json             # Firebase project config
└── bitrise.yml               # CI/CD config
```

## Build & Run

### iOS App
```bash
# Open in Xcode
open ColocsKitchenRace.xcodeproj

# Build from CLI
xcodebuild -project ColocsKitchenRace.xcodeproj -scheme colockitchenrace -destination generic/platform=iOS build
```

Schemes: `colockitchenrace` (main app), `CKRAdmin` (admin app)

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
xcodebuild -project ColocsKitchenRace.xcodeproj -scheme colockitchenrace -derivedDataPath DerivedData test
```

## Architecture & Conventions

### TCA Pattern
- Each feature has a `*Feature.swift` reducer and a `*View.swift` view
- Root flow: `AppFeature` -> `TabFeature` -> individual feature reducers
- Clients use `@DependencyClient` for testability
- Tests use TCA's `TestStore` for exhaustive action/state verification

### Naming
- Reducers: `FeatureNameFeature.swift` (e.g., `SignupFeature.swift`)
- Views: `FeatureNameView.swift` (e.g., `SignupView.swift`)
- Clients: `ServiceNameClient.swift` (e.g., `ChallengesClient.swift`)
- Shared components go in `Views/Global/`

### Logging
Custom `Logger` extension with domain-specific loggers: `Logger.authLog`, `Logger.ckrLog`, etc.

### Demo Mode
- Test account: `test_apple@colocskitchenrace.be`
- `DemoMode` enum provides mock data for Apple App Review
- Bypasses Firestore/Cloud Functions when active
- Uses stable UUIDs for cross-model references

## Cloud Functions (Key Endpoints)
- `registerForGame` - Game registration + Stripe PaymentIntent creation
- `createPaymentIntent` - Server-side price validation
- `getMyPlanning` - Returns personalized event schedule
- `matchCohouses` - Runs matching algorithm (groups of 4)
- `revealPlanning` - Makes matching results visible to users
- `sendNotification*` - FCM notification distribution
- `deleteAccount` - User account cleanup

## Firestore Collections
- `/users/{userId}` - User profiles (authId-bound)
- `/cohouses/{cohouseId}` - Communities with `/users` subcollection
- `/ckrGames/{gameId}` - Game editions with `/registrations` subcollection
- `/challenges/{challengeId}` - Challenges with `/responses` subcollection
- `/news/{newsId}` - In-app news
- `/notificationHistory/{docId}` - Admin notification logs

## CI/CD (Bitrise)
- `deploy_testflight` workflow: builds main app -> TestFlight
- `deploy_testflight_admin` workflow: builds CKRAdmin -> TestFlight
- `GoogleService-Info.plist` restored from Base64 secrets at build time
- SPM dependencies cached between builds

## Important Notes
- All Firebase resources are in `europe-west1` (Belgium)
- Security-sensitive operations (registration, payments, matching) go through Cloud Functions, not direct Firestore writes
- Firestore security rules use custom claims (`request.auth.token.admin`) for admin access
- Account deletion must go through Cloud Functions for proper cleanup
- The `DemoMode.swift` file is excluded from the CKRAdmin target
