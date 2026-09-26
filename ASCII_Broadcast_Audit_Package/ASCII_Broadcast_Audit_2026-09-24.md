# ASCII Broadcast Source Audit

Date: 2026-09-24 (America/Los_Angeles)
Source audited: `Archive(3).zip`
Primary app: `apps/ASCIIBroadcast/ASCIIBroadcast`

## Validation performed

- Unpacked and enumerated the full repository.
- Read `README.md`, `AGENTS.md`, and Phase 3 implementation notes before auditing implementation.
- Parsed every Swift source file with Swift 6.2.1 frontend: PASS.
- Checked `web/app.js` with Node syntax checker: PASS.
- Regenerated the Xcode project and compared it to the checked-in `project.pbxproj`.
- Traced TrackAnalysis cache/version semantics from model -> analyzer -> AnalysisService -> StudioViewModel persistence.
- Traced import failure handling and source fingerprinting through StudioViewModel and MediaLibrary.
- Generated a unified patch and verified `git apply --check` succeeds against the supplied archive.
- Re-parsed every Swift source file after patching: PASS.

Important limitation: this environment is not macOS/Xcode, so Apple-framework type checking and a real `xcodebuild` cannot be executed here. The final acceptance gate remains an Xcode build on your Mac.

## Must-fix findings included in patch

### 1. TrackAnalysis cache version lookup constructs an impossible empty TrackAnalysis
Severity: build blocker

`AnalysisService` calls `TrackAnalysis().extractorVersion`, but `TrackAnalysis` requires `assetFingerprint`, so there is no zero-argument initializer. The version itself is type-level configuration, not instance state.

Fix: introduce `TrackAnalysis.currentExtractorVersion = 3`, make new analyses default to it, and compare cached analyses against that static value. This preserves the intended cache invalidation contract.

### 2. Missing Combine imports
Severity: probable build blockers

`AnalysisService` and `BroadcastCoordinator` conform to `ObservableObject` and use `@Published`, but neither imports Combine directly. `StudioViewModel` already does. The patch adds explicit `import Combine` to both files instead of relying on incidental/re-exported module visibility.

### 3. ImportFailure switch formatting/type repair
Severity: build/readability defect

The supplied `StudioViewModel.swift` has the failure case compressed/misaligned into the prior case. The underlying type mismatch was already conceptually corrected to use `failure.reason`; the patch normalizes the switch to an unambiguous form.

### 4. Persistent asset fingerprint uses randomized Swift hashValue
Severity: high logic/data-integrity defect

Imported assets currently use `url.lastPathComponent.hashValue` as part of their persisted fingerprint. Swift's `hashValue` is deliberately randomized between process launches and is not a stable persistent identifier. This can break duplicate detection and cause cached TrackAnalysis entries to be missed after relaunch.

The model comment already specifies the intended scheme as `size + mtime + head hash`. The patch implements that contract using SHA-256 of the first 64 KiB plus file size and modification time. This is deterministic across launches and cheap for large media files.

## Important findings not automatically changed

### 5. VisualDNA.compilerVersion is declared but never enforced
Severity: medium-high architectural defect

`VisualDNA.compilerVersion` is documented in Phase 3 as a cache invalidation contract, but the current source only stores the field. No restore/generation path compares persisted DNA against a current compiler version. Old DNA can therefore survive a compiler-meaning change even though the documentation says version 3 should invalidate it.

Recommendation: mirror the TrackAnalysis pattern with `VisualDNA.currentCompilerVersion`, then define an explicit restore policy: regenerate, mark stale, or migrate. I did not silently choose one because it changes creator-visible identity/lock behavior.

### 6. Xcode project generator and checked-in project have drifted
Severity: medium operational defect

Running `python3 tools/generate_xcodeproj.py` does not reproduce the supplied `project.pbxproj`. Some differences are formatting/order, but there are semantic differences too: the checked-in project contains a development team and additional sandbox/file-access settings that the generator removes or changes. In particular, generated `ENABLE_USER_SELECTED_FILES` is `readonly` while the checked-in project is `readwrite`.

Recommendation: decide which file is authoritative. If the generator is truly authoritative, encode desired capabilities/signing-neutral settings there and regenerate. If Xcode-managed capabilities are authoritative, stop claiming the pbxproj is never hand-maintained.

### 7. No automated tests despite deterministic core contracts
Severity: medium

The repository itself identifies this as deferred. The most valuable first tests remain: ScoreCompiler determinism, extractor-version cache invalidation, stable fingerprint behavior, AMF0 round trips, FLV AVC configuration records, and section finding on synthetic audio.

### 8. AVAsset synchronous metadata APIs are deprecated territory
Severity: low now, future-facing

`AVURLAsset.duration`, `commonMetadata`, and `tracks(withMediaType:)` are used synchronously in the import path. The repository already anticipates deprecation warnings. These do not need to block the current build-fix pass, but should move to async property loading in the next modernization pass.

### 9. RTMP/RTMPS implementation remains unvalidated against a live ingest
Severity: high release risk, not a static-code defect

This is explicitly documented by the project. The source can be structurally correct and still fail protocol interoperability. Dry-run coverage does not establish YouTube ingest compatibility. Validate handshake, command exchange, AVC/AAC headers, timestamps, reconnect behavior, and `NetStream.Publish.Start` against a disposable stream key before release.

## Patch scope

The supplied patch intentionally changes only four implementation areas:

- `Model/Analysis.swift`
- `Analysis/AnalysisService.swift`
- `Broadcast/BroadcastCoordinator.swift`
- `App/StudioViewModel.swift`

It does not alter VisualDNA regeneration semantics, Xcode project settings, RTMP behavior, rendering, scoring behavior, or creator-facing defaults.
