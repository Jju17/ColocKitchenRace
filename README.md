# Colocs Kitchen Race

A mobile app for organizing community dining events in Brussels, Belgium. Cohouses (shared living communities) register for game editions and get matched into groups rotating through apero, dinner, and party events. Users earn points via challenges and compete on leaderboards.

## Project Structure

```
ColocKitchenRace/
├── ios/                  # iOS apps (SwiftUI + TCA)
│   ├── ColocKitchenRace/ # Main iOS app
│   ├── CKRAdmin/         # Admin iOS app
│   ├── Shared/           # Shared code between iOS targets
│   └── ColocsKitchenRaceTests/
├── android/              # Android app (Kotlin + Jetpack Compose)
│   └── app/
├── web/                  # Web app (Next.js)
├── functions/            # Firebase Cloud Functions (TypeScript)
├── firestore.rules       # Firestore security rules
├── firestore.indexes.json
└── firebase.json
```

## Quick Start

### iOS
```bash
cd ios
open ColocsKitchenRace.xcodeproj
# Build scheme: colockitchenrace (main) or CKRAdmin (admin)
```

### Android
```bash
cd android
./gradlew assembleDebug
```

### Backend (Cloud Functions)
```bash
cd functions
npm install
npm run build
npm test
npm run serve    # Start Firebase emulators
```

### Web
```bash
cd web
npm install
npm run dev      # Start dev server on port 3000
```

## Tech Stack

| Platform | Language | UI Framework | Architecture |
|----------|----------|-------------|--------------|
| iOS | Swift 6.1+ | SwiftUI | TCA (The Composable Architecture) |
| Android | Kotlin | Jetpack Compose | MVI (ViewModel + State + Intent) |
| Web | TypeScript | Next.js + React | - |
| Backend | TypeScript | - | Firebase Cloud Functions v2 |

**Shared Services:** Firebase Auth, Firestore, Cloud Storage, FCM, Stripe

## Firebase

- **Project region:** `europe-west1` (Belgium)
- **Auth providers:** Email/Password, Google Sign-In, Apple Sign-In
- **Payments:** Stripe (server-side validation via Cloud Functions)

## Repo

https://github.com/Jju17/ColocKitchenRace
