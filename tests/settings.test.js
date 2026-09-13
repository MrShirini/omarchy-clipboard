const test = require("node:test");
const assert = require("node:assert/strict");
const Settings = require("../Settings.js");

test("parseSettings falls back to defaults for empty or invalid input", () => {
  assert.deepEqual(Settings.parseSettings(""), Settings.DEFAULT_SETTINGS);
  assert.deepEqual(Settings.parseSettings(null), Settings.DEFAULT_SETTINGS);
  assert.deepEqual(Settings.parseSettings("not json"), Settings.DEFAULT_SETTINGS);
  assert.deepEqual(Settings.parseSettings("[]"), Settings.DEFAULT_SETTINGS);
});

test("parseSettings validates position and allows valid positions", () => {
  assert.equal(Settings.parseSettings('{"position": "center"}').position, "center");
  assert.equal(Settings.parseSettings('{"position": "top-center"}').position, "top-center");
  assert.equal(Settings.parseSettings('{"position": "top-left"}').position, "top-left");
  assert.equal(Settings.parseSettings('{"position": "top-right"}').position, "top-right");

  // Invalid position falls back to default
  assert.equal(Settings.parseSettings('{"position": "bottom-right"}').position, "top-right");
});

test("parseSettings parses customOffset and custom shortcuts", () => {
  const custom = {
    position: "top-right",
    customOffset: { x: 10, y: 20 },
    shortcuts: {
      favorite: "Ctrl+Shift+F"
    },
    defaultTagSet: ["Work", "Personal"],
    maskSensitiveText: false
  };

  const parsed = Settings.parseSettings(JSON.stringify(custom));
  assert.equal(parsed.position, "top-right");
  assert.deepEqual(parsed.customOffset, { x: 10, y: 20 });
  assert.equal(parsed.shortcuts.favorite, "Ctrl+Shift+F");
  assert.equal(parsed.shortcuts.toggleFavoritesView, "Tab"); // preserved default
  assert.deepEqual(parsed.defaultTagSet, ["Work", "Personal"]);
  assert.equal(parsed.maskSensitiveText, false);
});

test("parseShortcut parses shortcut string into modifier and key components", () => {
  assert.equal(Settings.parseShortcut(""), null);
  assert.equal(Settings.parseShortcut(null), null);
  assert.deepEqual(Settings.parseShortcut("Alt+F"), { ctrl: false, alt: true, shift: false, meta: false, key: "f" });
  assert.deepEqual(Settings.parseShortcut("Ctrl+Shift+S"), { ctrl: true, alt: false, shift: true, meta: false, key: "s" });
  assert.deepEqual(Settings.parseShortcut("Super+Tab"), { ctrl: false, alt: false, shift: false, meta: true, key: "tab" });
});

test("matchesShortcut matches event against shortcut specification", () => {
  const altF = { key: 70, modifiers: 0x08000000 }; // 'F' (70) + Alt
  assert.equal(Settings.matchesShortcut(altF, "Alt+F"), true);
  assert.equal(Settings.matchesShortcut(altF, "Alt+S"), false);
  assert.equal(Settings.matchesShortcut(altF, "Ctrl+F"), false);

  const ctrlD = { key: 68, modifiers: 0x04000000 }; // 'D' (68) + Ctrl
  assert.equal(Settings.matchesShortcut(ctrlD, "Ctrl+D"), true);

  const tabEvent = { key: 0x01000001, modifiers: 0 };
  assert.equal(Settings.matchesShortcut(tabEvent, "Tab"), true);
});

