# Supadata YouTube Transcript Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pasted YouTube URL produces a timed Korean transcript again, through a provider-agnostic route that never has to change the app when the provider does.

**Architecture:** The iPhone asks the Hostinger API for a transcript. One server module talks to Supadata for the cues and to the official YouTube Data API for the metadata. Apple Translation still supplies English on the device, and the import is still one JSON file in iCloud.

**Tech Stack:** Node 22 (`node:http`, no framework), `node --test`, Swift 6, SwiftUI, Translation, XcodeGen, XCTest.

**Spec:** `docs/plans/2026-08-18-supadata-transcript-design.md`

## Why Supadata and not the alternatives

`yt-dlp` on Hostinger is blocked because the IP is a datacenter address, and the yt-dlp wiki is explicit that a PO token no longer clears the bot check in most cases — IP reputation decides. A NAS at home clears it for one person and caps out at the first dozens of users. Rented residential proxies scale but keep the yt-dlp upkeep and put the scraping on us. Supadata removes the infrastructure entirely, costs nothing at one user (100 credits/month), and stays under one function so a replacement is a one-file change.

Video metadata does **not** go through Supadata: a second Supadata endpoint would halve the free quota, while `videos.list` in the official YouTube Data API costs 1 unit out of 10,000 free per day and is the legitimate route for title, channel, duration and thumbnail.

## Global Constraints

- Minimum deployment target is iOS 18.0; no visual change, no new screen, no added animation.
- The app knows one endpoint only. Every provider detail stays behind `api/transcript.mjs`.
- Pin Supadata to native captions. AI generation bills 2 credits per generated minute and must never fire implicitly.
- No API key ever reaches the app. Keys live in the VPS `.env`.
- A video without Korean captions still imports, with an empty transcript and a working player.
- Apple Translation keeps producing English on the device. Photo captures keep being translated server-side — that path is untouched.
- No message shows a raw provider error, an HTTP status, or a key.
- Every check that touches a real API or the deployed stack runs from the VPS over SSH — the keys are IP-restricted. Unit tests stay local. See `CLAUDE.md`.

---

### Task 0: Confirm Supadata returns timed Korean before anything is built

**Files:** none — this is a gate, not a change.

- [ ] **Step 1: Call Supadata with a free key on the reference video**

Run from the VPS, never locally — the keys are IP-restricted (see `CLAUDE.md`):

`ssh root@srv1405219.hstgr.cloud "curl -s 'https://api.supadata.ai/v1/transcript?url=https://youtu.be/zC4aRaHI-yw&lang=ko&mode=native' -H 'x-api-key: \$SUPADATA_API_KEY'"`

Expected: a `content` array whose entries carry `text`, `offset` and `duration` in milliseconds, and roughly **63 segments** — the count the iOS spike measured on this video.

- [ ] **Step 2: Call the official metadata endpoint with a Google API key**

Run from the VPS as well:

`ssh root@srv1405219.hstgr.cloud "curl -s 'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=zC4aRaHI-yw&key=\$YOUTUBE_API_KEY'"`

Expected: `snippet.title`, `snippet.channelTitle`, `snippet.thumbnails` and an ISO 8601 `contentDetails.duration`.

- [ ] **Step 3: Stop if either fails**

If Korean does not come back, the provider choice is wrong, not the plan: re-run Step 1 against TranscriptAPI before continuing. Everything downstream assumes these two shapes.

---

### Task 1: The transcript provider module

**Files:**
- Create: `api/transcript.mjs`
- Create: `api/transcript.test.mjs`
- Delete: `api/youtube.mjs`, `api/youtube.test.mjs`

**Interfaces:**
- Produces: `fetchTranscript(url, options) -> { videoID, title, channel, duration, thumbnail, sourceURL, cues: [{ start, end, ko }] }`, and `parseYouTubeURL(value)` moved over unchanged from `api/youtube.mjs`.
- Consumes: `SUPADATA_API_KEY`, `YOUTUBE_API_KEY`, and an injectable `fetch` so tests never touch the network.

- [ ] **Step 1: Write failing tests for parsing, mapping and failure**

Keep the existing `parseYouTubeURL` cases from `api/youtube.test.mjs` — they already cover `youtu.be`, `shorts`, `live`, `embed`, channels and non-YouTube hosts. Add: a literal Supadata payload maps to seconds (`offset: 18800, duration: 1000` becomes `start: 18.8, end: 19.8`); an ISO 8601 `PT4M13S` becomes 253 seconds; an empty `content` yields a video with zero cues rather than an error; a Supadata 4xx surfaces as a typed failure carrying no key and no raw body.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `node --test api/transcript.test.mjs`

Expected: failure because `api/transcript.mjs` does not exist.

- [ ] **Step 3: Implement the module**

Validate the URL first, so a bad link never spends a credit. Request `lang=ko` with the native mode pinned. Fetch metadata from `videos.list` in parallel with the transcript, since neither needs the other. Fall back to `https://i.ytimg.com/vi/<id>/hqdefault.jpg` for the thumbnail and to the last cue's end for the duration when metadata is unavailable — a missing title must not lose a transcript.

- [ ] **Step 4: Delete the yt-dlp module**

Remove `api/youtube.mjs` and `api/youtube.test.mjs`. `parseVTT` and `alignEnglish` go with them: nothing calls them once cues arrive as JSON.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `node --test api/transcript.test.mjs`. Expected: all pass.

---

### Task 2: The route on the VPS

**Files:**
- Modify: `api/server.mjs`
- Modify: `api/server.test.mjs`

**Interfaces:**
- Produces: `POST /u/:id/transcript` with `{ url }`, replying with the `fetchTranscript` shape.
- Consumes: `fetchTranscript` from Task 1, and the existing `readBody` / `json` helpers.

- [ ] **Step 1: Write failing route tests**

Assert that `POST /u/:id/transcript` returns the mapped video for a stub provider, that a malformed URL returns 400 with a sentence the app can show, that a provider outage returns 503 and not 500, and that `POST /u/:id/youtube` is now 404.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `node --test api/server.test.mjs`

- [ ] **Step 3: Add the route and remove the old one**

Add `transcript` to the path regex at `api/server.mjs:275`. Delete the `youtube` route (lines 292–325) and the two helpers that only served it, `translateSentences` (line 190) and `annotateCues` (line 204), along with the `extractYouTube` import. The server stops translating YouTube entirely — the device does it.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `node --test api/*.test.mjs`. Expected: the whole API suite passes.

---

### Task 3: Deployment

**Files:**
- Modify: `api/Dockerfile`, `deploy/docker-compose.yml`, `deploy/push.sh`

**Interfaces:**
- Produces: an API image with no Python, and a `.env` carrying the two new keys.

- [ ] **Step 1: Slim the image**

Drop `python3`, `python3-pip` and the `yt-dlp` install from `api/Dockerfile`. The container becomes plain Node; the comment about downloading subtitle tracks goes with it.

- [ ] **Step 2: Route the new path**

In `deploy/docker-compose.yml`, replace `youtube` with `transcript` in the Traefik `PathRegexp` rule. Leave the memory limits alone — the VPS shares 8 GB with five other stacks.

- [ ] **Step 3: Ship the keys**

Widen the `grep -E '^(OPENROUTER_API_KEY|MOLAGO_USER_ID|MOLAGO_SECRET_PATH)='` filter in `deploy/push.sh` to carry `SUPADATA_API_KEY` and `YOUTUBE_API_KEY`. They travel by stdin like the others, never on a command line.

- [ ] **Step 4: Deploy and verify**

Run: `./deploy/push.sh --build`, then, from the VPS:

`ssh root@srv1405219.hstgr.cloud "curl -s -X POST https://molago.srv1405219.hstgr.cloud/u/<id>/transcript -H 'content-type: application/json' -d '{\"url\":\"https://youtu.be/zC4aRaHI-yw\"}'"`

Expected: the same 63 cues Task 0 saw, now from Hostinger — which is the whole point, since this is the machine YouTube refused.

---

### Task 4: The app asks the API

**Files:**
- Modify: `app/Sources/YouTubeImport.swift`, `app/project.yml`
- Test: `app/Tests/YouTubeImportTests.swift`

**Interfaces:**
- Produces: `YouTubeImport.fetch(_:)` unchanged in signature, backed by the API.
- Consumes: `Config.baseURL`, following `DayStore.fetchLibrary()` at `DayStore.swift:209`.

- [ ] **Step 1: Write failing decode tests**

Assert a literal API reply decodes into a `Video` with its cues in seconds, and that a reply with zero cues still produces a playable video. Keep every existing `videoID(from:)` and `item(from:translations:)` case — they do not change.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `xcodebuild test -project app/Molago.xcodeproj -scheme Molago -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MolagoTests/YouTubeImportTests`

- [ ] **Step 3: Point fetch at the API**

Validate the URL locally first, so a non-YouTube link is still refused before any network call. POST `{ url }` to `Config.baseURL.appending(path: "transcript")` with a 60-second timeout — a long transcript is slower than a library listing. Map the reply to the existing `Video`. Everything downstream (`item(from:)`, `CaptureFlow.importYouTube`, `ImportedLibrary`) stays untouched.

- [ ] **Step 4: Drop the package**

Remove the `YouTubeMetadata` package and the `YouTubeTranscript` dependency from `app/project.yml`, then run `xcodegen`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the command from Step 2. Expected: all `YouTubeImportTests` pass.

---

### Task 5: Documentation

**Files:**
- Modify: `README.md`, `docs/plans/2026-08-17-local-youtube-import-design.md`

- [ ] **Step 1: Correct the superseded document**

`docs/plans/2026-08-17-local-youtube-import-design.md` still claims "Aucun appel Supadata" and "Aucun appel à la route Hostinger". Add a closing note saying what replaced it and why, rather than editing history.

- [ ] **Step 2: Update the README**

The YouTube line names where a transcript now comes from. The `api/` row mentions transcripts instead of YouTube imports.

---

## Verification

1. `node --test api/*.test.mjs` passes.
2. `POST /u/<id>/transcript`, called from the VPS, returns 63 cues for `zC4aRaHI-yw`.
3. A non-YouTube URL is refused in the app before any network call.
4. Pasting the reference link in Capture gives title, thumbnail, 63 translated segments, an entry in Library, and readable offline.
5. Re-importing the same video replaces its file without creating a duplicate.
6. With the API unreachable, the app shows its recovery sentence and no raw error.
7. A video without Korean captions still imports and still plays.
