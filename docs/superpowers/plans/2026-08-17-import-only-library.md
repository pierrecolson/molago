# Import-only Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace daily generated articles with user-triggered Photo and YouTube imports, including a synchronized saved transcript and the validated Library/Wordbook UI.

**Architecture:** Keep the existing JSON-on-disk server instead of adding a database. The API scans imported texts into one library response, while the iOS app caches that response and remote thumbnails for offline use. YouTube metadata and captions are extracted by `yt-dlp`; the native app embeds the official IFrame player in `WKWebView` and maps its current time to stored caption cues.

**Tech Stack:** Node.js 22 standard library, `yt-dlp`, Swift 6, SwiftUI, SwiftData, WebKit, XCTest, XcodeGen.

**Spec:** `docs/plans/2026-08-17-import-only-library-design.md`

## Global Constraints

- iOS deployment target remains 18.0.
- No new Swift package or JavaScript package dependency.
- `yt-dlp` is the only new server executable and is invoked without a shell.
- Only `youtube.com` and `youtu.be` URLs are accepted.
- AI runs only after a user-triggered import, and only for missing English captions or existing word annotation.
- Recent means exactly the three most recently imported items, independent of date.
- Photo and YouTube rich cards use one component and identical geometry.
- Stored transcripts remain readable when playback is offline or unavailable.
- Interface chrome remains English; product documentation remains French.

---

### Task 1: Caption parsing and YouTube URL boundary

**Files:**
- Create: `api/youtube.mjs`
- Create: `api/youtube.test.mjs`

**Interfaces:**
- Produces: `parseYouTubeURL(value: unknown): URL`
- Produces: `parseVTT(source: string): Array<{start:number,end:number,text:string}>`
- Produces: `alignEnglish(korean, english): Array<{start:number,end:number,ko:string,en:string}>`
- Produces: `extractYouTube(url, options): Promise<VideoImport>`

- [ ] **Step 1: Write the failing parser tests**

```js
import test from 'node:test'
import assert from 'node:assert/strict'
import { parseYouTubeURL, parseVTT, alignEnglish } from './youtube.mjs'

test('accepts only YouTube video URLs', () => {
  assert.equal(parseYouTubeURL('https://youtu.be/42M_DVvzye8').hostname, 'youtu.be')
  assert.throws(() => parseYouTubeURL('https://example.com/watch?v=42M_DVvzye8'), /YouTube/)
})

test('parses timed WebVTT cues and removes markup', () => {
  const cues = parseVTT('WEBVTT\n\n00:00:06.214 --> 00:00:10.301\n<c>안녕하세요</c>\n')
  assert.deepEqual(cues, [{ start: 6.214, end: 10.301, text: '안녕하세요' }])
})

test('aligns English text by time overlap', () => {
  const ko = [{ start: 6, end: 10, text: '안녕하세요' }]
  const en = [{ start: 6.1, end: 9.9, text: 'Hello' }]
  assert.deepEqual(alignEnglish(ko, en), [{ start: 6, end: 10, ko: '안녕하세요', en: 'Hello' }])
})
```

- [ ] **Step 2: Run `node --test api/youtube.test.mjs` and verify `ERR_MODULE_NOT_FOUND`**
- [ ] **Step 3: Implement the three pure functions, then the smallest `yt-dlp` wrapper using `execFile`/`spawn` arguments rather than a shell string**
- [ ] **Step 4: Re-run `node --test api/youtube.test.mjs` and verify all tests pass**

### Task 2: Library and YouTube API routes

**Files:**
- Create: `api/server.test.mjs`
- Modify: `api/server.mjs`
- Modify: `api/Dockerfile`
- Modify: `deploy/docker-compose.yml`

**Interfaces:**
- Produces: `GET /u/:id/library -> {items: Array<{date:string,text:object}>}`
- Produces: `POST /u/:id/youtube {url:string} -> {date:string,slot:string,title:string}`
- Consumes: `extractYouTube()` from Task 1

- [ ] **Step 1: Write an HTTP integration test that starts the exported handler on an ephemeral port with a temporary data directory**

```js
test('returns only user imports and stores a YouTube import', async () => {
  const imported = await post('/u/testuser1/youtube', { url: 'https://youtu.be/42M_DVvzye8' })
  assert.equal(imported.status, 200)
  const library = await get('/u/testuser1/library')
  assert.equal(library.items.length, 1)
  assert.equal(library.items[0].text.videoID, '42M_DVvzye8')
})
```

- [ ] **Step 2: Run `node --test api/server.test.mjs` and verify the missing route fails with 404**
- [ ] **Step 3: Export a testable server factory, add the two routes, store imported captions with optional timing/word annotations, and keep legacy photo captures in the library scan**
- [ ] **Step 4: Install `yt-dlp` in the API image and expose the new routes through Traefik**
- [ ] **Step 5: Run `node --test api/*.test.mjs` and verify all tests pass**

### Task 3: iOS import data and offline library store

**Files:**
- Create: `app/Tests/LibraryModelTests.swift`
- Modify: `app/project.yml`
- Modify: `app/Sources/Day.swift`
- Modify: `app/Sources/DayStore.swift`

**Interfaces:**
- Produces: `LibraryItem { date: String, text: Day.Text }`
- Produces: `DayStore.items: [LibraryItem]`
- Produces: `Day.Text.isYouTube`, `isPhoto`, `thumbnailURL`, and timed `Day.Sentence.start/end`
- Produces: `LibrarySections.split(_:) -> (recent:[LibraryItem], older:[LibraryItem])`

- [ ] **Step 1: Add an XCTest target and a failing test that decodes a video import and splits four literal imports into 3 Recent + 1 Older**
- [ ] **Step 2: Run the focused `xcodebuild test` command and verify compilation fails because the new models do not exist**
- [ ] **Step 3: Add optional video fields to the existing `Day.Text`/`Sentence`, implement `LibraryItem`, and refactor `DayStore.load()` to fetch/cache `/library` instead of guessing daily files**
- [ ] **Step 4: Cache YouTube thumbnails by slot and merge legacy cached photo captures without exposing generated articles**
- [ ] **Step 5: Re-run the focused test and verify it passes**

### Task 4: Direct YouTube entry in Capture

**Files:**
- Modify: `app/Sources/Capture.swift`
- Modify: `app/Sources/CaptureView.swift`

**Interfaces:**
- Produces: `CaptureFlow.importYouTube(_ url: String) async`
- Consumes: `POST /youtube` from Task 2

- [ ] **Step 1: Add a failing model test for trimming a pasted URL and rejecting an empty value before a request is created**
- [ ] **Step 2: Run the focused XCTest and verify the missing validation fails**
- [ ] **Step 3: Add the inline URL field and `Add` button below the two photo actions, with `Preparing the transcript…`, invalid-link, no-transcript, and success copy**
- [ ] **Step 4: Re-run the focused XCTest and the Swift build**

### Task 5: Recent and Older Library UI

**Files:**
- Modify: `app/Sources/HomeView.swift`
- Modify: `app/Sources/MolagoApp.swift`
- Modify: `app/Sources/SearchView.swift`

**Interfaces:**
- Consumes: `DayStore.items` and `LibrarySections.split(_:)` from Task 3
- Produces: one `ImportCard` used by Photo and YouTube with fixed image/text geometry

- [ ] **Step 1: Keep the Task 3 four-item split test red while replacing the old Today/My content/Previously inputs**
- [ ] **Step 2: Implement `Recent` as a horizontal row of up to three equal `ImportCard` views and `Older` as the existing compact row block**
- [ ] **Step 3: Add the empty state `Nothing here yet` / `Add a photo or YouTube video to start your library.` and remove the morning bell/sheet**
- [ ] **Step 4: Update Search to use imports only and run all iOS unit tests/build**

### Task 6: Embedded player and synchronized transcript

**Files:**
- Create: `app/Sources/YouTubePlayer.swift`
- Create: `app/Tests/TranscriptTimelineTests.swift`
- Modify: `app/Sources/ReaderView.swift`

**Interfaces:**
- Produces: `TranscriptTimeline.index(at:in:) -> Int?`
- Produces: `YouTubePlayerModel.currentTime`, `state`, `seek(to:)`, `retry()`
- Produces: `YouTubePlayerView(videoID:model:)`

- [ ] **Step 1: Write a failing test for cue boundaries: before first cue is nil, a cue owns `[start,end)`, and a gap keeps no active cue**
- [ ] **Step 2: Run the focused test and verify `TranscriptTimeline` is missing**
- [ ] **Step 3: Implement the pure timeline, then a `WKWebView` IFrame wrapper that posts time/state/error messages and omits YouTube caption forcing**
- [ ] **Step 4: Branch ReaderView for videos: player on top, stored transcript below, English off by default, active cue highlighting/scrolling, sentence tap seeking, no voice bar**
- [ ] **Step 5: Implement offline, removed/private, and embed-refused states while leaving the transcript visible**
- [ ] **Step 6: Re-run timeline tests and the complete iOS test/build suite**

### Task 7: Wordbook naming and minimal word detail

**Files:**
- Modify: `app/Sources/MolagoApp.swift`
- Modify: `app/Sources/NotebookView.swift`
- Modify: `app/Sources/Notebook.swift`
- Modify: `app/Sources/WordDetailView.swift`
- Modify: `app/Sources/ReaderView.swift`

**Interfaces:**
- Adds optional `sourceTime: Double?` to `KeptWord`
- Reader keep action stores `sentence.start`

- [ ] **Step 1: Add a model test proving an optional YouTube timestamp survives encode/decode of the source data used to create a kept word**
- [ ] **Step 2: Run the focused test and verify the missing timestamp fails**
- [ ] **Step 3: Replace every user-facing Notebook string with Wordbook**
- [ ] **Step 4: Simplify the detail screen to system typography plus `Where you met it` and `Word family`; remove decorative hanja/colored ornaments and expose the video timestamp action when present**
- [ ] **Step 5: Run all iOS tests/build**

### Task 8: Stop daily generation and update product truth

**Files:**
- Modify: `deploy/docker-compose.yml`
- Modify: `deploy/push.sh`
- Modify: `PRODUCT.md`
- Modify: `README.md`

**Interfaces:**
- The deploy stack produces only `files` and `api` services.

- [ ] **Step 1: Run `docker compose -f deploy/docker-compose.yml config --services` and record that `pipeline` is present**
- [ ] **Step 2: Remove pipeline deployment/build/run behavior and daily-generation documentation; document import-only behavior and the VPS cron removal command**
- [ ] **Step 3: Re-run Compose config and verify output is exactly `files` and `api`**

### Task 9: Verification and visual audit

**Files:**
- Modify only files required by findings from the audit.

- [ ] **Step 1: Run `node --test api/*.test.mjs`**
- [ ] **Step 2: Run all iOS tests with `xcodebuild test` on the iPhone 17 Pro simulator**
- [ ] **Step 3: Run `./app/run.sh`, import `https://www.youtube.com/watch?v=42M_DVvzye8`, and confirm the real transcript/player flow**
- [ ] **Step 4: Capture Library, Reader, offline/unavailable, and Wordbook screens**
- [ ] **Step 5: Run the current Web Interface Guidelines audit against changed UI files and fix Block-level findings**
- [ ] **Step 6: Confirm `git diff --check`, review the complete diff, and report the live simulator test checklist**
