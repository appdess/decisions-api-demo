#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build
xcrun swiftc -module-cache-path build/ModuleCache BakeryDecisions/DecisionCore.swift Tests/CoreChecks.swift -o build/core-checks
./build/core-checks
