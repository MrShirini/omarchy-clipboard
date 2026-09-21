const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const CAPTURE_SCRIPT = path.resolve(__dirname, "../capture.sh");

test("capture.sh saves image within byte limit and returns JSON", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const payload = Buffer.from("test-png-image-binary-payload-data");
    const res = spawnSync(CAPTURE_SCRIPT, ["image/png"], {
      input: payload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_IMAGE_BYTES: "1024",
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.ok(output.length > 0, "Expected JSON output");
    const json = JSON.parse(output);
    assert.equal(json.type, "image");
    assert.equal(json.mime, "image/png");
    assert.equal(json.bytes, payload.length);
    assert.ok(fs.existsSync(json.path));
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh rejects oversized image stream, removes temp files, and outputs nothing", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const maxBytes = 500;
    const oversizedPayload = Buffer.alloc(2000, "X");
    const res = spawnSync(CAPTURE_SCRIPT, ["image/png"], {
      input: oversizedPayload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_IMAGE_BYTES: String(maxBytes),
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.equal(output, "", "Expected empty output for oversized payload");

    const imgDir = path.join(tmpDir, "omarchy/clipboard-images");
    if (fs.existsSync(imgDir)) {
      const files = fs.readdirSync(imgDir);
      assert.equal(files.length, 0, "Expected no image or temp files saved");
    }
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh ignores empty input without leaving temp files", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const res = spawnSync(CAPTURE_SCRIPT, ["image/png"], {
      input: Buffer.alloc(0),
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_IMAGE_BYTES: "1024",
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.equal(output, "");

    const imgDir = path.join(tmpDir, "omarchy/clipboard-images");
    if (fs.existsSync(imgDir)) {
      const files = fs.readdirSync(imgDir);
      assert.equal(files.length, 0);
    }
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh saves text within byte limit and returns JSON", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const payload = Buffer.from("Hello Omarchy clipboard text");
    const res = spawnSync(CAPTURE_SCRIPT, ["text"], {
      input: payload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_TEXT_BYTES: "1024",
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.ok(output.length > 0, "Expected JSON output");
    const json = JSON.parse(output);
    assert.equal(json.type, "text");
    assert.equal(json.text, "Hello Omarchy clipboard text");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh rejects oversized text stream and outputs nothing", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const maxBytes = 200;
    const oversizedPayload = Buffer.alloc(1000, "T");
    const res = spawnSync(CAPTURE_SCRIPT, ["text"], {
      input: oversizedPayload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_TEXT_BYTES: String(maxBytes),
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.equal(output, "", "Expected empty output for oversized text payload");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh ignores empty text input and outputs nothing", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const res = spawnSync(CAPTURE_SCRIPT, ["text"], {
      input: Buffer.alloc(0),
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_TEXT_BYTES: "1024",
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.equal(output, "");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh saves text/uri-list within byte limit and returns JSON", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const payload = Buffer.from("file:///home/user/doc.txt\nfile:///home/user/image.png");
    const res = spawnSync(CAPTURE_SCRIPT, ["text/uri-list"], {
      input: payload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_TEXT_BYTES: "1024",
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.ok(output.length > 0, "Expected JSON output");
    const json = JSON.parse(output);
    assert.equal(json.type, "text");
    assert.equal(json.mime, "text/uri-list");
    assert.equal(json.text, "file:///home/user/doc.txt\nfile:///home/user/image.png");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh rejects oversized text/uri-list stream and outputs nothing", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const maxBytes = 50;
    const oversizedPayload = Buffer.from("file:///home/user/very_long_path_that_exceeds_fifty_bytes_limit.txt");
    const res = spawnSync(CAPTURE_SCRIPT, ["text/uri-list"], {
      input: oversizedPayload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_TEXT_BYTES: String(maxBytes),
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.equal(output, "", "Expected empty output for oversized uri-list");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh decodes UTF-16 text payloads with bounded reader", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    // UTF-16LE with BOM
    const bom = Buffer.from([0xFF, 0xFE]);
    const str = Buffer.from("Hello UTF16", "utf16le");
    const payload = Buffer.concat([bom, str]);
    const res = spawnSync(CAPTURE_SCRIPT, ["text"], {
      input: payload,
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
        CLIPBOARD_MAX_TEXT_BYTES: "1024",
      },
    });

    assert.equal(res.status, 0);
    const output = res.stdout.toString().trim();
    assert.ok(output.length > 0, "Expected JSON output");
    const json = JSON.parse(output);
    assert.equal(json.type, "text");
    assert.equal(json.text, "Hello UTF16");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("capture.sh respects clipboard-paused state file and CLIPBOARD_PAUSED env var", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-test-"));
  try {
    const omarchyDir = path.join(tmpDir, "omarchy");
    fs.mkdirSync(omarchyDir, { recursive: true });
    const pausedFlag = path.join(omarchyDir, "clipboard-paused");

    // Create pause flag file
    fs.writeFileSync(pausedFlag, "1");

    const resWithFlag = spawnSync(CAPTURE_SCRIPT, ["text"], {
      input: "sensitive password or confidential text",
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_STATE: "",
      },
    });

    assert.equal(resWithFlag.status, 0);
    assert.equal(resWithFlag.stdout.toString().trim(), "", "Should output nothing when paused flag exists");

    // Remove flag file
    fs.unlinkSync(pausedFlag);

    // Test with CLIPBOARD_PAUSED=1 env var
    const resWithEnv = spawnSync(CAPTURE_SCRIPT, ["text"], {
      input: "confidential token",
      env: {
        ...process.env,
        XDG_STATE_HOME: tmpDir,
        CLIPBOARD_PAUSED: "1",
        CLIPBOARD_STATE: "",
      },
    });

    assert.equal(resWithEnv.status, 0);
    assert.equal(resWithEnv.stdout.toString().trim(), "", "Should output nothing when CLIPBOARD_PAUSED=1");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});
