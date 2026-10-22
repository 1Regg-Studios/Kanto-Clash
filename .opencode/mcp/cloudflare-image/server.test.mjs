import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const directory = dirname(fileURLToPath(import.meta.url));
const imageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/fRcAAAAASUVORK5CYII=";
const accountId = "0123456789abcdef0123456789abcdef";

async function connect(t, credentials = true) {
  const outputDirectory = await mkdtemp(join(directory, ".test-output-"));
  t.after(() => rm(outputDirectory, { recursive: true, force: true }));
  const mock = `
    import assert from "node:assert/strict";
    globalThis.fetch = async (url, options) => {
      assert.equal(url, "https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/@cf/black-forest-labs/flux-1-schnell");
      assert.equal(options.method, "POST");
      assert.equal(options.headers.Authorization, "Bearer test-token");
      assert.equal(options.headers["Content-Type"], "application/json");
      const body = JSON.parse(options.body);
      assert.deepEqual(Object.keys(body).sort(), ["prompt", "steps"]);
      assert.equal(body.steps, 4);
      if (body.prompt === "quota exhausted") {
        return new Response(JSON.stringify({ success: false, errors: [{ message: "Daily quota exceeded" }] }), { status: 429 });
      }
      if (body.prompt === "invalid image") {
        return new Response(JSON.stringify({ success: true, result: { image: "bm90IGFuIGltYWdl" } }));
      }
      return new Response(JSON.stringify({ success: true, result: { image: "${imageBase64}" } }));
    };
  `;
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: ["--import", `data:text/javascript,${encodeURIComponent(mock)}`, join(directory, "server.mjs")],
    cwd: directory,
    env: {
      ...process.env,
      CLOUDFLARE_ACCOUNT_ID: credentials ? accountId : "",
      CLOUDFLARE_API_TOKEN: credentials ? "test-token" : "",
      OUTPUT_DIR: outputDirectory,
    },
    stderr: "pipe",
  });
  const client = new Client({ name: "cloudflare-install-check", version: "1.0.0" });
  t.after(() => client.close());
  await client.connect(transport);
  return { client, outputDirectory };
}

test("Cloudflare generation saves images, preserves existing files, and reports API failures", { timeout: 20_000 }, async (t) => {
  const { client, outputDirectory } = await connect(t);
  const { tools } = await client.listTools();
  assert.ok(tools.some((tool) => tool.name === "generate_image"));

  const first = await client.callTool({
    name: "generate_image",
    arguments: { prompt: "pixel-art village", filename: "village" },
  });
  assert.ok(!first.isError, JSON.stringify(first));
  const image = JSON.parse(first.content[0].text);
  assert.equal(image.imagePath, join(outputDirectory, "village.png"));
  assert.equal(image.mimeType, "image/png");
  assert.deepEqual(await readFile(image.imagePath), Buffer.from(imageBase64, "base64"));

  const second = await client.callTool({
    name: "generate_image",
    arguments: { prompt: "pixel-art village variation", filename: "village" },
  });
  assert.ok(!second.isError, JSON.stringify(second));
  assert.equal(JSON.parse(second.content[0].text).imagePath, join(outputDirectory, "village-v2.png"));
  assert.deepEqual(await readFile(image.imagePath), Buffer.from(imageBase64, "base64"));

  const quotaFailure = await client.callTool({
    name: "generate_image",
    arguments: { prompt: "quota exhausted", filename: "quota" },
  });
  assert.equal(quotaFailure.isError, true);
  assert.match(quotaFailure.content[0].text, /429.*Daily quota exceeded/);

  const invalidImage = await client.callTool({
    name: "generate_image",
    arguments: { prompt: "invalid image", filename: "invalid" },
  });
  assert.equal(invalidImage.isError, true);
  assert.match(invalidImage.content[0].text, /unrecognized image format/);
  assert.deepEqual((await readdir(outputDirectory)).sort(), ["village-v2.png", "village.png"]);
});

test("MCP connects without credentials and explains how to activate generation", { timeout: 20_000 }, async (t) => {
  const { client, outputDirectory } = await connect(t, false);
  const { tools } = await client.listTools();
  assert.ok(tools.some((tool) => tool.name === "generate_image"));
  const result = await client.callTool({
    name: "generate_image",
    arguments: { prompt: "pixel-art village" },
  });
  assert.equal(result.isError, true);
  assert.match(result.content[0].text, /cloudflare-account-id\.txt/);
  assert.match(result.content[0].text, /cloudflare-api-token\.txt/);
  assert.deepEqual(await readdir(outputDirectory), []);
});
