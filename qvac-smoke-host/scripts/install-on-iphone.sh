#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required. QVAC requires Node.js >= 22.17 for SDK tooling." >&2
  exit 1
fi

node -e '
const [major, minor] = process.versions.node.split(".").map(Number);
if (major < 22 || (major === 22 && minor < 17)) {
  console.error(`Node.js ${process.versions.node} found. QVAC requires Node.js >= 22.17.`);
  process.exit(1);
}
'

echo "Checking physical iPhone availability for Xcode..."
if ! command -v xcrun >/dev/null 2>&1; then
  echo "Xcode command line tools are required. Install/open Xcode before running this smoke host." >&2
  exit 70
fi

device_list="$(xcrun devicectl list devices 2>&1 || true)"
device_details="$(xcrun devicectl list devices --verbose 2>&1 || true)"
device_udid="$(printf "%s\n" "$device_details" | sed -n 's/.*udid: Optional("\([^"]*\)").*/\1/p' | head -n 1)"
device_name="$(printf "%s\n" "$device_details" | sed -n 's/.*name: Optional("\([^"]*\)").*/\1/p' | head -n 1)"

if ! printf "%s\n" "$device_list" | grep -q "iPhone"; then
  echo "No physical iPhone is visible to Xcode." >&2
  echo "Connect the iPhone, unlock it, tap Trust This Computer if prompted, then rerun this command." >&2
  exit 70
fi

if [ -z "$device_udid" ]; then
  echo "Xcode can see an iPhone, but the script could not read its physical-device UDID." >&2
  echo "Open Xcode > Window > Devices and Simulators, wait for the iPhone to become ready, then rerun." >&2
  exit 70
fi

if printf "%s\n" "$device_details" | grep -q "developerModeStatus.*disabled"; then
  echo "The connected iPhone is paired, but Developer Mode is disabled." >&2
  echo "On the iPhone: Settings > Privacy & Security > Developer Mode > On, then restart and confirm." >&2
  echo "After restart, keep the iPhone unlocked and rerun this command." >&2
  exit 70
fi

if printf "%s\n" "$device_list" | grep -Eq "unavailable[[:space:]]+iPhone"; then
  echo "A physical iPhone is known to Xcode, but it is currently unavailable as a build destination." >&2
  echo "Unlock the iPhone, reconnect the cable, confirm Trust This Computer, and make sure Developer Mode is enabled." >&2
  echo "If it still shows unavailable, open Xcode > Window > Devices and Simulators and wait for the phone to become ready." >&2
  exit 70
fi

echo "Installing QVAC/Expo smoke host dependencies..."
npm install

echo "Aligning Expo native module versions with the installed Expo SDK..."
npx expo install expo-file-system expo-build-properties expo-device

echo "Validating smoke host files..."
npm run validate

echo "Generating native iOS project..."
npx expo prebuild --platform ios

project_file="ios/QVACSmokeHost.xcodeproj/project.pbxproj"
configured_team="$(sed -n 's/.*DEVELOPMENT_TEAM = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' "$project_file" | grep -v '^$' | head -n 1 || true)"
development_team="${QVAC_SMOKE_DEVELOPMENT_TEAM:-$configured_team}"

if [ -z "$development_team" ]; then
  echo "No Apple development team is configured for the generated Xcode project." >&2
  echo "Rerun with QVAC_SMOKE_DEVELOPMENT_TEAM=<team-id>, or open ios/QVACSmokeHost.xcworkspace in Xcode and select a team." >&2
  exit 65
fi

configuration="${QVAC_SMOKE_CONFIGURATION:-Release}"
derived_data_path="${QVAC_SMOKE_DERIVED_DATA:-${TMPDIR:-/tmp}/qvac-smoke-host-derived-data}"
app_path="$derived_data_path/Build/Products/${configuration}-iphoneos/QVACSmokeHost.app"

echo "Building offline-capable iOS app with Xcode automatic provisioning enabled..."
echo "Device: ${device_name:-iPhone} ($device_udid)"
echo "Team: $development_team"
echo "Configuration: $configuration"

xcodebuild \
  -workspace ios/QVACSmokeHost.xcworkspace \
  -scheme QVACSmokeHost \
  -configuration "$configuration" \
  -destination "platform=iOS,id=$device_udid" \
  -derivedDataPath "$derived_data_path" \
  DEVELOPMENT_TEAM="$development_team" \
  RCT_NO_LAUNCH_PACKAGER=1 \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

if [ ! -d "$app_path" ]; then
  echo "Xcode build succeeded, but the expected app bundle was not found at:" >&2
  echo "$app_path" >&2
  exit 65
fi

if [ ! -f "$app_path/main.jsbundle" ]; then
  echo "Xcode build succeeded, but the app bundle does not contain main.jsbundle." >&2
  echo "Airplane Mode cold launch would fail without the embedded React Native JavaScript bundle." >&2
  echo "Make sure this script builds Release and does not set SKIP_BUNDLING." >&2
  exit 65
fi

echo "Installing the signed app on ${device_name:-the connected iPhone}..."
install_log="$(mktemp "${TMPDIR:-/tmp}/qvac-smoke-install.XXXXXX")"
set +e
xcrun devicectl device install app --device "$device_udid" "$app_path" 2>&1 | tee "$install_log"
install_status=${PIPESTATUS[0]}
set -e

if [ "$install_status" -ne 0 ]; then
  if grep -Eq "profile has not been explicitly trusted|invalid code signature|inadequate entitlements|Security" "$install_log"; then
    echo "" >&2
    echo "The app appears to be installed, but iOS refused to launch it because the developer profile is not trusted yet." >&2
    echo "On the iPhone, open:" >&2
    echo "  Settings > General > VPN & Device Management" >&2
    echo "Then trust the Developer App / Apple Development profile for this Mac's signing account." >&2
    echo "After trusting it, tap QVAC Smoke Host on the iPhone, or rerun npm run ios:device." >&2
    echo "" >&2
    echo "Install log: $install_log" >&2
    exit 70
  fi

  echo "Device install failed for the smoke host." >&2
  echo "Install log: $install_log" >&2
  exit "$install_status"
fi

echo "Launching QVAC Smoke Host..."
launch_log="$(mktemp "${TMPDIR:-/tmp}/qvac-smoke-launch.XXXXXX")"
set +e
xcrun devicectl device process launch --device "$device_udid" dev.qvac.smokehost 2>&1 | tee "$launch_log"
launch_status=${PIPESTATUS[0]}
set -e

if [ "$launch_status" -ne 0 ]; then
  if grep -Eq "profile has not been explicitly trusted|invalid code signature|inadequate entitlements|Security" "$launch_log"; then
    echo "" >&2
    echo "The app appears to be installed, but iOS refused to launch it because the developer profile is not trusted yet." >&2
    echo "On the iPhone, open:" >&2
    echo "  Settings > General > VPN & Device Management" >&2
    echo "Then trust the Developer App / Apple Development profile for this Mac's signing account." >&2
    echo "After trusting it, tap QVAC Smoke Host on the iPhone, or rerun npm run ios:device." >&2
    echo "" >&2
    echo "Launch log: $launch_log" >&2
    exit 70
  fi

  echo "The app installed, but Xcode could not launch it automatically." >&2
  echo "Try tapping QVAC Smoke Host on the iPhone." >&2
  echo "Launch log: $launch_log" >&2
  exit "$launch_status"
fi

echo "QVAC Smoke Host installed and launched. It is built with an embedded JS bundle for Airplane Mode cold launch."
