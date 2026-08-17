# Local YouTube Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import and translate a Korean YouTube transcript on the iPhone, then synchronize the resulting library item through iCloud Documents.

**Architecture:** A pinned Swift package fetches the transcript from the iPhone network. Apple Translation supplies English in `CaptureView`, a pure mapper builds the existing `LibraryItem`, and one JSON file per import is saved to iCloud and merged by `DayStore`.

**Tech Stack:** Swift 6, SwiftUI, Translation, Foundation, iCloud Documents, XcodeGen, XCTest, `YouTubeTranscript` 0.1.0.

**Spec:** `docs/plans/2026-08-17-local-youtube-import-design.md`

## Global Constraints

- Minimum deployment target is iOS 18.0.
- Preserve the current Capture and Library visual language; no new surface or animation.
- Do not call Supadata or the Hostinger `/youtube` route.
- Keep one JSON file per imported video and prefer it over an older remote item with the same slot.
- Translation errors must provide a recovery action in plain English.

---

### Task 1: iCloud import files

**Files:**
- Create: `app/Sources/ImportedLibrary.swift`
- Modify: `app/Sources/DayStore.swift`
- Test: `app/Tests/ImportedLibraryTests.swift`

**Interfaces:**
- Produces: `ImportedLibrary.save(_:in:) throws` and `ImportedLibrary.read(from:) async -> [LibraryItem]`.
- Consumes: existing `LibraryItem`, `Paths.root`, and the iCloud ubiquity container.

- [ ] **Step 1: Write failing round-trip and replacement tests**

Create two `LibraryItem` fixtures, save them in a temporary directory, assert both decode, then save the same slot again and assert only the replacement remains.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `xcodebuild test -project app/Molago.xcodeproj -scheme Molago -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MolagoTests/ImportedLibraryTests`

Expected: compilation fails because `ImportedLibrary` does not exist.

- [ ] **Step 3: Implement the minimum file store**

Write `<slot>.json` atomically. Read `.json` files, request downloads for `.icloud` placeholders, wait briefly for those files, decode valid items, and ignore malformed files without dropping valid siblings.

- [ ] **Step 4: Merge local imports into DayStore**

Load iCloud imports before the network request, merge them into the immediate cache, and prefer them again after the Hostinger library response arrives.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the focused command from Step 2. Expected: all `ImportedLibraryTests` pass.

### Task 2: YouTube transcript mapping

**Files:**
- Create: `app/Sources/YouTubeImport.swift`
- Modify: `app/project.yml`
- Test: `app/Tests/YouTubeImportTests.swift`

**Interfaces:**
- Produces: `YouTubeImport.fetch(_:) async throws -> YouTubeImport.Video` and `YouTubeImport.item(from:translations:now:) -> LibraryItem`.
- Consumes: `YouTubeTranscript.fetch(_:languages:)` and the existing `Day` model.

- [ ] **Step 1: Write failing validation and mapping tests**

Assert that a non-YouTube URL is rejected. Map a literal two-cue video and assert its slot, canonical source, timestamps, translations, metadata, and tappable word tokens.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `xcodebuild test -project app/Molago.xcodeproj -scheme Molago -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MolagoTests/YouTubeImportTests`

Expected: compilation fails because `YouTubeImport` does not exist.

- [ ] **Step 3: Add the pinned package and mapper**

Add `swift-youtube-metadata` exact version `0.1.0` to XcodeGen and link only the `YouTubeTranscript` product to Molago. Validate YouTube hosts, fetch Korean, convert package metadata and cues, and create `Day.Sentence` values with whitespace token words.

- [ ] **Step 4: Preserve videos without Korean captions**

For transcript-disabled or no-transcript errors, build a zero-cue video using its parsed ID, canonical URL, deterministic thumbnail, and generic metadata so the reader still opens the YouTube player.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the focused command from Step 2. Expected: all `YouTubeImportTests` pass.

### Task 3: Capture orchestration and Apple Translation

**Files:**
- Modify: `app/Sources/Capture.swift`
- Modify: `app/Sources/CaptureView.swift`
- Modify: `app/Tests/LibraryModelTests.swift`

**Interfaces:**
- Produces: `CaptureFlow.importYouTube(_:translate:fetch:save:) async`.
- Consumes: `YouTubeImport.fetch`, `YouTubeImport.item`, `ImportedLibrary.save`, and an async translation closure supplied by `TranslationSession`.

- [ ] **Step 1: Replace the server-request test with failing local-flow tests**

Supply literal fetch, translation, and save closures. Assert `.filed(title:)` and the saved English text on success; assert a recovery message when translation throws.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `xcodebuild test -project app/Molago.xcodeproj -scheme Molago -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MolagoTests/LibraryModelTests`

Expected: compilation fails because the local import signature is missing.

- [ ] **Step 3: Implement the local flow**

Remove `youtubeRequest(for:)`. Fetch locally, skip translation for an empty transcript, require one translation per cue, save the item, and map fetch, translation, and storage failures to the approved UI copy.

- [ ] **Step 4: Connect Apple Translation in CaptureView**

Import `Translation`, invalidate a Korean-to-English `TranslationSession.Configuration` when `Add` is submitted, translate requests in batches of 50 using client identifiers, and pass the ordered results to `CaptureFlow`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the focused command from Step 2. Expected: all `LibraryModelTests` pass.

### Task 4: Whole-app verification

**Files:**
- Review: all changed Swift and YAML files.

**Interfaces:**
- Consumes: all preceding tasks.
- Produces: a build ready for physical-iPhone and TestFlight validation.

- [ ] **Step 1: Regenerate the project and run all tests**

Run: `cd app && xcodegen && xcodebuild test -project Molago.xcodeproj -scheme Molago -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build`.

- [ ] **Step 2: Build the iPhone app**

Run: `xcodebuild -project app/Molago.xcodeproj -scheme Molago -destination 'generic/platform=iOS' -derivedDataPath app/build CODE_SIGNING_ALLOWED=NO build`.

- [ ] **Step 3: Run the Impeccable detector**

Run: `node /Users/pierre/.agents/skills/impeccable/scripts/detect.mjs --json app/Sources/CaptureView.swift` and resolve only findings introduced by this change.

- [ ] **Step 4: Inspect the final diff**

Confirm the app no longer constructs a `/youtube` request, no raw technical command can reach the UI, and no unrelated files changed.
