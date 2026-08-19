// Checks every link in the chain and says which one is broken.
//
//   node tests/doctor.mjs
//
// Written because "it doesn't work" was, five times running, one of five very
// different problems — and telling them apart meant reading a log, checking a
// port, and squinting at a version number in a browser tab. This does all of
// that and prints the one thing to go fix.

import { execSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const REPO = new URL("..", import.meta.url).pathname;
const HS = join(homedir(), ".hammerspoon");
const LOG = join(HS, "mochi.log");
const PORT = 27852;

const pass = (m) => console.log(`  \x1b[32mok\x1b[0m    ${m}`);
const fail = (m, fix) => {
  console.log(`  \x1b[31mFAIL\x1b[0m  ${m}`);
  if (fix) console.log(`        → ${fix}`);
  return false;
};
const warn = (m) => console.log(`  \x1b[33m··\x1b[0m    ${m}`);

function quiet(cmd) {
  try {
    return execSync(cmd, { stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch {
    return null;
  }
}

console.log("\nmochi doctor\n");

// 1 — Hammerspoon -------------------------------------------------------------

let ok = true;

if (quiet("pgrep -f 'Hammerspoon.app/Contents/MacOS/Hammerspoon'")) {
  pass("Hammerspoon is running");
} else {
  ok = fail("Hammerspoon is not running", "open -a Hammerspoon");
}

// 2 — the pet loaded ----------------------------------------------------------

const petbus = join(HS, "petbus.log");
if (existsSync(petbus) && readFileSync(petbus, "utf8").includes("mochi loaded")) {
  pass("mochi is loaded by Hammerspoon");
} else {
  ok = fail("mochi never loaded", 'add require("mochi") to ~/.hammerspoon/init.lua');
}

// 3 — installed copy matches the repo ----------------------------------------

const drift = quiet(`diff -rq "${REPO}hammerspoon/mochi" "${join(HS, "mochi")}" 2>/dev/null`);
if (drift) {
  warn("the installed pet differs from the repo — run ./install.sh");
} else {
  pass("installed pet matches the repo");
}

// 4 — the extension on disk ---------------------------------------------------

const manifest = JSON.parse(readFileSync(join(REPO, "extension/manifest.json"), "utf8"));
pass(`extension on disk is v${manifest.version}`);

// 5 — writing mode / the bridge ----------------------------------------------

const open = quiet(`nc -z 127.0.0.1 ${PORT} && echo open`);

if (!open) {
  fail(
    "writing mode is OFF — the bridge port is closed",
    "click the dog → Turn writing mode on, then run this again"
  );
  console.log("\n(that is not a bug: mochi closes the socket when it isn't reading)\n");
  process.exit(1);
}

pass(`writing mode is ON — bridge listening on ${PORT}`);

// 6 — has the browser ever connected? ----------------------------------------

const log = existsSync(LOG) ? readFileSync(LOG, "utf8") : "";
const drafts = (log.match(/draft received/g) || []).length;
const fromBrowser = (log.match(/draft received: (?!420 words)/g) || []).length;

if (drafts === 0) {
  warn("no draft has ever reached the pet");
} else if (fromBrowser === 0) {
  warn(`${drafts} draft(s) received — all from this test script, none from the browser`);
} else {
  pass(`${fromBrowser} draft(s) received from the browser`);
}

// 7 — end to end --------------------------------------------------------------

const draft = {
  kind: "draft",
  url: "https://mattypark.substack.com/publish/post/doctor",
  title: "Sifting Through the Noise",
  subtitle: "",
  blocks: [
    { tag: "p", text: "Hey guys, welcome back to the newsletter." },
    { tag: "p", text: "He quickly opened the door. The article was written by a stranger." },
    { tag: "blockquote", text: "Quotes are honestly never critiqued, deliberately." },
    { tag: "p", text: "One. Two. Three. Four. Five. Six. Seven. Eight." },
  ],
  words: 999,
};
draft.body = draft.blocks.map((b) => b.text).join("\n\n");

const socket = new WebSocket(`ws://127.0.0.1:${PORT}/mochi`);

const timer = setTimeout(() => {
  fail("the bridge accepted a connection but never replied");
  process.exit(1);
}, 5000);

socket.addEventListener("open", () => socket.send(JSON.stringify(draft)));

socket.addEventListener("message", (event) => {
  clearTimeout(timer);

  const reply = JSON.parse(event.data);
  const marks = reply.marks || [];

  pass(`sent a draft, got ${marks.length} marks back`);

  // The blockquote is block 3 and must never be marked — someone else's
  // sentence is not the writer's problem.
  const quoted = marks.filter((m) => m.block === 3);
  if (quoted.length) {
    ok = fail(`the blockquote was marked ${quoted.length} time(s)`);
  } else {
    pass("the blockquote was left alone");
  }

  console.log("\n  marks the page would draw:");
  for (const m of marks) {
    console.log(`    block ${m.block}  ${m.rule.padEnd(9)} ${m.severity.padEnd(11)} ${m.text ?? ""}`);
  }

  console.log(
    ok
      ? "\n\x1b[32mThe Mac half works end to end.\x1b[0m mochi is showing a bubble right now."
      : "\n\x1b[31mSomething is wrong above.\x1b[0m"
  );

  if (fromBrowser === 0) {
    console.log(
      "\nThe browser half has never connected. Reload the extension:\n" +
      `  comet://extensions → mochi → ⟳  (must read v${manifest.version})\n` +
      "  then ⌘R the Substack draft tab.\n"
    );
  }

  socket.close();
  process.exit(ok ? 0 : 1);
});

socket.addEventListener("error", () => {
  clearTimeout(timer);
  fail("could not connect to the bridge", "turn writing mode on");
  process.exit(1);
});
