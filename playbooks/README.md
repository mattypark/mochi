# playbooks

The opinions mochi enforces. Everything it says traces back to a line in one of
these files — mochi has no generic writing advice of its own, and should never
invent any.

| File | Author | Scope |
|---|---|---|
| `write-path.md` | Kaguura Gichuru | Craft: sentences, paragraphs, structure, titles |
| `slay-with-finances.md` | Jessica Onne | Strategy: positioning, offers, market size, engagement time |

`write-path.md` is **not in the repo yet** — only excerpts of it have been pasted
into a session, and a playbook mochi quotes from needs to be complete or it will
paraphrase from memory, which is exactly the failure the design rules out. Paste
the full essay into that file before the judgement tier ships.

## Which tier enforces what

The two playbooks work at different distances, and that decides where each rule
lives.

**Deterministic tier** (`hammerspoon/mochi/rules.lua`) — in-draft, checkable
without a model. Almost all of it comes from *The Write Path*: adverbs, passive
voice, stadium-talk, inflated words, word band, paragraph rhythm, title shape,
the 10% rule.

**Judgement tier** (`brain.lua`) — in-draft, needs reading comprehension. Story
arc, whether the opening earns its place, concrete vs abstract, the Multiplier.
From *Slay with Finances*: does this post connect to an offer, and is the
perspective specific enough that a reader could describe it in one sentence?

**Cross-post tier** — not yet built, and the reason *Slay with Finances* can't
just be bolted onto the existing two. Its central rules are ratios across a body
of work, not properties of one draft:

- 1 in every 3-4 posts makes a direct offer
- posting 2-4x/week, not daily
- engagement capped near 75 minutes/week
- the market is big enough that 1% converting is a real business

None of that is visible in the draft on screen. It needs mochi to remember what
was published and when, which is Stage 8.

## Voice

mochi is not a style cop applying these uniformly forever. It learns how Matthew
actually writes and gets more specific over time — see Stage 7. A rule the
playbook states and Matthew consistently breaks on purpose is a fact about his
voice, not a violation to repeat every session.
