# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

A French expat who has lived in Seoul for eight years. Reads hangul fluently, holds
3 000–5 000 words, works in tech. He can live in Korean but stalls at group conversation,
the phone, and nuance — the long-term-resident plateau. He hates rote learning and has no
interest in K-pop or K-drama. He uses the app once a day, in the morning, on his phone,
alone, before or during the commute. Single-user V1; every table carries a `user_id` from
day one because a commercial version is envisaged.

## Product Purpose

Every morning, three Korean texts on subjects that genuinely interest him, calibrated to
his own vocabulary, read aloud — and the words he meets in his life in Seoul come back
inside them. Success is that he opens it because he wants to read what is in it, and that
he speaks better with the people around him. Failure is any morning where the app feels
like homework.

## Positioning

The content is the product; the language is the vehicle. The validation test for any text
is "would you have read this if it were in French?". Two things a neighbouring product
cannot truthfully copy:

1. **The level is guaranteed by a calculation, not a judgement.** Deterministic
   morphological analysis (Kiwi) compares every generated text's lemmas to the user's
   profile before publication. A text above level is not published — two good texts beat
   three with one bad one.
2. **The third text is written from the words the user captured himself.** A word caught
   on a maintenance bill on Tuesday is the subject of Wednesday's text, back in situation
   with the vocabulary that surrounds it.

## Operating Context

- **The morning ritual.** One notification at a user-set hour, announcing what there is to
  read, never asking for anything. Texts and audio are already on the device — no network
  needed. Read 3–4 min, quiz 90 s, done.
- **The city.** Maintenance bills (관리비 고지서), pharmacy counters, building management
  offices, KakaoTalk threads, administrative paperwork, the subway. This is where capture
  happens: photo (native iOS Vision OCR), iOS share sheet, or manual entry.
- **The three universes**, one per morning slot, each working a different layer of Korean:
  Tech & Science (Sino-Korean, dense), Korea — news & society (journalistic), Daily life in
  Seoul (spoken, 해요체).
- **The nightly factory.** A pipeline runs before the notification hour: collect → choose
  subject → select vocabulary → generate → deterministic level check → naturalness check →
  annotate → quiz → voice → publish.

## Capabilities and Constraints

- **Two tabs only: Library and Notebook.** No settings tab (the avatar opens settings), no
  separate archive tab (history is the continuation of today's feed).
- **Library**: today's three cards (universe label, English title, `4 min` and nothing else
  unless difficulty is unusual: `· a bit of a stretch` / `· easy going`), then previous days
  below without a break, indefinitely. Never shown on a card: total word count, new-word
  count, or where the subject came from.
- **Reader**: ~300 Korean words, the sentence being spoken is highlighted and follows the
  voice, tap a sentence to move the voice there. Two layouts in settings (continuous flow or
  sentence blocks). No word is ever visually marked as new. Tap a word → word panel (pauses
  voice). Long-press a sentence → full translation, deliberately more expensive than a tap.
- **Word panel, three storeys**, always opening at the first: meaning only → three usable
  example sentences → the hanja root family full screen, with already-known words marked
  `KNOWN`. Grouping is on the real Chinese character, never the hangul syllable.
- **Two swipes**: right `Keep` (into the Notebook with its context sentence), left
  `I knew this` (corrects the engine). Closing does nothing, and that is the common case.
- **Notebook**: a journal, newest first, each word with a Thiings icon, its context sentence
  and its day. One search field replaces all filters (Korean, English, part of speech, or
  semantic domain). A word's card carries a four-step self-assessed confidence gauge
  (`Not yet` / `I recognise it` / `I understand it` / `I can use it`) with Molago's own
  estimate shown beside it, dashed — a Strava "perceived exertion" borrowing.
- **Quiz**: three questions built on the sentences just read; multiple choice for a young
  word, keyboard entry for a mature one; distractors of the same part of speech and
  frequency band, drawn from the same text; spacing ignored, one letter off counts as
  correct. Right or wrong get exactly the same treatment. At the end: nothing — no score,
  no recap, no "well done".
- **First-day calibration**: ~30 words, two large buttons, two minutes, once in a lifetime.
  Skippable.
- **Technical**: native Swift app; Postgres 16 + a Hono/Drizzle TypeScript API in Docker on
  an existing VPS behind Traefik; Google OAuth with an address allowlist; generation via
  OpenRouter; icons from the user's existing Thiings API (9 000 objects, port 3088); OCR
  native iOS Vision; morphology via Kiwi. No Supabase, no Vercel, no ffmpeg.
- **Undecided**: the voice provider and the Korean-native verification model — both to be
  settled by a blind comparative trial before any code (spec §14). No visual direction has
  been chosen yet; this session is that decision.
- **Out of scope for V1**: flashcards of any kind, a general dictionary, spoken production
  mode, subject serialisation, a "this sentence sounds odd" button, payment, and any
  non-commercial-licensed dependency.

## Brand Commitments

- **Name**: Molago. Existing logo and icons in `public/`.
- **Interface language is English** for chrome and translations; content is Korean; the
  product's own documentation is French.
- **Voice**: it announces, it never demands. Proscribed in every string: "Don't forget",
  "Your streak", "You haven't read today". One notification per day, and it is the only one
  the app ever sends.
- **User-pinned references**: the Apple design system, used with a twist rather than plain;
  Gentler Streak's register as the tonal north star (warmth, non-punitive, calm).

## Evidence on Hand

- `docs/product-spec.md` — the validated product specification (v1, 25 July 2026).
- `docs/decisions.md` — 31 decisions with their reasons.
- `docs/research/` — six research notes: vocabulary acquisition science, Korean specifics,
  motivation, the app landscape, expat daily-life vocabulary, AI-generated content.
- `docs/wireframes/` — structural wireframes from the design interview; structure and
  behaviour only, explicitly not a visual direction.
- `data/expat-lexicon.json` — hand-built list of daily-life Korean under-represented in
  official frequency lists.
- **Absent, must not be fabricated**: any real generated Korean text, any real audio, any
  benchmark of generation quality, any user or usage data. No code exists.

## Product Principles

1. **Zero debt, zero guilt.** No unread counter, no streak to hold, no catch-up, no reproach
   in any failure case. Anything that can accumulate into an obligation is cut.
2. **Spaced repetition is invisible.** It lives inside the texts and the quiz; there is never
   a pile of cards.
3. **The system observes, it never asks.** The profile is built from taps, reads and swipes,
   not from declarations. The one exception is the Notebook confidence gauge, which the user
   volunteers at rest.
4. **The app never shows doubt in front of the user.** Quality is controlled before
   publication, so there is no "report a bad sentence" button.
5. **A minimal but real effort.** Ninety seconds of active recall a day. Reading alone is
   not enough — and the fixed, announced duration is what makes him come back.

## Accessibility & Inclusion

Korean and Latin text sit side by side throughout; text size is a first-class reading
setting, and Dynamic Type must carry both scripts. Audio and text are always paired, never
alternatives. The reader is used one-handed, in motion, in the morning.
