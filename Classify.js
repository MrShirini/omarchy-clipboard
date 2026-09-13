var URL_REGEX = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i
var WWW_URL_REGEX = /^www\.[a-z0-9-]+(\.[a-z0-9-]+)+([/?#][^\s]*)?$/i

var COLOR_HEX_REGEX = /^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i
var COLOR_FUNC_REGEX = /^(rgb|rgba|hsl|hsla)\(\s*[\d.]+%?\s*,\s*[\d.]+%?\s*,\s*[\d.]+%?(\s*,\s*[\d.]+%?)?\s*\)$/i

var CODE_PATTERNS = [
  /^```[\s\S]*```$/,
  /^(<\?xml|<!doctype\s+html|<html|<div|<script|<style|<svg)[\s\S]*>/i,
  /^\s*[{\[][\s\S]*[}\]]\s*$/,
  /^(import|export)\s+.*\s+from\s+['"].*['"]/m,
  /^(const|let|var)\s+[a-zA-Z0-9_$]+\s*=\s*/m,
  /^\s*(function\s*[a-zA-Z0-9_$]*\s*\(|def\s+[a-zA-Z0-9_]+\s*\(|fn\s+[a-zA-Z0-9_]+\s*\()/m,
  /^\s*(public|private|protected)\s+(static\s+)?/m,
  /^\s*(class|interface|struct|enum)\s+[A-Za-z0-9_$]+/m,
  /^\s*(SELECT|INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+/i,
  /^\s*#[!][\/a-z0-9_]+/m
]

var TYPE_META = {
  all:   { id: "all",   label: "All",   icon: "󰄲" },
  text:  { id: "text",  label: "Text",  icon: "󰦨" },
  code:  { id: "code",  label: "Code",  icon: "󰘦" },
  link:  { id: "link",  label: "Link",  icon: "󰌹" },
  image: { id: "image", label: "Image", icon: "󰋩" },
  file:  { id: "file",  label: "File",  icon: "󰈔" },
  color: { id: "color", label: "Color", icon: "󰏘" }
}

function isUrl(text) {
  var str = String(text || "").trim()
  return URL_REGEX.test(str) || WWW_URL_REGEX.test(str)
}

function isColor(text) {
  var str = String(text || "").trim()
  return COLOR_HEX_REGEX.test(str) || COLOR_FUNC_REGEX.test(str)
}

function isCode(text) {
  var str = String(text || "").trim()
  if (!str) return false

  for (var i = 0; i < CODE_PATTERNS.length; i++) {
    if (CODE_PATTERNS[i].test(str)) {
      return true
    }
  }

  if (str.indexOf("\n") > 0) {
    var codeIndicators = (str.match(/[{};=><\(\)\[\]]/g) || []).length
    var words = (str.match(/\b[a-zA-Z_][a-zA-Z0-9_]*\b/g) || []).length
    if (codeIndicators >= 6 && words > 0 && (codeIndicators / words) > 0.35) {
      return true
    }
  }

  return false
}

function classifyEntry(entry, hasFilePaths) {
  if (!entry) return "text"
  if (entry.type === "image") return "image"
  if (entry.mime === "text/uri-list" || hasFilePaths === true) return "file"

  var text = String(entry.text || "").trim()
  if (!text) return "text"

  if (isColor(text)) return "color"
  if (isUrl(text)) return "link"
  if (isCode(text)) return "code"

  return "text"
}

if (typeof module !== "undefined") {
  module.exports = {
    TYPE_META: TYPE_META,
    isUrl: isUrl,
    isColor: isColor,
    isCode: isCode,
    classifyEntry: classifyEntry
  }
}
