const test = require("node:test");
const assert = require("node:assert/strict");
const Classify = require("../Classify.js");

test("isUrl detects http, https, ftp, and www URLs", () => {
  assert.equal(Classify.isUrl("https://omarchy.org"), true);
  assert.equal(Classify.isUrl("http://localhost:3000/api/v1"), true);
  assert.equal(Classify.isUrl("ftp://ftp.is.co.za/linux/distributions"), true);
  assert.equal(Classify.isUrl("www.google.com/search?q=test"), true);

  assert.equal(Classify.isUrl("not a url"), false);
  assert.equal(Classify.isUrl("hello world"), false);
  assert.equal(Classify.isUrl(""), false);
});

test("isColor detects hex, rgb, rgba, hsl, and hsla colors", () => {
  assert.equal(Classify.isColor("#fff"), true);
  assert.equal(Classify.isColor("#ffffff"), true);
  assert.equal(Classify.isColor("#101315ff"), true);
  assert.equal(Classify.isColor("rgb(255, 0, 128)"), true);
  assert.equal(Classify.isColor("rgba(0, 0, 0, 0.5)"), true);
  assert.equal(Classify.isColor("hsl(210, 50%, 40%)"), true);

  assert.equal(Classify.isColor("#xyz"), false);
  assert.equal(Classify.isColor("blueish"), false);
  assert.equal(Classify.isColor("#12"), false);
});

test("isCode detects JSON, JS/TS, Python, HTML, SQL, and code snippets", () => {
  assert.equal(Classify.isCode('{"name": "omarchy", "version": 1}'), true);
  assert.equal(Classify.isCode("function test() { return 42; }"), true);
  assert.equal(Classify.isCode("const x = 10; let y = 20;"), true);
  assert.equal(Classify.isCode("import { useState } from 'react';"), true);
  assert.equal(Classify.isCode("def calculate_total(items):\n    return sum(items)"), true);
  assert.equal(Classify.isCode("SELECT * FROM users WHERE active = 1;"), true);
  assert.equal(Classify.isCode("<div class='container'><p>Hello</p></div>"), true);
  assert.equal(Classify.isCode("#!/bin/bash\necho 'hello'"), true);

  assert.equal(Classify.isCode("Just a normal conversation sentence with nothing special."), false);
  assert.equal(Classify.isCode("Buy milk, eggs, and bread from the grocery store."), false);
});

test("classifyEntry accurately categorizes entries by type", () => {
  assert.equal(Classify.classifyEntry({ type: "image", path: "/tmp/a.png" }, false), "image");
  assert.equal(Classify.classifyEntry({ type: "text", text: "file:///tmp/a" }, true), "file");
  assert.equal(Classify.classifyEntry({ type: "text", mime: "text/uri-list", text: "..." }, false), "file");
  assert.equal(Classify.classifyEntry({ type: "text", text: "#ff5722" }, false), "color");
  assert.equal(Classify.classifyEntry({ type: "text", text: "https://github.com/omacom/omarchy" }, false), "link");
  assert.equal(Classify.classifyEntry({ type: "text", text: "const a = 123;\nconst b = 456;" }, false), "code");
  assert.equal(Classify.classifyEntry({ type: "text", text: "Remember to call John tomorrow morning" }, false), "text");
});
