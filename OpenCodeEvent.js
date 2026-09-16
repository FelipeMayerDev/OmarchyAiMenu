function parse(line) {
  try {
    var event = JSON.parse(String(line || ""))
    var kind = String(event.type || "")
    var text = (kind === "text" || kind === "thinking") && event.part ? String(event.part.text || "") : ""
    return {
      type: kind,
      sessionID: String(event.sessionID || ""),
      text: kind === "text" ? text : "",
      thinking: kind === "thinking" ? text : "",
      used: kind === "usage" && event.part ? Number(event.part.used) || 0 : 0,
      limit: kind === "usage" && event.part ? Number(event.part.limit) || 0 : 0
    }
  } catch (e) {
    return { type: "", sessionID: "", text: "", thinking: "", used: 0, limit: 0 }
  }
}

function choice(link) {
  var value = String(link || "")
  if (value.indexOf("choice:") !== 0) return ""
  try { return decodeURIComponent(value.substring(7)) } catch (e) { return value.substring(7) }
}

function choices(text) {
  var result = []
  var pattern = /\[([^\]]+)\]\(choice:([^)]+)\)/g
  var match
  while ((match = pattern.exec(String(text || "")) ) !== null)
    result.push({ label: match[1], value: choice("choice:" + match[2]) })
  return result
}

function withoutChoices(text) {
  return String(text || "")
    .replace(/\[([^\]]+)\]\(choice:([^)]+)\)/g, "")
    .replace(/^[ \t]*(and|or|,|\/|·|\||-)*[ \t]*$/gim, "")
    .trim()
}

function isImagePath(token) {
  return /^(file:\/\/|~\/|\/).+\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(String(token || "").trim())
}

// Markdown blocks keep growing while the answer streams, so image references
// only become renderable blocks once their path is complete.
function pushMarkdown(result, text) {
  var value = String(text || "")
  var pattern = /!\[([^\]]*)\]\(([^)]+)\)/g
  var index = 0
  var match
  while ((match = pattern.exec(value)) !== null) {
    if (isImagePath(match[2])) {
      if (match.index > index)
        result.push({ kind: "markdown", text: value.substring(index, match.index) })
      result.push({ kind: "image", path: match[2].trim(), label: match[1] })
      index = pattern.lastIndex
    }
  }
  if (index < value.length) result.push({ kind: "markdown", text: value.substring(index) })
}

function blocks(text) {
  var value = withoutChoices(text)
  var split = []
  var pattern = /```([^\n`]*)\n?([\s\S]*?)(?:```|$)/g
  var index = 0
  var match
  while ((match = pattern.exec(value)) !== null) {
    if (match.index > index)
      split.push({ kind: "markdown", text: value.substring(index, match.index) })
    split.push({
      kind: "code",
      language: String(match[1] || "code").trim() || "code",
      text: String(match[2] || "").replace(/\n$/, "")
    })
    index = pattern.lastIndex
  }
  if (index < value.length) split.push({ kind: "markdown", text: value.substring(index) })
  if (split.length === 0) split.push({ kind: "markdown", text: value })

  var result = []
  for (var i = 0; i < split.length; i++) {
    var block = split[i]
    if (block.kind !== "markdown") { result.push(block); continue }
    var lines = String(block.text).split("\n")
    var buffer = ""
    for (var j = 0; j < lines.length; j++) {
      if (isImagePath(lines[j])) {
        pushMarkdown(result, buffer)
        buffer = ""
        result.push({ kind: "image", path: lines[j].trim(), label: "" })
      } else {
        buffer += (buffer ? "\n" : "") + lines[j]
      }
    }
    pushMarkdown(result, buffer)
  }
  return result
}

if (typeof module !== "undefined") module.exports = {
  parse: parse, choice: choice, choices: choices, withoutChoices: withoutChoices, blocks: blocks
}
