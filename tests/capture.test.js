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
