#!/usr/bin/env bash
# Runs production Foundation-only models + XCTest on Linux or macOS. Does not validate SwiftUI.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
validation_root="$(mktemp -d "${TMPDIR:-/tmp}/botaplata-foundation.XXXXXX")"
trap 'rm -rf "$validation_root"' EXIT
mkdir -p "$validation_root/Sources/BotaplataApp" "$validation_root/Tests/BotaplataAppTests"
cat > "$validation_root/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "BotaplataFoundationValidation", products: [], targets: [
    .target(name: "BotaplataApp"),
    .testTarget(name: "BotaplataAppTests", dependencies: ["BotaplataApp"], resources: [.copy("Fixtures")])
], swiftLanguageModes: [.v5])
PACKAGE
sources=(
    Domain/Trading/TradingModels.swift
    Domain/Trading/TradingChartModels.swift
    Domain/Trading/PremiumMarketPresentation.swift
    Domain/Shared/SharedModels.swift
    Domain/Shared/APIWarningPresentation.swift
    Domain/Sessions/SessionModels.swift
    Domain/Auth/AuthenticationModels.swift
    Domain/Auth/AuthenticatedUser.swift
    Features/Sessions/RealStrategyExplanationRepositoryProtocol.swift
    Features/Sessions/RealStrategyExplanationStore.swift
    Domain/Sessions/RealSessionsDTO.swift
    Domain/Sessions/StrategyExplanationDTO.swift
    Domain/Sessions/StrategyExplanationModels.swift
    Domain/Sessions/StrategyExplanationMapper.swift
    Domain/Dashboard/RealActiveSnapshotDTO.swift
    Core/Formatting/FinancialFormatters.swift
    Core/Networking/APIEnvelope.swift
    Core/Networking/APIWarning.swift
    Core/Networking/APIMeta.swift
    Core/Networking/APIError.swift
    Core/Networking/JSONCoding.swift
)
for source_file in "${sources[@]}"; do
    cp "$repo_root/BotaplataApp/$source_file" "$validation_root/Sources/BotaplataApp/"
done
cp "$repo_root/BotaplataAppTests/TradingChartMapperTests.swift" "$validation_root/Tests/BotaplataAppTests/"
cp "$repo_root/BotaplataAppTests/MobileV1ChartContractDecodingTests.swift" "$validation_root/Tests/BotaplataAppTests/"
cp "$repo_root/BotaplataAppTests/PremiumStrategyStoreTests.swift" "$validation_root/Tests/BotaplataAppTests/"
cp "$repo_root/BotaplataAppTests/PremiumRedesignTests.swift" "$validation_root/Tests/BotaplataAppTests/"
cp -R "$repo_root/BotaplataAppTests/Fixtures" "$validation_root/Tests/BotaplataAppTests/"
export CLANG_MODULE_CACHE_PATH="$validation_root/clang-cache"
swift test --cache-path "$validation_root/swift-cache" --config-path "$validation_root/swift-config" --security-path "$validation_root/swift-security" --package-path "$validation_root" --jobs 2
