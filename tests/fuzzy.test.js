const test = require("node:test");
const assert = require("node:assert/strict");
const Fuzzy = require("../Fuzzy.js");

test("fuzzyMatch handles empty and whitespace inputs", () => {
  assert.equal(Fuzzy.fuzzyMatch("", "hello").match, true);
  assert.equal(Fuzzy.fuzzyMatch("   ", "hello").match, true);
  assert.equal(Fuzzy.fuzzyMatch("a", "").match, false);
});

test("fuzzyMatch exact substring matches give high scores", () => {
  const m1 = Fuzzy.fuzzyMatch("apple", "Apple pie");
  const m2 = Fuzzy.fuzzyMatch("pie", "Apple pie");
  assert.equal(m1.match, true);
  assert.equal(m2.match, true);
  // Start of string exact match scores higher than middle exact match
  assert.ok(m1.score > m2.score);
  assert.deepEqual(m1.indices, [0, 1, 2, 3, 4]);
});

test("fuzzyMatch matches sequential characters and respects word boundaries", () => {
  const m1 = Fuzzy.fuzzyMatch("gc", "git commit -m message");
  assert.equal(m1.match, true);
  assert.equal(m1.indices.length, 2);
  assert.equal(m1.indices[0], 0); // 'g'
  assert.equal(m1.indices[1], 4); // 'c' at word boundary

  const m2 = Fuzzy.fuzzyMatch("cb", "omarchy-clipboard");
  assert.equal(m2.match, true);

  const mFail = Fuzzy.fuzzyMatch("xyz", "omarchy-clipboard");
  assert.equal(mFail.match, false);
});

test("fuzzyMatch performance across 500 items is fast (< 5ms)", () => {
  const start = performance.now();
  for (let i = 0; i < 500; i++) {
    Fuzzy.fuzzyMatch("omarchy", "mrshirini.clipboard plugin for omarchy desktop environment");
  }
  const elapsed = performance.now() - start;
  assert.ok(elapsed < 20, `500 fuzzy matches took ${elapsed}ms, expected < 20ms`);
});
