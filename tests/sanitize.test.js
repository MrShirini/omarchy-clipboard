const test = require("node:test");
const assert = require("node:assert/strict");
const Sanitize = require("../Sanitize.js");

test("detectSensitive identifies API keys, JWTs, and passwords", () => {
  // OpenAI key
  assert.ok(Sanitize.isSensitive("sk-abcdef12345678901234567890"));
  assert.equal(Sanitize.detectSensitive("sk-abcdef12345678901234567890").type, "OpenAI/API Key");

  // GitHub token
  assert.ok(Sanitize.isSensitive("ghp_123456789012345678901234567890123456"));
  assert.equal(Sanitize.detectSensitive("ghp_123456789012345678901234567890123456").type, "GitHub Token");

  // AWS Access Key
  assert.ok(Sanitize.isSensitive("AKIAIOSFODNN7EXAMPLE"));
  assert.equal(Sanitize.detectSensitive("AKIAIOSFODNN7EXAMPLE").type, "AWS Key");

  // JWT token
  const jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozGzN_ce";
  assert.ok(Sanitize.isSensitive(jwt));

  // Private key
  assert.ok(Sanitize.isSensitive("-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA..."));

  // Key-value password
  assert.ok(Sanitize.isSensitive("export DB_PASSWORD=mySuperSecretPassword123!"));
  assert.ok(Sanitize.isSensitive('api_key: "abcdef12345678"'));

  // Benign strings
  assert.equal(Sanitize.isSensitive("hello world"), false);
  assert.equal(Sanitize.isSensitive("git checkout -b feature/tags"), false);
  assert.equal(Sanitize.isSensitive("https://github.com/mrshirini/omarchy-clipboard"), false);
});

test("maskText masks secrets while keeping context legible", () => {
  const openAi = "sk-proj-12345678901234567890abcd";
  const maskedOpenAi = Sanitize.maskText(openAi);
  assert.ok(maskedOpenAi.includes("••••••••"));
  assert.ok(!maskedOpenAi.includes("12345678901234567890"));

  const rsa = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----";
  assert.equal(Sanitize.maskText(rsa), "-----BEGIN PRIVATE KEY----- [MASKED]");

  const envVar = "export DB_PASSWORD=mySuperSecretPassword123!";
  const maskedEnv = Sanitize.maskText(envVar);
  assert.ok(maskedEnv.startsWith("export DB_PASSWORD="));
  assert.ok(maskedEnv.includes("••••••••"));
  assert.ok(!maskedEnv.includes("mySuperSecretPassword123!"));
});
