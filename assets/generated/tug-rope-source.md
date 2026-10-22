# Tug of War rope artwork

- **Source:** `tug-rope-source.jpg`, generated with the Cloudflare Workers AI image MCP on 2026-10-22.
- **Model:** `@cf/black-forest-labs/flux-1-schnell`, 8 steps.
- **Art direction:** One straight, uniformly thick horizontal brown braided rope, dark outline, warm fiber highlights, isolated on magenta for background removal.
- **Runtime asset:** `games/Tug Of war/assets/rope-uniform.png`. An interior section of the generated braid was chroma-keyed, reduced to a 32 × 8 pixel tile, and mapped to a six-color warm pixel-art palette. The silhouette and tile seam were normalized for a continuous 24-pixel-wide `Line2D`.
- **Character integration:** `p1-puller.png` through `p4-puller.png` are derived from the original corresponding character atlases. Only the 129 baked-in rope pixels beyond each character's hand outlines were removed. The original atlases are retained as the source artwork.
- **Pull effects:** `p1-pull-effect.png` through `p4-pull-effect.png` are derived from the original corresponding `pN effect.png` atlases. The baked-in rope pixels beyond the hand outlines were removed: local columns 22–31, rows 18–20 in frame zero, and columns 21–31, rows 19–21 in subsequent source frames (162 pixels for P1, 129 for P2–P4). Character pixels and motion lines are preserved. P2–P4 have four source frames, so their last rope-free idle pose is appended to match P1's fifth recovery frame and keep effect timing consistent. Idle and effect animations share a single sprite and grip alignment so only the continuous `Line2D` supplies the rope in either state.
