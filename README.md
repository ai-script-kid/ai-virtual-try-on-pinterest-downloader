# Pinterest Downloader and AI Virtual Try-On iOS App (Swift)

An iOS app to **download Pinterest images & videos** and run an **AI virtual try-on** — drop in a Pinterest clothing pin, pick a photo of yourself, and the app generates a photorealistic image of you wearing the item.

> ⚠️ This repository ships with **placeholder API keys**. You must supply your own credentials (see [Configuration](#configuration)) before the app or backend will work.

## Features

- **Pinterest downloader** — paste a Pinterest pin URL to fetch the original-quality image or video. Saved to the user's photo library and to their personal history.
- **AI Virtual Try-On** — combine a Pinterest clothing pin with a user photo to generate a try-on result (powered by Google's `nano-banana` model via Wiro AI).
- **Anonymous accounts** — no sign-up; each device gets an anonymous Firebase Auth identity.
- **Subscriptions** — free tier allows 1 download; premium unlocks unlimited downloads and a monthly pool of try-on credits. Managed with RevenueCat + StoreKit.
- **Per-user history** — downloads and try-on results stored privately per user in Firestore.

## Tech Stack

### iOS app
- **SwiftUI** (iOS 17+), Swift 5.9
- **MVVM** architecture (`Views` / `ViewModels` / `Services` / `Models`)
- [**Firebase iOS SDK**](https://github.com/firebase/firebase-ios-sdk) — Auth (anonymous), Firestore, Storage, Functions
- [**RevenueCat**](https://github.com/RevenueCat/purchases-ios) — subscription management & paywall
- [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) — project generation from `project.yml`

### Backend (`functions/`)
- **Firebase Cloud Functions** (Gen 2), Node.js 22
- `firebase-admin`, `firebase-functions`, `node-fetch`, `form-data`
- External APIs: **RapidAPI** (Pinterest downloader), **Wiro AI** (image generation)

### Data model (Firestore)
```
users/{uid}
  ├─ isPremium: bool
  ├─ tryOnCredits: number
  ├─ downloads/{id}   → { pinUrl, imageUrl, videoUrl, thumbnailUrl, isVideo, title, createdAt }
  └─ tryons/{id}      → { clothingImageUrl, resultUrl, createdAt }
```
Security rules (`firestore.rules`, `storage.rules`) restrict every document to its owning user; privileged writes happen only from Cloud Functions via the Admin SDK.

## Cloud Functions

| Function | Type | Purpose |
|---|---|---|
| `downloadPin` | Callable | Resolves a Pinterest URL via RapidAPI, enforces the free/premium download limit, stores the result. |
| `tryOn` | Callable | Atomically checks premium + deducts a credit, submits the job to Wiro AI, polls for the result (≤150s), stores the output. |
| `revenuecatWebhook` | HTTP | Receives RevenueCat events (purchase/renew/expire) and updates `isPremium` + `tryOnCredits`. Auth via shared bearer secret. |
| `updateSubscriptionStatus` | Callable | Lets the client sync premium status as a fallback. |

Credit grants per product: `pinweekly` → 20, `pinyearly` → 300 (see `PRODUCT_CREDITS` in `functions/index.js`).

## Configuration

All secrets have been replaced with placeholders. Provide your own:

### 1. Firebase (`GoogleService-Info.plist`)
The root and `PinSave/GoogleService-Info.plist` files are placeholders. Download your real config from the **Firebase Console → Project Settings → Your apps → iOS app** and replace both files. Also set your project ID in `.firebaserc`.

### 2. RevenueCat (iOS) — `PinSave/App/PinSaveApp.swift`
```swift
Purchases.configure(withAPIKey: "REVENUECAT_PUBLIC_SDK_KEY_HERE")
```
Replace with your RevenueCat **public** iOS SDK key (this one is safe to ship in the client).

### 3. Backend secrets — `functions/index.js`
| Placeholder | Where to get it |
|---|---|
| `RAPIDAPI_KEY_HERE` | [RapidAPI](https://rapidapi.com) — the Pinterest Downloader API |
| `WIRO_API_KEY_HERE` | [Wiro AI](https://wiro.ai) dashboard → project API key |
| `WIRO_API_SECRET_HERE` | Wiro AI dashboard → project API secret |
| `REVENUECAT_WEBHOOK_SECRET_HERE` | A secret you define, also set as the Authorization bearer token in your RevenueCat webhook config |

> For production, move these out of source and into [Firebase secrets / environment config](https://firebase.google.com/docs/functions/config-env) rather than hardcoding.

### 4. App Store / StoreKit
Configure subscription products in App Store Connect and RevenueCat. Product IDs used by the app: `pinweekly`, `pinyearly`.

### 5. Signing
`DEVELOPMENT_TEAM` is blank in `project.yml` / `project.pbxproj`. Set your own Apple Developer Team ID in Xcode before building to a device.

## Getting Started

### App
```bash
# Generate the Xcode project (requires XcodeGen)
xcodegen generate

# Open and run
open PinSave.xcodeproj
```
Then drop in your `GoogleService-Info.plist`, set your signing team, and build to a simulator or device.

### Backend
```bash
cd functions
npm install
firebase deploy --only functions
```
Make sure `.firebaserc` points at your Firebase project and your secrets are configured.

## Project Structure
```
.
├── PinSave/                 # SwiftUI app
│   ├── App/                 # Entry point, app state, root view
│   ├── Models/              # Data models
│   ├── Services/            # Subscription service, etc.
│   ├── ViewModels/          # Home, Downloads, TryOn view models
│   ├── Views/               # Home, Downloads, TryOn, Paywall, Settings
│   └── GoogleService-Info.plist  # ← replace with your own
├── functions/               # Firebase Cloud Functions (Node.js)
├── firestore.rules          # Firestore security rules
├── storage.rules            # Storage security rules
├── project.yml              # XcodeGen project definition
└── .firebaserc / firebase.json
```

## License

No license specified. Add one if you intend others to reuse this code.
