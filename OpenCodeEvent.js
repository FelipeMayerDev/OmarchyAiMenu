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

function blocks(text) {
  var value = withoutChoices(text)
  var result = []
  var pattern = /```([^\n`]*)\n?([\s\S]*?)(?:```|$)/g
  var index = 0
  var match
  while ((match = pattern.exec(value)) !== null) {
    if (match.index > index)
      result.push({ kind: "markdown", text: value.substring(index, match.index) })
    result.push({
      kind: "code",
      language: String(match[1] || "code").trim() || "code",
      text: String(match[2] || "").replace(/\n$/, "")
    })
    index = pattern.lastIndex
  }
  if (index < value.length) result.push({ kind: "markdown", text: value.substring(index) })
  if (result.length === 0) result.push({ kind: "markdown", text: value })
  return result
}

if (typeof module !== "undefined") module.exports = {
  parse: parse, choice: choice, choices: choices, withoutChoices: withoutChoices, blocks: blocks
}
