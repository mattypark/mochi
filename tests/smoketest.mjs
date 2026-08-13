// End-to-end check with no browser and no Substack involved.
//
//   node tests/smoketest.mjs
//
// Connects to the bridge exactly as the extension does and sends a draft built
// to trip specific rules. If the pet says something, the whole chain works:
// socket → decode → rules → nag → bubble.
//
// Requires writing mode to be ON — the bridge is closed otherwise, and that is
// the point of it, so a refused connection here is a pass for privacy and a
// fail for this test. The message below says which.

const URL = "ws://127.0.0.1:27852/mochi";

const draft = {
  kind: "draft",
  url: "https://mattypark.substack.com/publish/post/smoketest",
  // Deliberately bad: a poetic title, a stadium opener, an adverb, a passive,
  // an inflated word, and a wall of text.
  title: "Sifting Through the Noise",
  subtitle: "",
  blocks: [
    { tag: "p", text: "Hey guys, welcome back to the newsletter." },
    { tag: "p", text: "He quickly opened the door. The article was written by a stranger. We utilize the platform in order to reach people." },
    { tag: "blockquote", text: "Quotes are honestly never critiqued, deliberately." },
    { tag: "p", text: "One. Two. Three. Four. Five. Six. Seven. Eight." },
  ],
  words: 420,
  caret: null,
};

draft.body = draft.blocks.map((b) => b.text).join("\n\n");

const socket = new WebSocket(URL);

const timeout = setTimeout(() => {
  console.error("timed out with no reply — is Hammerspoon running?");
  process.exit(1);
}, 5000);

socket.addEventListener("open", () => {
  console.log("connected to", URL);
  socket.send(JSON.stringify(draft));
});

socket.addEventListener("message", (event) => {
  clearTimeout(timeout);
  console.log("bridge replied:", event.data);
  console.log("\nmochi should now be showing a bubble with 4 findings.");
  socket.close();
  process.exit(0);
});

socket.addEventListener("error", () => {
  clearTimeout(timeout);
  console.error(
    "could not connect.\n" +
    "  If writing mode is OFF, this is correct — the bridge is closed.\n" +
    "  Turn it on from the menu bar (mochi ●) and run this again."
  );
  process.exit(1);
});
