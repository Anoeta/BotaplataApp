#!/usr/bin/env bash
# Requires macOS, Xcode and an iPhone simulator compatible with the project's deployment target.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
    echo "Xcode and the iOS Simulator SDK are required; no iOS build or tests ran." >&2
    exit 1
fi
if [[ -n "${BOTAPLATA_SIMULATOR_ID:-}" ]]; then
    simulator_id="$BOTAPLATA_SIMULATOR_ID"
else
    devices_json="$(mktemp "${TMPDIR:-/tmp}/botaplata-simulators.XXXXXX")"
    trap 'rm -f "$devices_json"' EXIT
    xcrun simctl list devices available --json > "$devices_json"
    simulator_id="$(python3 - "$devices_json" <<'PY'
import json, re, sys
from pathlib import Path
project=Path('BotaplataApp.xcodeproj/project.pbxproj').read_text()
target=tuple(map(int,re.search(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+)',project)[1].split('.')))
for runtime, devices in json.load(open(sys.argv[1]))['devices'].items():
    version=re.search(r'iOS-(\d+)-(\d+)',runtime)
    if not version or tuple(map(int,version.groups())) < target:
        continue
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            print(device['udid']); sys.exit(0)
sys.exit('No available iPhone simulator meets iOS ' + '.'.join(map(str,target)))
PY
)"
fi
validation_root="${BOTAPLATA_TEST_RESULTS_DIR:-${TMPDIR:-/tmp}/botaplata-ios-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$validation_root"
xcodebuild -project BotaplataApp.xcodeproj -scheme BotaplataApp \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$validation_root/DerivedData" \
    -resultBundlePath "$validation_root/TestResults.xcresult" test
