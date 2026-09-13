function fuzzyMatch(pattern, text) {
  var p = String(pattern || "").trim().toLowerCase()
  var t = String(text || "").trim().toLowerCase()

  if (!p) return { match: true, score: 0, indices: [] }
  if (!t) return { match: false, score: 0, indices: [] }

  var subIdx = t.indexOf(p)
  if (subIdx >= 0) {
    var subIndices = []
    for (var k = 0; k < p.length; k++) {
      subIndices.push(subIdx + k)
    }
    var bonus = (subIdx === 0) ? 100 : (/[^a-zA-Z0-9]/.test(t.charAt(subIdx - 1)) ? 80 : 50)
    return {
      match: true,
      score: 1000 + bonus - (t.length - p.length),
      indices: subIndices
    }
  }

  var pLen = p.length
  var tLen = t.length
  if (pLen > tLen) return { match: false, score: 0, indices: [] }

  var pIdx = 0
  var score = 0
  var indices = []
  var prevMatchIdx = -1

  for (var tIdx = 0; tIdx < tLen && pIdx < pLen; tIdx++) {
    var pChar = p.charAt(pIdx)
    var tChar = t.charAt(tIdx)

    if (pChar === tChar) {
      indices.push(tIdx)
      var charScore = 10

      if (tIdx === 0 || /[^a-zA-Z0-9]/.test(t.charAt(tIdx - 1))) {
        charScore += 25
      }

      if (prevMatchIdx === tIdx - 1) {
        charScore += 20
      }

      score += charScore
      prevMatchIdx = tIdx
      pIdx++
    }
  }

  if (pIdx < pLen) {
    return { match: false, score: 0, indices: [] }
  }

  score -= (tLen - pLen)
  return { match: true, score: score, indices: indices }
}

if (typeof module !== "undefined") {
  module.exports = {
    fuzzyMatch: fuzzyMatch
  }
}
