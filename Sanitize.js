// Sanitize.js - Sensitive data detection and display masking for Omarchy Clipboard

var PATTERNS = [
  { name: "OpenAI/API Key", regex: /sk-(?:proj-|ant-|live-)?[a-zA-Z0-9_\-]{20,}/ },
  { name: "GitHub Token", regex: /gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[a-zA-Z0-9_]{22,}/ },
  { name: "AWS Key", regex: /(?:A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}/ },
  { name: "Google Key", regex: /AIza[0-9A-Za-z\-_]{35}/ },
  { name: "Slack Token", regex: /xox[baprs]-[0-9a-zA-Z]{10,48}/ },
  { name: "Stripe Secret Key", regex: /sk_live_[0-9a-zA-Z]{24}/ },
  { name: "JWT", regex: /eyJ[a-zA-Z0-9_-]{5,}\.eyJ[a-zA-Z0-9_-]{5,}\.[a-zA-Z0-9_-]{5,}/ },
  { name: "Private Key", regex: /-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/ },
  { name: "Credential KV", regex: /(?:password|passwd|secret|api_key|apikey|access_token|auth_token)\s*[:=]\s*['"]?([^\s'"]{8,})/i }
]

function detectSensitive(text) {
  if (!text || typeof text !== "string") return null
  var str = text.trim()
  if (str.length < 8) return null

  for (var i = 0; i < PATTERNS.length; i++) {
    var p = PATTERNS[i]
    if (p.regex.test(str)) {
      return { isSensitive: true, type: p.name }
    }
  }
  return null
}

function isSensitive(text) {
  return detectSensitive(text) !== null
}

function maskSecretToken(token) {
  if (token.length <= 8) return "••••••••"
  var prefixLen = Math.min(4, Math.floor(token.length / 4))
  var suffixLen = Math.min(4, Math.floor(token.length / 4))
  return token.slice(0, prefixLen) + "••••••••" + token.slice(-suffixLen)
}

function maskText(text) {
  if (!text || typeof text !== "string") return ""
  var str = text

  if (/-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/.test(str)) {
    return "-----BEGIN PRIVATE KEY----- [MASKED]"
  }

  // Check key-value credential pattern
  var kvMatch = str.match(/((?:password|passwd|secret|api_key|apikey|access_token|auth_token)\s*[:=]\s*['"]?)([^\s'"]{8,})(['"]?)/i)
  if (kvMatch) {
    return str.replace(kvMatch[0], kvMatch[1] + "••••••••" + kvMatch[3])
  }

  // Check specific token patterns
  for (var i = 0; i < PATTERNS.length; i++) {
    var p = PATTERNS[i]
    if (p.name === "Credential KV" || p.name === "Private Key") continue
    var m = str.match(p.regex)
    if (m && m[0]) {
      return str.replace(m[0], maskSecretToken(m[0]))
    }
  }

  return maskSecretToken(str)
}

if (typeof module !== "undefined") {
  module.exports = {
    detectSensitive: detectSensitive,
    isSensitive: isSensitive,
    maskText: maskText,
    maskSecretToken: maskSecretToken
  }
}
