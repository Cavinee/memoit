# QVAC Smoke Host

Standalone physical-iPhone smoke host for Issue 13. This is intentionally separate from the SwiftUI app. It proves the QVAC Expo/Bare path on a real iPhone before Issue 14 embeds a host behind `AIRuntimeAdapter`.

## What This Tests

- `@qvac/sdk` can load a local model on a physical iPhone.
- The model can generate one non-empty response locally.
- The same smoke flow can be repeated after setup with network disabled.
- The observed host path is `embeddedExpoBareRuntime`.

The app does not display or log generated prose. It reports content-free fields such as `generatedTextNonEmpty`, token count, model metadata, and pass/fail status.

## Requirements

- Physical iPhone, iOS 17 or newer.
- Xcode with a signing team configured.
- Node.js 22.17 or newer.
- npm.
- The iPhone connected over USB or otherwise available to Xcode.

QVAC does not support iOS Simulator/emulators for this path.

## Install And Run

Connect the iPhone, unlock it, and trust this Mac if prompted.

On the iPhone, enable Developer Mode before running the installer:

`Settings > Privacy & Security > Developer Mode > On`

The iPhone will restart. After restart, confirm Developer Mode, unlock the phone, and keep it connected.

From the repo root:

```bash
cd qvac-smoke-host
npm run ios:device
```

The script will:

1. check that Xcode can see a physical iPhone,
2. fail early if Developer Mode is disabled or the phone is unavailable,
3. install npm dependencies,
4. align Expo native module versions for the installed SDK,
5. validate this smoke host scaffold,
6. run `npx expo prebuild --platform ios`,
7. run `xcodebuild` with automatic provisioning updates enabled,
8. build a Release iPhone app with the JavaScript bundle embedded,
9. install and launch the signed app on the connected iPhone with `devicectl`.

The installer fails before installation if the built `.app` does not contain `main.jsbundle`, because an app without that embedded JavaScript bundle cannot cold-launch in Airplane Mode.

If the generated Xcode project does not already contain your team ID, run:

```bash
QVAC_SMOKE_DEVELOPMENT_TEAM=<your-team-id> npm run ios:device
```

The installer auto-detects the connected physical iPhone, so the normal flow should not require picking a destination manually. It builds `Release` by default because Debug React Native builds depend on Metro and cannot cold-launch in Airplane Mode.

To override the build configuration for debugging only:

```bash
QVAC_SMOKE_CONFIGURATION=Debug npm run ios:device
```

Do not use Debug for the offline repeat check.

If the app installs but iOS refuses to launch it with a message about an untrusted profile, trust the developer profile on the iPhone:

`Settings > General > VPN & Device Management > Developer App > Trust`

Then tap `QVAC Smoke Host` on the iPhone, or rerun `npm run ios:device`.

## Clean Up The Borrowed iPhone

When you are done testing, remove only the smoke host app from the connected iPhone:

```bash
cd qvac-smoke-host
npm run ios:uninstall
```

This uninstalls bundle ID `dev.qvac.smokehost`. It does not touch the main QVAC app, photos, files, settings, or any other apps on the phone.

## Smoke Flow

1. Keep networking enabled for the first run so QVAC can download/cache the model if needed.
2. Tap `Run Smoke Test`.
3. Confirm the result shows:
   - `status: validatedOnPhysicalDevice`
   - `hostPath: embeddedExpoBareRuntime`
   - `generatedTextNonEmpty: true`
4. Enable Airplane Mode after the model setup completes.
5. Fully close and reopen `QVAC Smoke Host` while still in Airplane Mode.
6. Turn on `Offline repeat` in the smoke host UI.
7. Tap `Run Smoke Test` again.

Expected offline result:

- `status: validatedOnPhysicalDevice`
- `generatedTextNonEmpty: true`
- `offlineRepeatabilityChecked: true`
- `networkDisabledRepeat: passed`

If Airplane Mode launch shows `No script url provided`, reinstall with `npm run ios:device`. That error means the installed build was a Debug/Metro-dependent build or otherwise missing the embedded JavaScript bundle.
6. Confirm local generation still reports `generatedTextNonEmpty: true`.

## Report Back

Report this shape:

```text
status: validatedOnPhysicalDevice
hostPath: embeddedExpoBareRuntime
device: <iPhone model and iOS version>
installPath: Xcode development install
modelProfile.identifier: LLAMA_3_2_1B_INST_Q4_0
modelProfile.name: Llama 3.2 1B Instruct Q4_0
modelProfile.source: QVAC quickstart constant
generatedTextNonEmpty: true
offlineRepeatabilityChecked: true
networkDisabledRepeat: passed
contentFreeLogsCaptured: true
notes: <setup issues, first-token latency, memory pressure, or error categories>
```

Do not report generated prose from private prompts. This smoke app uses a generic prompt, but the product rule is still content-free diagnostics.

## Troubleshooting

- If the app runs on Simulator, stop and choose a physical iPhone.
- If the script says Developer Mode is disabled, enable it at `Settings > Privacy & Security > Developer Mode`, restart, confirm, unlock, and rerun.
- If Xcode says the device is unavailable, reconnect the phone and open `Xcode > Window > Devices and Simulators` until the phone appears as ready.
- If Node is rejected, install Node.js 22.17 or newer.
- If signing says no provisioning profile exists, rerun `npm run ios:device`; the installer now passes `-allowProvisioningUpdates` so Xcode can create the development profile.
- If signing still fails because no team is configured, run `QVAC_SMOKE_DEVELOPMENT_TEAM=<your-team-id> npm run ios:device`, or open `ios/QVACSmokeHost.xcworkspace` in Xcode and choose your team under Signing & Capabilities.
- If launch fails because the profile has not been explicitly trusted, open `Settings > General > VPN & Device Management > Developer App > Trust` on the iPhone, then tap the app or rerun the installer.
- If Airplane Mode cold launch shows `No script url provided`, reinstall with the default `npm run ios:device` flow. That builds Release with an embedded JavaScript bundle; Debug builds require Metro.
- If first run fails offline, run once online so the model can download/cache, then retry in Airplane Mode.
- If QVAC reports `llamacpp` or Metal errors, include only the error category and device/iOS version in the result.
