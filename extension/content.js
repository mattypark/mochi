// mochi — reads the Substack editor and hands the draft to the pet.
//
// Why an extension and not screen capture: the editor is a ProseMirror tree in
// this page. Reading it gives the *whole* document — including the paragraphs
// scrolled off screen — as exact text, with no OCR error, no Screen Recording
// permission, and none of the stitching that capturing a scrolling viewport
// would force. Capture was the fallback plan and it is not needed.
//
// Status is shown on the page, not in the console. Two attempts at verifying
// this through DevTools failed — first because a content script's globals live
// in an isolated world the page console cannot see, then because `world: MAIN`
// is not reliable across Chromium forks. A console is a bad status display
// regardless: it is a second place to go to answer "is it working". The HUD in
// the corner answers that by being looked at.
//
// Stage 2 sends the same snapshots on to Hammerspoon over a local WebSocket.
// Nothing here talks to the network yet.

(() => {
  "use strict";

  const DEBOUNCE_MS = 400;   // long enough to not fire mid-word, short enough to feel live
  const RECONNECT_MS = 4000; // floor between connection attempts while mochi is asleep
  const BRIDGE_URL = "ws://127.0.0.1:27852/mochi";
  const LOG_PREFIX = "[mochi]";

  // ------------------------------------------------------------------ finding

  // Substack ships class names that move between deploys, so every lookup is a
  // cascade ending in a structural guess. A selector that silently matches
  // nothing would look exactly like an empty draft, which is why `describe()`
  // below reports which strategy actually won.

  /// The ProseMirror body. Falls back to the largest contenteditable on the page,
  /// which is the editor on every Substack layout seen so far.
  function findEditor() {
    // Substack's own test hook, and the most stable handle on the page:
    //   <div contenteditable="true" data-testid="editor" class="tiptap ProseMirror mousetrap">
    const tagged = document.querySelector('[data-testid="editor"][contenteditable="true"]');
    if (tagged) return { node: tagged, how: "data-testid" };

    const direct = document.querySelector('div.ProseMirror[contenteditable="true"]');
    if (direct) return { node: direct, how: "ProseMirror" };

    const editables = Array.from(
      document.querySelectorAll('[contenteditable="true"]')
    );
    if (editables.length === 0) return null;

    const largest = editables.reduce((best, node) =>
      node.textContent.length > best.textContent.length ? node : best
    );
    return { node: largest, how: "largest-contenteditable" };
  }

  /// Title and subtitle live outside the ProseMirror doc, in their own growing
  /// fields, so they are read separately.
  ///
  /// They are resolved together on purpose. "Add a subtitle…" contains the
  /// substring "title", so a naive `placeholder*="title"` matches the subtitle
  /// field and — on any layout where the title is not a textarea — silently
  /// reports the subtitle as the title. Classifying every candidate in one pass
  /// makes that impossible: subtitle is claimed first, and title takes what is
  /// left.
  function findFields() {
    const candidates = Array.from(
      document.querySelectorAll("textarea, input[type=text], [contenteditable=true]")
    );

    let title = null;
    let subtitle = null;

    for (const node of candidates) {
      const hint = (
        node.getAttribute("placeholder") ||
        node.getAttribute("data-testid") ||
        node.getAttribute("aria-label") ||
        ""
      ).toLowerCase();

      if (!subtitle && hint.includes("subtitle")) {
        subtitle = { node, how: "placeholder" };
      } else if (!title && hint.includes("title")) {
        title = { node, how: "placeholder" };
      }
    }

    if (!title) {
      const heading = document.querySelector("h1 textarea, h1[contenteditable=true], h1");
      if (heading) title = { node: heading, how: "h1" };
    }

    return { title, subtitle };
  }

  function valueOf(found) {
    if (!found) return "";
    const { node } = found;
    const raw = "value" in node ? node.value : node.textContent;
    return (raw || "").trim();
  }

  // ------------------------------------------------------------------ reading

  // Block-level children of the editor, in document order. Paragraph structure
  // is not decoration here — the wall-of-text and LinkedIn-robot rules are both
  // about where the breaks fall, so blocks are kept apart rather than joined
  // into one string.
  const BLOCK_TAGS = new Set([
    "P", "H1", "H2", "H3", "H4", "H5", "H6",
    "BLOCKQUOTE", "PRE", "LI", "FIGCAPTION",
  ]);

  function readBlocks(editor) {
    const blocks = [];

    for (const node of editor.querySelectorAll(Array.from(BLOCK_TAGS).join(","))) {
      // A LI inside a UL inside the editor is a block; a P wrapping that LI is
      // not, or the same text would be counted twice.
      if (node.querySelector(Array.from(BLOCK_TAGS).join(","))) continue;

      const text = (node.textContent || "").replace(/\s+/g, " ").trim();

      // A paragraph inside a blockquote is someone else's sentence. Reporting
      // Kevin Systrom's adverbs back to the person quoting him is exactly the
      // kind of false positive that gets a checker switched off, so the quote
      // keeps its own tag and the rules skip it.
      const tag = node.closest("blockquote")
        ? "blockquote"
        : node.tagName.toLowerCase();

      blocks.push({ tag, text });
    }

    return blocks;
  }

  /// Where the caret sits, as a character offset into the joined body text.
  /// Used to keep a critique from pointing at the sentence still being typed.
  function readCaret(editor) {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0) return null;

    const range = selection.getRangeAt(0);
    if (!editor.contains(range.startContainer)) return null;

    const upto = range.cloneRange();
    upto.selectNodeContents(editor);
    upto.setEnd(range.startContainer, range.startOffset);
    return upto.toString().length;
  }

  function countWords(text) {
    const matches = text.match(/[A-Za-z0-9’'’-]+/g);
    return matches ? matches.length : 0;
  }

  function snapshot() {
    const editor = findEditor();
    if (!editor) return null;

    const blocks = readBlocks(editor.node);
    const body = blocks.map((block) => block.text).join("\n\n");
    const fields = findFields();

    return {
      kind: "draft",
      url: location.href,
      at: Date.now(),
      title: valueOf(fields.title),
      subtitle: valueOf(fields.subtitle),
      blocks,
      body,
      words: countWords(body),
      caret: readCaret(editor.node),
      // How each field was located, so a Substack redesign shows up as a changed
      // strategy rather than as a draft that mysteriously went blank.
      via: {
        editor: editor.how,
        title: fields.title?.how || "none",
        subtitle: fields.subtitle?.how || "none",
      },
    };
  }

  // ------------------------------------------------------------------ emitting

  // The pet is the status display. There is deliberately nothing drawn on the
  // page: an editor is for writing in, and a chip in the corner of it is one
  // more thing to look at while trying not to look at things.

  let socket = null;
  let reconnectAt = 0;

  /// Connect only when there is something to send. The bridge is closed
  /// whenever writing mode is off, so a failed connection is the normal resting
  /// state and must stay silent — retrying loudly would fill the console with
  /// noise every few seconds all day.
  function ensureSocket() {
    if (socket && socket.readyState <= WebSocket.OPEN) return socket;

    const now = Date.now();
    if (now < reconnectAt) return null;
    reconnectAt = now + RECONNECT_MS;

    try {
      socket = new WebSocket(BRIDGE_URL);
      socket.addEventListener("close", () => { socket = null; });
      socket.addEventListener("error", () => { socket = null; });
    } catch (_) {
      socket = null;
    }

    return socket;
  }

  let lastBody = null;

  function emit(draft) {
    const live = ensureSocket();
    if (live && live.readyState === WebSocket.OPEN) {
      live.send(JSON.stringify(draft));
    }
  }

  function tick() {
    const draft = snapshot();

    // Being unable to find the editor must never look like an empty draft —
    // that is how a broken selector survives a redesign unnoticed for weeks. It
    // is reported as a distinct message so the pet can say which one it is.
    if (!draft) {
      const live = ensureSocket();
      if (live && live.readyState === WebSocket.OPEN) {
        live.send(JSON.stringify({ kind: "lost", url: location.href }));
      }
      return;
    }

    // Caret moves and re-renders fire constantly; only a text change is news.
    const fingerprint = draft.title + " " + draft.subtitle + " " + draft.body;
    if (fingerprint === lastBody) return;
    lastBody = fingerprint;

    emit(draft);
  }

  let pending = null;

  function schedule() {
    if (pending) clearTimeout(pending);
    pending = setTimeout(() => {
      pending = null;
      tick();
    }, DEBOUNCE_MS);
  }

  // -------------------------------------------------------------------- watching

  // The editor mounts after navigation on this SPA, so watching document.body
  // and re-resolving the editor each tick is more robust than binding to a node
  // that may be replaced under us.
  const observer = new MutationObserver(schedule);
  observer.observe(document.body, {
    subtree: true,
    childList: true,
    characterData: true,
  });

  document.addEventListener("selectionchange", schedule, { passive: true });

  // Available from the DevTools console *if* its context is switched from "top"
  // to this extension. The HUD is the supported way to check status; this is
  // here for poking at a specific field.
  window.__mochi = { snapshot, tick };

  console.log(LOG_PREFIX, "watching — status is the chip in the bottom-right corner.");
  schedule();
})();
