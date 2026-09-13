const test = require("node:test");
const assert = require("node:assert/strict");
const History = require("../ClipboardHistory.js");

test("normalizeEntry handles strings, text objects, and images", () => {
  // Strings
  assert.deepEqual(History.normalizeEntry("hello"), {
    type: "text",
    text: "hello",
    favorite: false,
  });
  assert.equal(History.normalizeEntry("   "), null);
  assert.equal(History.normalizeEntry(""), null);

  // Text objects
  assert.deepEqual(History.normalizeEntry({ type: "text", text: "valid" }), {
    type: "text",
    text: "valid",
  });
  assert.deepEqual(
    History.normalizeEntry({ type: "text", text: "fav", favorite: true }),
    { type: "text", text: "fav", favorite: true }
  );
  assert.equal(History.normalizeEntry({ type: "text", text: "" }), null);
  assert.equal(History.normalizeEntry({ type: "text", text: "   " }), null);

  // Image objects
  assert.deepEqual(
    History.normalizeEntry({ type: "image", path: "/tmp/img.png" }),
    { type: "image", path: "/tmp/img.png", mime: "image/png" }
  );
  assert.deepEqual(
    History.normalizeEntry({
      type: "image",
      path: "/tmp/img.jpg",
      mime: "image/jpeg",
      capturedAt: "2026-09-13 12:00:00",
      favorite: true,
    }),
    {
      type: "image",
      path: "/tmp/img.jpg",
      mime: "image/jpeg",
      capturedAt: "2026-09-13 12:00:00",
      favorite: true,
    }
  );
  assert.equal(History.normalizeEntry({ type: "image", path: "" }), null);

  // Null & invalid values
  assert.equal(History.normalizeEntry(null), null);
  assert.equal(History.normalizeEntry(undefined), null);
  assert.equal(History.normalizeEntry(123), null);
  assert.equal(History.normalizeEntry({ type: "unknown" }), null);
});

test("entryKey produces distinct keys for text and image", () => {
  assert.equal(History.entryKey({ type: "text", text: "abc" }), "text:abc");
  assert.equal(
    History.entryKey({ type: "image", path: "/tmp/pic.png" }),
    "image:/tmp/pic.png"
  );
  assert.equal(History.entryKey(null), "");
});

test("parseHistory handles valid, invalid, and malformed inputs", () => {
  const json = JSON.stringify([
    { type: "text", text: "first" },
    { type: "unknown" },
    { type: "text", text: "second", favorite: true },
  ]);
  const parsed = History.parseHistory(json);
  assert.equal(parsed.length, 2);
  assert.equal(parsed[0].text, "first");
  assert.equal(parsed[1].text, "second");
  assert.equal(parsed[1].favorite, true);

  assert.deepEqual(History.parseHistory("invalid json"), []);
  assert.deepEqual(History.parseHistory(""), []);
  assert.deepEqual(History.parseHistory(null), []);
  assert.deepEqual(History.parseHistory('{"not": "an array"}'), []);
});

test("addEntry prepends new items, deduplicates, and preserves favorites", () => {
  const h1 = History.addEntry([], { type: "text", text: "A" }, 10);
  assert.equal(h1.length, 1);
  assert.equal(h1[0].text, "A");

  // Add B
  const h2 = History.addEntry(h1, { type: "text", text: "B" }, 10);
  assert.equal(h2.length, 2);
  assert.equal(h2[0].text, "B");
  assert.equal(h2[1].text, "A");

  // Favorite A
  const h3 = History.toggleFavorite(h2, 1);
  assert.equal(h3[1].favorite, true);

  // Re-add A (should move to front and keep favorite: true)
  const h4 = History.addEntry(h3, { type: "text", text: "A" }, 10);
  assert.equal(h4.length, 2);
  assert.equal(h4[0].text, "A");
  assert.equal(h4[0].favorite, true);
  assert.equal(h4[1].text, "B");

  // Respects limit
  const hLimit = History.addEntry(
    [{ type: "text", text: "1" }, { type: "text", text: "2" }],
    { type: "text", text: "3" },
    2
  );
  assert.equal(hLimit.length, 2);
  assert.equal(hLimit[0].text, "3");
  assert.equal(hLimit[1].text, "1");
});

test("toggleFavorite toggles favorite boolean on targeted item", () => {
  const history = [
    { type: "text", text: "one", favorite: false },
    { type: "text", text: "two" },
  ];

  const toggled = History.toggleFavorite(history, 0);
  assert.equal(toggled[0].favorite, true);
  assert.equal(toggled[1].favorite, undefined);

  const toggledBack = History.toggleFavorite(toggled, 0);
  assert.equal(toggledBack[0].favorite, false);

  // Out of bounds index
  assert.deepEqual(History.toggleFavorite(history, 99), history);
  assert.deepEqual(History.toggleFavorite(history, -1), history);
});

test("clearHistory retains only starred items", () => {
  const history = [
    { type: "text", text: "keep me", favorite: true },
    { type: "text", text: "delete me", favorite: false },
    { type: "text", text: "delete me too" },
    { type: "image", path: "/tmp/star.png", favorite: true },
  ];

  const cleared = History.clearHistory(history);
  assert.equal(cleared.length, 2);
  assert.equal(cleared[0].text, "keep me");
  assert.equal(cleared[1].path, "/tmp/star.png");

  // No favorites
  assert.deepEqual(
    History.clearHistory([{ type: "text", text: "none", favorite: false }]),
    []
  );
});

test("removeEntryAt removes only the item at target index", () => {
  const history = [
    { type: "text", text: "A" },
    { type: "text", text: "B" },
    { type: "text", text: "C" },
  ];
  const next = History.removeEntryAt(history, 1);
  assert.equal(next.length, 2);
  assert.equal(next[0].text, "A");
  assert.equal(next[1].text, "C");

  // Invalid index
  assert.deepEqual(History.removeEntryAt(history, 10), history);
});

test("displayRows supports limit, search query, and favoritesOnly filter", () => {
  const history = [
    { type: "text", text: "Apple pie", favorite: false },
    { type: "text", text: "Banana bread", favorite: true },
    { type: "text", text: "Apple cider", favorite: true },
    { type: "image", path: "/tmp/shot.png", mime: "image/png", favorite: false },
  ];

  // All entries, no query
  const allRows = History.displayRows(history, "", 50, false);
  assert.equal(allRows.length, 4);

  // Favorites only
  const favRows = History.displayRows(history, "", 50, true);
  assert.equal(favRows.length, 2);
  assert.equal(favRows[0].previewText, "Banana bread");
  assert.equal(favRows[0].favorite, true);
  assert.equal(favRows[1].previewText, "Apple cider");
  assert.equal(favRows[1].favorite, true);

  // Search query
  const appleRows = History.displayRows(history, "cider", 50, false);
  assert.equal(appleRows.length, 1);
  assert.equal(appleRows[0].previewText, "Apple cider");

  // Search favorites only
  const appleFavRows = History.displayRows(history, "apple", 50, true);
  assert.equal(appleFavRows.length, 1);
  assert.equal(appleFavRows[0].previewText, "Apple cider");

  // Limit check
  const limited = History.displayRows(history, "", 2, false);
  assert.equal(limited.length, 2);
});

test("filePaths decodes file URIs including percent-encoded paths", () => {
  const entry = {
    type: "text",
    text: "file:///home/amir/My%20Documents/note%231.txt\r\n# Comment line\r\nfile:///tmp/test.png",
  };
  const paths = History.filePaths(entry);
  assert.equal(paths.length, 2);
  assert.equal(paths[0], "/home/amir/My Documents/note#1.txt");
  assert.equal(paths[1], "/tmp/test.png");

  const preview = History.previewText(entry);
  assert.equal(preview, "2 files");
});

test("filePaths distinguishes copied file URI lists from text that merely contains a file:// path", () => {
  // Plain text with a file link inside: should NOT be treated as a file entry
  const textWithUri = {
    type: "text",
    text: "Hey, check out this log file:\nfile:///var/log/syslog\nLet me know what you think.",
  };
  assert.deepEqual(History.filePaths(textWithUri), []);

  const rows = History.displayRows([textWithUri], "", 10);
  assert.equal(rows[0].entryType, "text");

  // Explicit text/uri-list mime: treated as file
  const uriListEntry = {
    type: "text",
    mime: "text/uri-list",
    text: "file:///etc/hosts",
  };
  assert.deepEqual(History.filePaths(uriListEntry), ["/etc/hosts"]);
  const uriRows = History.displayRows([uriListEntry], "", 10);
  assert.equal(uriRows[0].entryType, "file");
});

test("normalizeEntry caps giant text to MAX_ENTRY_TEXT_LENGTH and marks truncated", () => {
  const hugeText = "x".repeat(100 * 1024); // 100 KiB
  const normalized = History.normalizeEntry(hugeText);
  assert.equal(normalized.type, "text");
  assert.equal(normalized.text.length, History.MAX_ENTRY_TEXT_LENGTH);
  assert.equal(normalized.truncated, true);

  const normalizedObj = History.normalizeEntry({ type: "text", text: hugeText });
  assert.equal(normalizedObj.text.length, History.MAX_ENTRY_TEXT_LENGTH);
  assert.equal(normalizedObj.truncated, true);
});

test("parseHistoryResult accurately detects and reports corrupt JSON", () => {
  // Corrupt string
  const corrupt1 = History.parseHistoryResult("{not valid json");
  assert.equal(corrupt1.corrupted, true);
  assert.deepEqual(corrupt1.entries, []);
  assert.ok(corrupt1.error);

  // Non-array JSON
  const corrupt2 = History.parseHistoryResult('{"key": "value"}');
  assert.equal(corrupt2.corrupted, true);
  assert.deepEqual(corrupt2.entries, []);

  // Empty string or empty array
  const validEmpty = History.parseHistoryResult("");
  assert.equal(validEmpty.corrupted, false);
  assert.deepEqual(validEmpty.entries, []);

  const validEmptyArr = History.parseHistoryResult("[]");
  assert.equal(validEmptyArr.corrupted, false);
  assert.deepEqual(validEmptyArr.entries, []);

  // Valid array
  const valid = History.parseHistoryResult('[{"type":"text","text":"hello"}]');
  assert.equal(valid.corrupted, false);
  assert.equal(valid.entries.length, 1);
  assert.equal(valid.entries[0].text, "hello");
});

test("pruneTotalSize and addEntry evict oldest unstarred entries when size limit exceeded", () => {
  // Create entries: entry 1 (starred), entry 2 (unstarred), entry 3 (unstarred)
  const e1 = { type: "text", text: "starred-entry-".padEnd(200, "1"), favorite: true };
  const e2 = { type: "text", text: "old-unstarred-".padEnd(200, "2"), favorite: false };
  const e3 = { type: "text", text: "new-unstarred-".padEnd(200, "3"), favorite: false };

  // Set byte limit (e.g. 600 bytes) - each entry is ~264 bytes
  let history = History.addEntry([], e1, 10, 600);
  history = History.addEntry(history, e2, 10, 600);
  assert.equal(history.length, 2);

  // Adding e3 should push total bytes (792) over 600. e2 (oldest unstarred) should be evicted,
  // but e1 (starred) must be kept even though it's older than e3!
  history = History.addEntry(history, e3, 10, 600);
  assert.equal(history.length, 2);
  assert.equal(history[0].text.startsWith("new-unstarred"), true);
  assert.equal(history[1].text.startsWith("starred-entry"), true);
  assert.equal(history[1].favorite, true);
});

test("pruneImageStore caps image disk usage and retains starred images", () => {
  const img1 = { type: "image", path: "/tmp/img1.png", mime: "image/png", bytes: 10 * 1024 * 1024, favorite: true };
  const img2 = { type: "image", path: "/tmp/img2.png", mime: "image/png", bytes: 15 * 1024 * 1024, favorite: false };
  const img3 = { type: "image", path: "/tmp/img3.png", mime: "image/png", bytes: 15 * 1024 * 1024, favorite: false };

  // Total cap = 30 MiB
  const cap = 30 * 1024 * 1024;
  let history = [img2, img1]; // 25 MiB, fits under 30 MiB
  assert.equal(History.pruneImageStore(history, cap).length, 2);

  // Add img3: total would be 40 MiB > 30 MiB
  // img2 (oldest unstarred) must be evicted, keeping img3 (newest) and img1 (starred)!
  const updated = [img3, img2, img1];
  const pruned = History.pruneImageStore(updated, cap);
  assert.equal(pruned.length, 2);
  assert.equal(pruned[0].path, "/tmp/img3.png");
  assert.equal(pruned[1].path, "/tmp/img1.png");
  assert.equal(pruned[1].favorite, true);
});

test("referencedImagePaths and findOrphanedImages accurately identify orphaned disk files", () => {
  const history = [
    { type: "text", text: "hello" },
    { type: "image", path: "/images/imgA.png" },
    { type: "image", path: "/images/imgB.png", favorite: true },
  ];

  const referenced = History.referencedImagePaths(history);
  assert.equal(referenced["/images/imgA.png"], true);
  assert.equal(referenced["/images/imgB.png"], true);
  assert.equal(referenced["/images/imgC.png"], undefined);

  const diskFiles = [
    "/images/imgA.png",
    "/images/imgB.png",
    "/images/imgOrphan1.png",
    "/images/imgOrphan2.png",
  ];

  const orphans = History.findOrphanedImages(history, diskFiles);
  assert.deepEqual(orphans, [
    "/images/imgOrphan1.png",
    "/images/imgOrphan2.png",
  ]);
});

