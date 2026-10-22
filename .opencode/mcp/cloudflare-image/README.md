# Project-local Cloudflare image MCP

This local stdio adapter uses the official MCP SDK and the Cloudflare Workers AI
REST API. The `generate_image` tool uses `@cf/black-forest-labs/flux-1-schnell` and
saves image files in this project's `assets/generated/` directory. Filenames are
versioned when a file already exists, and the extension matches the image format.

## Activate image generation

1. Open [Cloudflare Workers AI](https://dash.cloudflare.com/?to=/:account/ai/workers-ai).
2. Select **Use REST API**, then **Create a Workers AI API Token**.
3. Put the token in `.opencode/secrets/cloudflare-api-token.txt`.
4. Copy the **Account ID** into `.opencode/secrets/cloudflare-account-id.txt`.
5. Quit and restart OpenCode in this project.

The token needs Workers AI Read and Edit permissions. The credential files are
git-ignored. The server can connect and list its tool before credentials are
provided; generation requires valid credentials.

Cloudflare currently includes 10,000 neurons per day on the Workers Free plan.
The number of images depends on generation settings and other Workers AI usage.
See [Cloudflare pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/).

## Example tool arguments

```json
{
  "prompt": "A colorful pixel-art tropical village background for a 2D game",
  "steps": 4,
  "filename": "village-background"
}
```

To verify the adapter locally, run `npm test` in this directory. Tests mock the
Cloudflare API and do not consume the account's generation quota.
