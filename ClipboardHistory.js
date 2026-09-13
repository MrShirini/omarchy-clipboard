var MAX_ENTRY_TEXT_LENGTH = 64 * 1024 // 64 KiB
var MAX_TOTAL_HISTORY_BYTES = 1024 * 1024 // 1 MiB

function normalizeTags(tags) {
  if (!Array.isArray(tags)) return []
  var result = []
  for (var i = 0; i < tags.length; i++) {
    var tag = String(tags[i] || "").trim()
    if (tag && result.indexOf(tag) < 0) {
      result.push(tag)
    }
  }
  return result
}

function normalizeEntry(value) {
  if (typeof value === "string") {
    var trimmed = value.trim()
    if (trimmed.length === 0) return null
    var textVal = value
    var truncated = false
    if (textVal.length > MAX_ENTRY_TEXT_LENGTH) {
      textVal = textVal.slice(0, MAX_ENTRY_TEXT_LENGTH)
      truncated = true
    }
    var res = { type: "text", text: textVal, favorite: false }
    if (truncated) res.truncated = true
    return res
  }

  if (!value || typeof value !== "object") return null

  var isFav = value.favorite === true
  var type = String(value.type || value.kind || "")
  if (type === "text") {
    var rawText = String(value.text || "")
    if (rawText.trim().length === 0) return null
    var textVal = rawText
    var truncated = value.truncated === true
    if (textVal.length > MAX_ENTRY_TEXT_LENGTH) {
      textVal = textVal.slice(0, MAX_ENTRY_TEXT_LENGTH)
      truncated = true
    }
    var entry = { type: "text", text: textVal }
    if (value.mime) entry.mime = String(value.mime)
    if (truncated) entry.truncated = true
    if (isFav) entry.favorite = true
    if (value.tags) {
      var tags = normalizeTags(value.tags)
      if (tags.length > 0) entry.tags = tags
    }
    return entry
  }

  if (type === "image") {
    var path = String(value.path || "")
    if (!path) return null
    var entry = {
      type: "image",
      path: path,
      mime: String(value.mime || "image/png")
    }
    if (value.capturedAt !== undefined && value.capturedAt !== null)
      entry.capturedAt = String(value.capturedAt)
    if (value.bytes !== undefined && value.bytes !== null) {
      var numBytes = Number(value.bytes)
      if (!isNaN(numBytes) && numBytes > 0) entry.bytes = numBytes
    }
    if (isFav) entry.favorite = true
    if (value.tags) {
      var imgTags = normalizeTags(value.tags)
      if (imgTags.length > 0) entry.tags = imgTags
    }
    return entry
  }

  return null
}

function entryKey(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image:" + String(entry.path || "")
  return "text:" + String(entry.text || "")
}

function parseHistoryResult(raw) {
  var str = String(raw || "").trim()
  if (!str || str === "[]") return { entries: [], corrupted: false }
  try {
    var parsed = JSON.parse(str)
    if (!Array.isArray(parsed)) return { entries: [], corrupted: true, error: "not an array" }

    var next = []
    for (var i = 0; i < parsed.length; i++) {
      var entry = normalizeEntry(parsed[i])
      if (entry) next.push(entry)
    }
    return { entries: next, corrupted: false }
  } catch (e) {
    return { entries: [], corrupted: true, error: e.message }
  }
}

function parseHistory(raw) {
  return parseHistoryResult(raw).entries
}

function entrySizeBytes(entry) {
  if (!entry) return 0
  if (entry.type === "text") return (entry.text ? entry.text.length : 0) + 64
  if (entry.type === "image") return (entry.bytes ? entry.bytes : 64 * 1024) + 64
  return 128
}

var MAX_IMAGE_STORE_BYTES = 32 * 1024 * 1024 // 32 MiB

function pruneImageStore(entries, maxBytes) {
  var cap = maxBytes === undefined || maxBytes === null ? MAX_IMAGE_STORE_BYTES : Number(maxBytes)
  if (isNaN(cap) || cap <= 0) return entries

  var total = 0
  for (var i = 0; i < entries.length; i++) {
    var item = entries[i]
    if (item && item.type === "image") {
      total += (item.bytes ? item.bytes : 64 * 1024)
    }
  }

  if (total <= cap) return entries

  var result = entries.slice()
  for (var j = result.length - 1; j >= 0 && total > cap; j--) {
    var cand = result[j]
    if (cand && cand.type === "image" && !cand.favorite) {
      total -= (cand.bytes ? cand.bytes : 64 * 1024)
      result.splice(j, 1)
    }
  }

  return result
}

function pruneTotalSize(entries, maxBytes) {
  var cap = maxBytes === undefined || maxBytes === null ? MAX_TOTAL_HISTORY_BYTES : Number(maxBytes)
  if (isNaN(cap) || cap <= 0) return entries

  var total = 0
  for (var i = 0; i < entries.length; i++) {
    total += entrySizeBytes(entries[i])
  }

  if (total <= cap) return entries

  // Evict oldest unstarred entries first
  var result = entries.slice()
  for (var j = result.length - 1; j >= 0 && total > cap; j--) {
    if (!result[j].favorite) {
      total -= entrySizeBytes(result[j])
      result.splice(j, 1)
    }
  }

  return result
}

function referencedImagePaths(history) {
  var values = Array.isArray(history) ? history : []
  var paths = {}
  for (var i = 0; i < values.length; i++) {
    var entry = values[i]
    if (entry && entry.type === "image" && entry.path) {
      paths[entry.path] = true
    }
  }
  return paths
}

function findOrphanedImages(history, imageFileList) {
  var referenced = referencedImagePaths(history)
  var files = Array.isArray(imageFileList) ? imageFileList : []
  var orphans = []
  for (var i = 0; i < files.length; i++) {
    var file = String(files[i] || "")
    if (file && !referenced[file]) {
      orphans.push(file)
    }
  }
  return orphans
}

function addEntry(history, entry, limit, maxBytes, maxImageBytes) {
  var normalized = normalizeEntry(entry)
  var max = limit === undefined || limit === null ? 100 : Number(limit)
  if (isNaN(max)) max = 100
  max = Math.max(0, max)
  if (!normalized) return Array.isArray(history) ? history.slice(0, max) : []
  if (max === 0) return []

  var key = entryKey(normalized)
  var values = Array.isArray(history) ? history : []

  // Preserve favorite state if item already existed in history
  for (var i = 0; i < values.length; i++) {
    var existing = normalizeEntry(values[i])
    if (existing && entryKey(existing) === key) {
      if (existing.favorite) normalized.favorite = true
      break
    }
  }

  var next = [normalized]
  for (var i = 0; i < values.length && next.length < max; i++) {
    var existing = normalizeEntry(values[i])
    if (!existing || entryKey(existing) === key) continue
    next.push(existing)
  }

  var prunedHistory = pruneTotalSize(next, maxBytes)
  return pruneImageStore(prunedHistory, maxImageBytes)
}

function removeEntryAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()

  var next = values.slice()
  next.splice(target, 1)
  return next
}

function toggleFavorite(history, index) {
  var values = Array.isArray(history) ? history.slice() : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values

  var entry = Object.assign({}, values[target])
  entry.favorite = !entry.favorite
  values[target] = entry
  return values
}

function clearHistory(history) {
  var values = Array.isArray(history) ? history : []
  return values.filter(function(e) { return e && e.favorite === true })
}

function setEntryTags(history, keyOrIndex, tags) {
  var list = Array.isArray(history) ? history.slice() : []
  var cleanTags = normalizeTags(tags)
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (i === keyOrIndex || entryKey(item) === keyOrIndex) {
      var updated = Object.assign({}, item)
      if (cleanTags.length > 0) {
        updated.tags = cleanTags
      } else {
        delete updated.tags
      }
      list[i] = updated
      break
    }
  }
  return list
}

function toggleEntryTag(history, keyOrIndex, tag) {
  var t = String(tag || "").trim()
  if (!t) return history
  var list = Array.isArray(history) ? history.slice() : []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (i === keyOrIndex || entryKey(item) === keyOrIndex) {
      var currentTags = Array.isArray(item.tags) ? item.tags.slice() : []
      var idx = currentTags.indexOf(t)
      if (idx >= 0) {
        currentTags.splice(idx, 1)
      } else {
        currentTags.push(t)
      }
      var updated = Object.assign({}, item)
      if (currentTags.length > 0) {
        updated.tags = currentTags
      } else {
        delete updated.tags
      }
      list[i] = updated
      break
    }
  }
  return list
}

function getAllTags(history) {
  var list = Array.isArray(history) ? history : []
  var tags = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (item && Array.isArray(item.tags)) {
      for (var j = 0; j < item.tags.length; j++) {
        var t = item.tags[j]
        if (t && tags.indexOf(t) < 0) {
          tags.push(t)
        }
      }
    }
  }
  return tags
}

function suggestedTags(entry, sanitizer) {
  var sn = sanitizer || SanitizeModule
  var tags = []
  if (entry && entry.type === "text" && sn && typeof sn.isSensitive === "function") {
    if (sn.isSensitive(entry.text)) {
      tags.push("Tokens")
    }
  }
  return tags
}

function parseEntryJson(line) {
  var raw = String(line || "").trim()
  if (!raw) return null
  try { return normalizeEntry(JSON.parse(raw)) } catch (e) { return null }
}

function searchableText(entry) {
  if (!entry) return ""
  var tagPart = (entry.tags && entry.tags.length > 0) ? " " + entry.tags.join(" ") : ""
  if (entry.type === "image") return "image screenshot " + String(entry.mime || "") + " " + String(entry.capturedAt || "") + tagPart
  return String(entry.text || "") + " " + fileEntryText(entry) + tagPart
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""

  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""

  try { return decodeURIComponent(path) } catch (e) { return path }
}

function filePaths(entry) {
  if (!entry || entry.type !== "text") return []

  var lines = String(entry.text || "").split(/\r?\n/)
  var paths = []
  var hasNonEmptyLine = false
  var allLinesAreUris = true

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line || line.charAt(0) === "#") continue
    hasNonEmptyLine = true
    var path = decodeFileUri(line)
    if (path) {
      paths.push(path)
    } else {
      allLinesAreUris = false
    }
  }

  if (entry.mime === "text/uri-list") return paths
  if (hasNonEmptyLine && allLinesAreUris) return paths

  return []
}

function fileName(path) {
  var parts = String(path || "").split("/")
  return parts.length > 0 ? parts[parts.length - 1] : String(path || "")
}

function isImagePath(path) {
  return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || ""))
}

function fileEntryText(entry) {
  var paths = filePaths(entry)
  if (paths.length === 0) return ""
  if (paths.length === 1) return fileName(paths[0])
  return paths.length + " files"
}

function imagePreviewText(entry) {
  var timestamp = String(entry && entry.capturedAt || "")
  if (!timestamp) return "Image"

  var label = String(entry && entry.mime || "") === "image/png" ? "Screenshot" : "Image"
  return label + " from " + timestamp
}

function previewText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return imagePreviewText(entry)
  var fileText = fileEntryText(entry)
  if (fileText) return fileText
  return String(entry.text || "").replace(/\s+/g, " ")
}

function fullText(entry) {
  if (!entry) return ""
  var paths = filePaths(entry)
  if (paths.length > 0) return paths.join("\n")
  return String(entry.text || "")
}

// The picker only ever searches and renders a prefix of an entry, so scan and
// render just that much. A single huge paste otherwise costs hundreds of
// megabytes of string work on every keystroke and stalls the whole shell.
// Pasting reads the full entry back from history by index, so nothing is lost.
var displayTextLimit = 8192

function cappedEntry(entry) {
  if (!entry || entry.type !== "text" || entry.text.length <= displayTextLimit) return entry

  // Cut on a line break so a file:// URI never truncates into a bogus path.
  var cut = entry.text.lastIndexOf("\n", displayTextLimit)
  return { type: "text", text: entry.text.slice(0, cut > 0 ? cut : displayTextLimit) }
}

var ClassifyModule = (typeof require !== "undefined") ? require("./Classify.js") : null
var FuzzyModule = (typeof require !== "undefined") ? require("./Fuzzy.js") : null
var SanitizeModule = (typeof require !== "undefined") ? require("./Sanitize.js") : null

function displayRows(history, query, limit, favoritesOnly, typeFilter, tagFilterOrClassifier, classifierOrFuzzy, fuzzyMatcher, sanitizerModule) {
  var values = Array.isArray(history) ? history : []
  var needle = String(query || "").trim().toLowerCase()
  var max = limit === undefined || limit === null ? 50 : Number(limit)
  if (isNaN(max)) max = 50
  max = Math.max(0, max)
  if (max === 0) return []

  var filterType = String(typeFilter || "all").trim().toLowerCase()
  var tagFilter = "all"
  var cls = null
  var fz = null
  var sn = sanitizerModule || SanitizeModule

  if (typeof tagFilterOrClassifier === "string") {
    tagFilter = tagFilterOrClassifier.trim().toLowerCase()
    cls = classifierOrFuzzy
    fz = fuzzyMatcher
  } else {
    cls = tagFilterOrClassifier
    fz = classifierOrFuzzy
  }
  cls = cls || ClassifyModule
  fz = fz || FuzzyModule

  var rows = []

  for (var i = 0; i < values.length; i++) {
    var entry = cappedEntry(normalizeEntry(values[i]))
    if (!entry) continue
    if (favoritesOnly && !entry.favorite) continue

    if (tagFilter && tagFilter !== "all") {
      var entryTags = entry.tags || []
      var matchedTag = false
      for (var t = 0; t < entryTags.length; t++) {
        if (entryTags[t].toLowerCase() === tagFilter) {
          matchedTag = true
          break
        }
      }
      if (!matchedTag) continue
    }

    var paths = filePaths(entry)
    var isFile = paths.length > 0
    var entryType = (cls && typeof cls.classifyEntry === "function")
      ? cls.classifyEntry(entry, isFile)
      : (isFile ? "file" : entry.type)

    if (filterType && filterType !== "all" && entryType !== filterType) {
      continue
    }

    var score = 0
    if (needle) {
      var searchStr = searchableText(entry)
      if (fz && typeof fz.fuzzyMatch === "function") {
        var matchRes = fz.fuzzyMatch(needle, searchStr)
        if (!matchRes.match) continue
        score = matchRes.score
      } else {
        if (searchStr.toLowerCase().indexOf(needle) < 0) continue
      }
    }

    var isImage = entry.type === "image"
    var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    var pText = previewText(entry)
    var isSens = false
    var sensType = ""
    if (!isImage && sn && typeof sn.detectSensitive === "function") {
      var sInfo = sn.detectSensitive(entry.text || "")
      if (sInfo) {
        isSens = true
        sensType = sInfo.type || "Secret"
      }
    }

    var masked = (isSens && sn && typeof sn.maskText === "function") ? sn.maskText(pText) : pText

    rows.push({
      entryType: entryType,
      fullText: isImage ? "" : fullText(entry),
      previewText: pText,
      maskedPreview: masked,
      sensitive: isSens,
      sensitiveType: sensType,
      tags: entry.tags ? entry.tags.slice() : [],
      previewImage: previewPath,
      path: isImage ? String(entry.path || "") : (isFile && paths.length === 1 ? paths[0] : ""),
      mime: isImage ? String(entry.mime || "image/png") : "text/plain",
      favorite: !!entry.favorite,
      truncated: !!entry.truncated,
      score: score,
      index: i
    })
  }

  if (needle && rows.length > 1) {
    rows.sort(function(a, b) {
      return b.score - a.score
    })
  }

  return rows.slice(0, max)
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_ENTRY_TEXT_LENGTH: MAX_ENTRY_TEXT_LENGTH,
    MAX_TOTAL_HISTORY_BYTES: MAX_TOTAL_HISTORY_BYTES,
    MAX_IMAGE_STORE_BYTES: MAX_IMAGE_STORE_BYTES,
    normalizeEntry: normalizeEntry,
    normalizeTags: normalizeTags,
    entryKey: entryKey,
    parseHistory: parseHistory,
    parseHistoryResult: parseHistoryResult,
    pruneTotalSize: pruneTotalSize,
    pruneImageStore: pruneImageStore,
    referencedImagePaths: referencedImagePaths,
    findOrphanedImages: findOrphanedImages,
    entrySizeBytes: entrySizeBytes,
    addEntry: addEntry,
    removeEntryAt: removeEntryAt,
    clearHistory: clearHistory,
    toggleFavorite: toggleFavorite,
    setEntryTags: setEntryTags,
    toggleEntryTag: toggleEntryTag,
    getAllTags: getAllTags,
    suggestedTags: suggestedTags,
    parseEntryJson: parseEntryJson,
    searchableText: searchableText,
    previewText: previewText,
    imagePreviewText: imagePreviewText,
    filePaths: filePaths,
    fileEntryText: fileEntryText,
    fullText: fullText,
    displayRows: displayRows
  }
}

