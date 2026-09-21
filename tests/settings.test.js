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
    maskSensitiveText: false,
    pasteOnClick: true
  };

  const parsed = Settings.parseSettings(JSON.stringify(custom));
  assert.equal(parsed.position, "top-right");
  assert.deepEqual(parsed.customOffset, { x: 10, y: 20 });
  assert.equal(parsed.shortcuts.favorite, "Ctrl+Shift+F");
  assert.equal(parsed.shortcuts.toggleFavoritesView, "Tab"); // preserved default
  assert.deepEqual(parsed.defaultTagSet, ["Work", "Personal"]);
  assert.equal(parsed.maskSensitiveText, false);
  assert.equal(parsed.pasteOnClick, true);
});

test("parseSettings handles pasteOnClick default and explicit values", () => {
  assert.equal(Settings.parseSettings("{}").pasteOnClick, false);
  assert.equal(Settings.parseSettings('{"pasteOnClick": false}').pasteOnClick, false);
  assert.equal(Settings.parseSettings('{"pasteOnClick": true}').pasteOnClick, true);
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

test("parseSettings parses maxHistoryEntries, retentionDays, and storage limits", () => {
  const custom = {
    maxHistoryEntries: 500,
    retentionDays: 14,
    maxTotalHistoryMB: 2,
    maxImageStoreMB: 64,
    shortcuts: {
      togglePause: "Ctrl+Shift+P",
      openSettings: "Ctrl+Alt+S"
    }
  };
  const parsed = Settings.parseSettings(JSON.stringify(custom));
  assert.equal(parsed.maxHistoryEntries, 500);
  assert.equal(parsed.retentionDays, 14);
  assert.equal(parsed.maxTotalHistoryMB, 2);
  assert.equal(parsed.maxImageStoreMB, 64);
  assert.equal(parsed.shortcuts.togglePause, "Ctrl+Shift+P");
  assert.equal(parsed.shortcuts.openSettings, "Ctrl+Alt+S");

  // Invalid values fall back to defaults
  const invalid = Settings.parseSettings(JSON.stringify({
    maxHistoryEntries: 2, // below minimum 10
    retentionDays: -5,
    maxTotalHistoryMB: -1,
    maxImageStoreMB: 0
  }));
  assert.equal(invalid.maxHistoryEntries, 300);
  assert.equal(invalid.retentionDays, 0);
  assert.equal(invalid.maxTotalHistoryMB, 1);
  assert.equal(invalid.maxImageStoreMB, 32);
});

test("parseSettings parses windowSize presets and custom width/height dimensions", () => {
  // Presets
  assert.equal(Settings.parseSettings('{"windowSize": "compact"}').windowSize, "compact");
  assert.equal(Settings.parseSettings('{"windowSize": "compact"}').windowWidth, 600);
  assert.equal(Settings.parseSettings('{"windowSize": "compact"}').windowHeight, 420);

  assert.equal(Settings.parseSettings('{"windowSize": "large"}').windowSize, "large");
  assert.equal(Settings.parseSettings('{"windowSize": "large"}').windowWidth, 880);
  assert.equal(Settings.parseSettings('{"windowSize": "large"}').windowHeight, 620);

  assert.equal(Settings.parseSettings('{"windowSize": "expanded"}').windowSize, "expanded");
  assert.equal(Settings.parseSettings('{"windowSize": "expanded"}').windowWidth, 1040);
  assert.equal(Settings.parseSettings('{"windowSize": "expanded"}').windowHeight, 720);

  // Custom dimensions
  const custom = Settings.parseSettings(JSON.stringify({
    windowSize: "custom",
    windowWidth: 900,
    windowHeight: 650
  }));
  assert.equal(custom.windowSize, "custom");
  assert.equal(custom.windowWidth, 900);
  assert.equal(custom.windowHeight, 650);

  // Fallbacks for invalid values
  const invalid = Settings.parseSettings(JSON.stringify({
    windowSize: "gigantic",
    windowWidth: 50, // too small
    windowHeight: 99999 // too large
  }));
  assert.equal(invalid.windowSize, "medium");
  assert.equal(invalid.windowWidth, 720);
  assert.equal(invalid.windowHeight, 520);
});

