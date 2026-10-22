import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const model = "@cf/black-forest-labs/flux-1-schnell";
const outputDirectory = resolve(process.env.OUTPUT_DIR || "assets/generated");
const server = new McpServer({
  name: "kantoclash-cloudflare-image",
  version: "1.0.0",
});

function imageFormat(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from("89504e470d0a1a0a", "hex"))) {
    return { extension: "png", mimeType: "image/png" };
  }
  if (bytes.subarray(0, 3).equals(Buffer.from("ffd8ff", "hex"))) {
    return { extension: "jpg", mimeType: "image/jpeg" };
  }
  if (
    bytes.toString("ascii", 0, 4) === "RIFF" &&
    bytes.toString("ascii", 8, 12) === "WEBP"
  ) {
    return { extension: "webp", mimeType: "image/webp" };
  }
  throw new Error("Cloudflare returned an unrecognized image format.");
}

async function saveImage(bytes, filename, extension) {
  await mkdir(outputDirectory, { recursive: true });
  for (let version = 1; ; version += 1) {
    const suffix = version === 1 ? "" : `-v${version}`;
    const imagePath = join(outputDirectory, `${filename}${suffix}.${extension}`);
    try {
      await writeFile(imagePath, bytes, { flag: "wx" });
      return imagePath;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
    }
  }
}

server.registerTool(
  "generate_image",
  {
    title: "Generate Cloudflare Image",
    description:
      "Generate an image with Cloudflare Workers AI FLUX.1 Schnell and save it " +
      "in this project's assets/generated directory. Returns the saved file path. " +
      "Uses your Cloudflare Workers AI quota. Requires a Cloudflare Account ID " +
      "and Workers AI API token in the project's .opencode/secrets files.",
    inputSchema: {
      prompt: z.string().trim().min(1).max(2048).describe("Image description."),
      steps: z.number().int().min(1).max(8).default(4).describe("Diffusion steps (1-8)."),
      filename: z
        .string()
        .regex(/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}$/)
        .optional()
        .describe("Optional filename without an extension. Use letters, numbers, hyphens or underscores."),
    },
  },
  async ({ prompt, steps, filename }) => {
    try {
      const accountId = process.env.CLOUDFLARE_ACCOUNT_ID?.trim();
      const token = process.env.CLOUDFLARE_API_TOKEN?.trim();
      if (!accountId || !token) {
        throw new Error(
          "Cloudflare credentials are required. Fill in " +
          ".opencode/secrets/cloudflare-account-id.txt and " +
          ".opencode/secrets/cloudflare-api-token.txt, then restart OpenCode.",
        );
      }
      if (!/^[a-fA-F0-9]{32}$/.test(accountId)) {
        throw new Error("CLOUDFLARE_ACCOUNT_ID must be your 32-character hexadecimal Account ID.");
      }

      const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${model}`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ prompt, steps }),
          signal: AbortSignal.timeout(90_000),
        },
      );
      const payload = await response.json().catch(() => null);
      if (!response.ok || payload?.success === false) {
        const details = payload?.errors?.map((error) => error.message).filter(Boolean).join("; ");
        throw new Error(
          `Cloudflare Workers AI request failed (HTTP ${response.status}): ` +
          (details || response.statusText || "Unknown API error"),
        );
      }
      const encodedImage = payload?.result?.image ?? payload?.image;
      if (typeof encodedImage !== "string" || !encodedImage) {
        throw new Error("Cloudflare returned no image data.");
      }
      const bytes = Buffer.from(encodedImage, "base64");
      const { extension, mimeType } = imageFormat(bytes);
      const stem = filename || `cloudflare-${Date.now()}-${randomUUID().slice(0, 8)}`;
      const imagePath = await saveImage(bytes, stem, extension);
      return {
        content: [{ type: "text", text: JSON.stringify({ imagePath, mimeType, model, steps }, null, 2) }],
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }],
      };
    }
  },
);

await server.connect(new StdioServerTransport());
