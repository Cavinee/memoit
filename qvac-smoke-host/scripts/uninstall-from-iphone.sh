#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

bundle_id="${QVAC_SMOKE_BUNDLE_ID:-dev.qvac.smokehost}"

echo "Checking physical iPhone availability for Xcode..."
if ! command -v xcrun >/dev/null 2>&1; then
  echo "Xcode command line tools are required to uninstall the smoke host." >&2
  exit 70
fi

device_list="$(xcrun devicectl list devices 2>&1 || true)"
device_details="$(xcrun devicectl list devices --verbose 2>&1 || true)"
device_udid="$(printf "%s\n" "$device_details" | sed -n 's/.*udid: Optional("\([^"]*\)").*/\1/p' | head -n 1)"
device_name="$(printf "%s\n" "$device_details" | sed -n 's/.*name: Optional("\([^"]*\)").*/\1/p' | head -n 1)"

if ! printf "%s\n" "$device_list" | grep -q "iPhone"; then
  echo "No physical iPhone is visible to Xcode." >&2
  echo "Connect and unlock the iPhone, then rerun this command." >&2
  exit 70
fi

if [ -z "$device_udid" ]; then
  echo "Xcode can see an iPhone, but the script could not read its physical-device UDID." >&2
  echo "Open Xcode > Window > Devices and Simulators, wait for the phone to become ready, then rerun." >&2
  exit 70
fi

echo "Uninstalling $bundle_id from ${device_name:-the connected iPhone} ($device_udid)..."
if xcrun devicectl device uninstall app --device "$device_udid" "$bundle_id"; then
  echo "Removed $bundle_id from ${device_name:-the connected iPhone}."
else
  echo "Uninstall failed. If the app was already removed, there may be nothing left to clean up." >&2
  exit 1
fi
