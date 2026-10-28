# Agent instructions — prisma

## Repository-specific deterministic quality contract (2026-10-26)

**Project:** Swift iOS app with service and parsing tests.

**Engineering requirements:** Preserve API parsing, consent/privacy and Swift concurrency; build with the iOS SDK matching the project's deployment target.

**Verification commands:** xcodebuild -project Prisma.xcodeproj -scheme Prisma -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build.

Only report checks as passed when run with actual evidence. Add regression tests for new behavior and boundary/error paths. Never delete/skip/weaken tests, hide failures or reduce thresholds to make CI pass. Require human review for changes to `QUALITY_GATES.md`, `AGENTS.md`, policy and workflows. Make `quality` a required branch status. Missing tooling or pre-existing failures must be disclosed. Preserve the original instructions.
