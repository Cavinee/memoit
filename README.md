# MemoIt — On‑Device AI Notes (iOS)

A privacy‑first notes app where **all AI runs on‑device** via the QVAC SDK — no cloud, no
data leaving the phone. It includes notes with rich text, semantic (embedding‑based)
retrieval, **Find Related Notes**, and an on‑device AI chat.

> Built for the QVAC "Unleash Edge AI" hackathon (Mobile Track).

---

## Repository layout

| Path | What it is |
| --- | --- |
| `Qvac2026/` | The iOS app — native SwiftUI shell + an Expo / React‑Native bare worklet that hosts the QVAC SDK. CocoaPods workspace lives here. |
| `Sources/QVACRuntime/` | The on‑device knowledge runtime (pure Swift package). The app consumes it as a local Swift Package dependency. |
| `Sources/QVACRuntimeBehaviorTests/` | Behavior test suite for the runtime (runs on the Mac, no device needed). |
| `Qvac2026/embedded-qvac-host/` | The bare worklet entry/bundle that runs QVAC generation + embeddings off the main thread. |

---

## Prerequisites

- **macOS** with **Xcode 16 or newer** (the project uses Xcode‑16 project format).
- A **physical iPhone on iOS 17.0+**. QVAC runs on‑device only — **the iOS Simulator is not supported.**
- **Node.js 18+** on your `PATH` (used to build the QVAC SDK worklet during the Xcode build).
- **CocoaPods** — `brew install cocoapods` or `sudo gem install cocoapods`.
- An **Apple ID / development team** for code signing. A free Apple ID works for installing on your own device.

---

## Setup

```bash
# 1. Clone
git clone https://github.com/Cavinee/qvac.git
cd qvac/Qvac2026

# 2. Install JS dependencies (the QVAC SDK + bare worklet runtime)
npm install

# 3. Install CocoaPods dependencies
pod install

# 4. Configure code signing
cp Local.xcconfig.example Local.xcconfig
```

Then edit `Qvac2026/Local.xcconfig` with your own team:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
CODE_SIGN_STYLE  = Automatic
```

Find your Team ID in **Xcode → Settings → Accounts**, or at
[developer.apple.com](https://developer.apple.com/account). `Local.xcconfig` is git‑ignored,
so your team ID never gets committed.

---

## Run it on your iPhone (Xcode — recommended)

1. Open the **workspace**, not the project:
   ```bash
   open Qvac2026/qvac2026.xcworkspace
   ```
2. Plug in your iPhone, tap **Trust** on the device, and enable **Developer Mode**
   (iOS: Settings → Privacy & Security → Developer Mode → on, then reboot).
3. Pick the **`qvac2026`** scheme and select your iPhone as the run destination.
4. In the **`qvac2026`** target → **Signing & Capabilities**, confirm *Automatically manage
   signing* and your Team is selected.
   - Using a **free** Apple ID? Also set a unique **Bundle Identifier** (e.g.
     `com.yourname.memoit`) so Xcode can provision it.
5. Press **Run (⌘R)**. Xcode builds, installs, and launches the app on the device.
6. **First launch** initializes the on‑device model through the QVAC SDK. This can take a
   moment and may need internet **the first time** to fetch the model; after that the app
   runs fully on‑device / offline.

---

## Run it on your iPhone (command line — alternative)

From `Qvac2026/`, find your device's identifier:

```bash
xcrun devicectl list devices        # copy the connected iPhone's identifier (UDID)
```

Build, install, and launch (replace `<DEVICE_UDID>`, and the bundle id if you changed it):

```bash
xcodebuild \
  -workspace qvac2026.xcworkspace \
  -scheme qvac2026 \
  -configuration Debug \
  -destination 'id=<DEVICE_UDID>' \
  -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates \
  build

xcrun devicectl device install app --device <DEVICE_UDID> \
  build/DerivedData/Build/Products/Debug-iphoneos/qvac2026.app

xcrun devicectl device process launch --device <DEVICE_UDID> com.nullabs.memoit
```

---

## Run the runtime tests (optional, no device)

The on‑device knowledge runtime has a pure‑Swift behavior suite:

```bash
# from the repo root
swift run qvac-runtime-tests
```

---

## Troubleshooting

- **"No such module" / Pod errors** — run `pod install` inside `Qvac2026/`, and always open
  `qvac2026.xcworkspace` (never `qvac2026.xcodeproj`).
- **"node: command not found" during build** — make sure `node` is on your `PATH`. The build
  resolves Node via `.xcode.env`; if needed create `Qvac2026/.xcode.env.local` containing
  `export NODE_BINARY=$(command -v node)`.
- **Signing / provisioning errors** — set `DEVELOPMENT_TEAM` in `Local.xcconfig` and use a
  unique bundle identifier. On the device you may need to trust the developer profile:
  Settings → General → VPN & Device Management.
- **AI features error on first run** — confirm the device has internet for the one‑time model
  fetch; afterward the QVAC SDK caches the model and works offline.
- **Trying to use the Simulator** — not supported. Use a physical iPhone on iOS 17.0+.

---

## For contributors

The bare worklet that hosts on‑device generation and embeddings is **pre‑bundled** at
`Qvac2026/qvac2026/embedded-qvac-host/answer-worker.bundle.js`. If you change the worklet
entry (`Qvac2026/embedded-qvac-host/answer-worker.entry.mjs`), re‑bundle it (via `bare-pack`)
and commit the regenerated bundle — a stale bundle causes the AI features to fail at runtime.
You can sanity‑check the embedded host with:

```bash
cd Qvac2026
npm run validate:embedded-qvac-host
```
