# Prior art, and what to steal from it

Notes from surveying open-source Grammarly alternatives, and the answer to
"can mochi do Google Docs too".

## The projects worth reading

| Project | Licence | Why it matters here |
|---|---|---|
| [Harper](https://github.com/automattic/harper) (Automattic) | Apache-2.0 | Rust core, `harper.js` via WebAssembly, plus a language server and a Chrome extension. Offline, on-device, sub-10ms suggestions. The serious reference implementation. |
| [write-better](https://github.com/justiceo/write-better) | open source | Chrome extension doing style suggestions *on Google Docs*. Port of `write-good`. Under 100KB, works offline. |
| [GemType](https://github.com/riponcm/GemType) | open source | Grammarly-alike for Chrome/Safari using your own Gemini key. Same architecture mochi's judgement tier uses: bring-your-own-model, no account. |
| [TextChecker](https://github.com/codextde/textchecker) | open source | LanguageTool-extension alternative, AI models via your own API keys. |

**What mochi should actually take from Harper:** not the product — mochi is not a
grammar checker and must not drift into being one — but its *parsing*. mochi's
adverb and passive-voice rules are string heuristics: `-ly` minus a deny-list, and
"a form of *to be* followed by something ending in -ed". Harper does real
tokenisation and part-of-speech work. If the false-positive rate on Matthew's
actual drafts turns out to be annoying, `harper.js` (WASM, runs in the extension)
is the upgrade path, and the rules stay where they are — only the detection under
them changes.

## Google Docs: the honest answer

**The DOM approach that works on Substack cannot work on Google Docs.** Docs
renders the document to a `<canvas>`, and its annotation API is restricted to
Google-whitelisted vendors — which is why Grammarly's Docs support is a special
partnership and not something a third party can reimplement. There is no text in
the DOM to read.

That leaves three real options:

1. **Google Docs API** (`documents.get`) — sanctioned, gives exact text with
   structure. Reads the *saved* document, so it lags typing by a few seconds and
   is not per-keystroke live. Matthew already has the `gws` CLI with Workspace
   OAuth, so the auth problem is solved. **This is the one to build.**
2. **Apps Script bound add-on** — runs inside the doc, can read live. Means
   maintaining a second codebase in a second language with its own deploy story,
   and the critique surface would be a Docs sidebar rather than the pet.
3. **Accessibility API / OCR** — rejected for the same reasons as before. No
   Accessibility permission, ever.

Option 1 changes what mochi *is* on Docs, and that has to be said plainly rather
than papered over: on Substack it watches you type, on Docs it reviews what you
have saved. Same rules, same voice, different tempo. The pet must say which one
it's doing — silent degradation looking like a working feature is the failure
mode this project keeps designing against.

**Substack stays primary.** mochi is a Substack pet; Docs is a second adapter
behind the same `draft` contract the extension already emits
(`{title, subtitle, blocks[], body, words}`). If supporting Docs ever requires
bending that contract or the playbook, Docs loses.
