# Publishing guide: Obsidian → Clustered Thoughts

```
Obsidian vault                    this repo                     GitHub Pages
07 HomeLab Things/                _posts/YYYY-MM-DD-slug.md     herms14.github.io/
  Homelab Blog Posts/*.md  ─sync─▶  (Minimal Mistakes front matter)  ─push─▶  Clustered-Thoughts/posts/slug/
  publish: true
```

## 1. Write the post in Obsidian

Folder: `07 HomeLab Things/Homelab Blog Posts/`. Minimal front matter:

```yaml
---
title: "My post title"
date: 2026-10-20          # future date = scheduled (goes live at 09:00 that day)
publish: true             # the ONLY switch that publishes a post
slug: my-post             # optional; URL becomes /posts/my-post/
summary: "One or two sentences shown in the post list and search results."
categories: ["homelab", "ai"]   # max 2 (main / sub)
tags: ["proxmox", "codex"]
cover:                    # optional
  image: /assets/img/posts/server-rack.jpg
  alt: "Server rack"
---
```

`description` may be used instead of `summary`. `image: /assets/...` also works instead of `cover`.

## 2. Sync

```powershell
cd "C:\Users\herms\Side Projects\Clustered-Thoughts"
python scripts\sync_obsidian.py --dry-run   # preview what would change
python scripts\sync_obsidian.py --push      # write _posts/, commit, push
```

The converter:
- maps front matter to Minimal Mistakes (`title`, `date` in +0800, `categories`, `tags`, `description`/`excerpt`, and the cover image as `header.overlay_image` + `header.teaser`)
- rewrites `/assets/...` images and `../slug/` post links to absolute `/Clustered-Thoughts/...` URLs
- strips the duplicate `# Title` heading
- turns `[[wikilinks]]` into plain text
- converts Obsidian callouts (`> [!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!DANGER]`) into Minimal Mistakes notices (`<div class="notice--info" markdown="1">`)
- sets `render_with_liquid: false`, so `{{ }}` in code samples (Docker/Go templates) can't break the build

Re-running is idempotent: unchanged posts are skipped. Editing the vault post and syncing again updates the live post.

## 3. Images

Put images in `assets/img/posts/` in this repo and reference them as `/assets/img/posts/name.jpg`. The sync script adds the `/Clustered-Thoughts` base URL (Minimal Mistakes doesn't do this for post bodies). If you edit a post in `_posts/` directly, write `/Clustered-Thoughts/assets/img/posts/name.jpg`.

## 4. Unpublish

Delete the file from `_posts/` (and set `publish: false` in the vault so the next sync doesn't bring it back), then commit and push.

## Build failures

Every push runs `htmlproofer`, which fails the build on broken internal links or missing images. Check the **Actions** tab. The live site is only replaced when the build passes.
