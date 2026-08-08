# mochi

A desktop pet that coaches you while you write on Substack.

Not a grammar checker. mochi enforces one specific rulebook — Kaguura Gichuru's
*The Write Path* — and tells you when you're breaking it, live, while you write.

Turn it on when you sit down to write. It watches the Substack editor and talks.
It never blocks, never pauses you, and never edits your text.

## Why this exists

Most writing advice is generic. This playbook isn't — it has opinions:

- Write to one person, not a stadium
- Kill adverbs, use heavier verbs
- Active voice only
- Second draft = first draft − 10%
- 800–2000 words, ~1800 is the sweet spot
- Calm Story → Plunge into Despair → Solution → Higher Ground
- Titles are outcome-driven, never poetic and never academic
- Vary paragraph length; don't be a LinkedIn robot

Those are checkable. mochi checks them.

## How it works

**Writing mode is explicit.** Off by default; mochi is inert and captures nothing.
Turn it on and it watches — you always know which state it's in.

**It reads the Substack editor** by capturing that one window, only while it's
frontmost. Not the whole screen, and never when you're doing something else.

**Two tiers of critique:**

*Deterministic* — pure Lua, instant, free, on every change. Adverbs, passive voice,
stadium-talk, inflated words, word count, paragraph rhythm, title shape, and the
10% rule measured against your own earlier draft.

*Judgement* — `claude -p`, at natural breaks only. Story arc, whether the opening
earns its place, concrete vs abstract, and turning a finished essay into the three
Notes the playbook prescribes.

The deterministic tier is the foundation. It can't be wrong about your text and it
costs nothing.

## Design rules

Carried over from [cost](https://github.com/mattypark/costpriority), where they were
learned the hard way:

- **An LLM never decides timing.** A clock does. The model only chooses wording.
- **Model output is never trusted.** Strict JSON, tolerant parser, deterministic
  fallback.
- **Always say which engine produced a critique.** Silent degradation looks like a
  working feature.
- **No Accessibility permission.** Mouse is polled; text entry goes through a
  webview.
- **Nothing calls Claude without a visible reason and a cost story.**

## Privacy

mochi captures a single window, only while writing mode is on and only while that
window is frontmost. OCR runs on-device via Vision — image data never leaves the
machine.

What *is* sent to Anthropic, and only when the judgement tier runs: your draft text.
That's the whole point of it. If that isn't acceptable, the deterministic tier does
most of the work with nothing leaving the machine at all.

## Status

Not built yet. See the handoff plan for what to research first.

## Licence

MIT
