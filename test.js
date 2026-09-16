const assert = require("node:assert/strict")
const fs = require("node:fs")
const { parse, choice, choices, withoutChoices, blocks } = require("./OpenCodeEvent.js")

assert.deepEqual(parse('{"type":"text","sessionID":"ses_1","part":{"text":"hello"}}'), {
  type: "text",
  sessionID: "ses_1",
  text: "hello",
  thinking: "",
  used: 0,
  limit: 0,
})
assert.deepEqual(parse('{"type":"thinking","sessionID":"ses_1","part":{"text":"hmm"}}'), {
  type: "thinking",
  sessionID: "ses_1",
  text: "",
  thinking: "hmm",
  used: 0,
  limit: 0,
})
assert.deepEqual(parse('{"type":"usage","sessionID":"ses_1","part":{"used":100,"limit":200}}'), {
  type: "usage",
  sessionID: "ses_1",
  text: "",
  thinking: "",
  used: 100,
  limit: 200,
})
assert.deepEqual(parse("not json"), { type: "", sessionID: "", text: "", thinking: "", used: 0, limit: 0 })
assert.equal(choice("choice:Fix%20it"), "Fix it")
assert.equal(choice("https://example.com"), "")
assert.deepEqual(choices("[Fix it](choice:Fix%20it) and [Explain](choice:Explain)"), [
  { label: "Fix it", value: "Fix it" },
  { label: "Explain", value: "Explain" },
])
assert.equal(withoutChoices("Answer\n\n[Fix](choice:Fix) and [Explain](choice:Explain)"), "Answer")
assert.deepEqual(blocks("Before\n```bash\necho ok\n```\nAfter"), [
  { kind: "markdown", text: "Before\n" },
  { kind: "code", language: "bash", text: "echo ok" },
  { kind: "markdown", text: "\nAfter" },
])

const assistant = fs.readFileSync("Assistant.qml", "utf8")
const runner = fs.readFileSync("bin/ai-run", "utf8")
assert.match(assistant, /bin\/ai-run/)
assert.match(runner, /permission/)
assert.match(runner, /subprocess\.Popen/)
assert.match(runner, /threading\.Timer\(TIMEOUT, kill\)/)
assert.match(runner, /thread\.started/)
assert.match(runner, /content_block_delta/)
assert.match(runner, /text_delta/)
assert.match(runner, /message\.part\.delta/)
assert.match(runner, /"opencode", "serve"/)
assert.match(runner, /danger-full-access/)
assert.match(runner, /dangerously-skip-permissions/)
assert.match(runner, /--approval-mode/)
assert.match(assistant, /property bool yolo: false/)
assert.match(assistant, /required property string thinking/)
assert.match(assistant, /font\.italic: true/)
assert.match(assistant, /Save settings/)
assert.match(assistant, /saveFlash/)
assert.match(assistant, /settingsLoaded/)
assert.match(assistant, /thinkingPulse/)
assert.match(assistant, /notify-send/)
assert.match(assistant, /pendingDots/)
assert.match(assistant, /usageLabel/)
assert.match(assistant, /contextUsed/)
assert.match(assistant, /onAccepted: root\.ask\(text\)/)
assert.match(assistant, /YOLO mode on/)
assert.match(runner, /emit_thinking/)
assert.match(runner, /thinking_delta/)
assert.match(runner, /"reasoning"/)
assert.match(assistant, /root\.finish\(124\)/)
assert.match(assistant, /solidBackground: Qt\.rgba\(background\.r, background\.g, background\.b, 1\)/)
assert.match(assistant, /borderSpec: root\.borderSpec/)
assert.match(assistant, /WlrLayershell\.namespace: "omarchy-menu"/)
assert.match(assistant, /id: hideTimer/)
assert.match(assistant, /function close\(\) \{ dismiss\(\) \}/)
assert.match(assistant, /Behavior on opacity/)
assert.match(assistant, /Style\.bar\.sizeHorizontal \+ Style\.gapsOut/)
assert.match(assistant, /NumberAnimation \{ duration: 240; easing\.type: Easing\.OutCubic \}/)
assert.match(assistant, /sequence: "Ctrl\+P"/)
assert.match(assistant, /context: Qt\.WindowShortcut/)
assert.match(assistant, /parent: root\.detached \? windowHost : card/)
assert.match(assistant, /FloatingWindow \{/)
assert.match(assistant, /Text\.MarkdownText/)
assert.match(assistant, /onLinkActivated/)
assert.match(assistant, /OpenCodeEvent\.choice/)
assert.match(assistant, /OpenCodeEvent\.choices/)
assert.match(assistant, /bordered: true/)
assert.match(assistant, /OpenCodeEvent\.blocks/)
assert.match(assistant, /text: "Copy"/)
assert.match(assistant, /PanelActionButton/)
assert.match(assistant, /SearchableDropdown/)
assert.match(assistant, /ButtonGroup/)
assert.match(assistant, /text\.toLowerCase\(\) === "\/new"/)
assert.match(assistant, /messages\.clear\(\)/)

const bar = fs.readFileSync("BarWidget.qml", "utf8")
assert.match(bar, /Qt\.RightButton/)
assert.match(bar, /settings/)

const harnessInfo = fs.readFileSync("bin/harness-info", "utf8")
for (const harness of ["opencode", "codex", "claude", "omp"])
  assert.match(harnessInfo, new RegExp(`"${harness}"`))
assert.match(harnessInfo, /for key, label in NAMES\.items\(\) if shutil\.which\(key\)/)
assert.match(harnessInfo, /"yolo": bool/)

const manifest = JSON.parse(fs.readFileSync("manifest.json", "utf8"))
assert.deepEqual(manifest.kinds, ["overlay", "bar-widget"])
assert.equal(manifest.entryPoints.overlay, "Assistant.qml")
assert.equal(manifest.omarchy, undefined)
