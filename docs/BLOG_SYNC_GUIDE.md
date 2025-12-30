# Blog Sync Guide: Obsidian to Hugo

This guide explains how to publish blog posts from your Obsidian vault to the Clustered Thoughts blog.

---

## Quick Reference

| Action | Command |
|--------|---------|
| Preview what will sync | `.\scripts\sync-obsidian-posts.ps1 -DryRun` |
| Sync posts | `.\scripts\sync-obsidian-posts.ps1` |
| Sync and push to GitHub | `.\scripts\sync-obsidian-posts.ps1 -Push` |
| Force overwrite existing | `.\scripts\sync-obsidian-posts.ps1 -Force -Push` |

---

## How It Works

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│    Obsidian     │      │   Hugo Blog     │      │  GitHub Pages   │
│                 │      │                 │      │                 │
│  status: ready  │ ──►  │  content/posts  │ ──►  │   Live Site     │
│  status: sched  │ sync │                 │ push │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

1. **Write** posts in Obsidian with `status: draft`
2. **Change status** to `ready` or `scheduled` when ready
3. **Run sync script** to transform and copy to blog repo
4. **GitHub Actions** builds and deploys automatically
5. **Scheduled posts** auto-publish at 9am Manila time daily

---

## Step-by-Step: Publish a Post Immediately

### Step 1: Update the Post Status in Obsidian

Open your blog post in Obsidian and change the front matter:

```yaml
---
title: "Network Segmentation That Actually Makes Sense"
series: Foundation Layer
post_number: 4
tags:
  - homelab
  - networking
created: 2025-12-27
status: ready          # ← Change from 'draft' to 'ready'
---
```

### Step 2: Open PowerShell

Open PowerShell or Windows Terminal and navigate to the blog folder:

```powershell
cd "C:\Users\herms\Side Projects\Clustered-Thoughts"
```

### Step 3: Preview the Sync (Optional)

Run a dry run to see what will be synced:

```powershell
.\scripts\sync-obsidian-posts.ps1 -DryRun
```

Expected output:
```
=== Obsidian to Hugo Blog Sync ===
[DRY RUN] Running in DRY RUN mode - no changes will be made
[INFO] Found 1 post(s) to sync:
  - Network Segmentation That Actually Makes Sense [ready]
[DRY RUN] Would sync: Network Segmentation That Actually Makes Sense -> network-segmentation-that-actually-makes-sense.md
[INFO] Sync complete: 1 synced, 0 skipped
```

### Step 4: Sync and Push

Run the sync script with the `-Push` flag:

```powershell
.\scripts\sync-obsidian-posts.ps1 -Push
```

Expected output:
```
=== Obsidian to Hugo Blog Sync ===
[INFO] Found 1 post(s) to sync:
  - Network Segmentation That Actually Makes Sense [ready]
[OK] Synced: Network Segmentation That Actually Makes Sense -> network-segmentation-that-actually-makes-sense.md
[INFO] Sync complete: 1 synced, 0 skipped
[INFO] Pushing to GitHub...
[OK] Pushed to GitHub successfully
```

### Step 5: Verify

Your post will be live within 2-3 minutes at:
```
https://herms14.github.io/Clustered-Thoughts/posts/network-segmentation-that-actually-makes-sense/
```

---

## Step-by-Step: Schedule a Post for Later

### Step 1: Update Front Matter with Schedule

Add `status: scheduled` and `publish_date` to your post:

```yaml
---
title: "Docker Compose Patterns That Scale"
series: Containerization Deep-Dives
post_number: 8
tags:
  - homelab
  - docker
created: 2025-12-27
status: scheduled           # ← Set to 'scheduled'
publish_date: 2025-01-15    # ← When to publish
---
```

### Step 2: Sync and Push

```powershell
cd "C:\Users\herms\Side Projects\Clustered-Thoughts"
.\scripts\sync-obsidian-posts.ps1 -Push
```

### Step 3: Wait for Publish Date

- The post is now in your GitHub repo but **hidden** (future date)
- GitHub Actions runs daily at **9am Manila time**
- On January 15, the scheduled rebuild will include your post
- The post goes live automatically

---

## Front Matter Reference

### Obsidian Format (Input)

```yaml
---
title: "Your Post Title"
series: Foundation Layer
post_number: 4
tags:
  - homelab
  - networking
created: 2025-12-27
status: draft | ready | scheduled
publish_date: 2025-01-15    # Only needed for scheduled
---
```

### Hugo Format (Output)

The sync script automatically transforms to:

```yaml
---
title: "Your Post Title"
description: "Auto-extracted from TL;DR or first paragraph"
date: 2025-12-27
slug: your-post-title
categories:
    - Homelab
    - Infrastructure
tags:
    - homelab
    - networking
---
```

### Status Values

| Status | Behavior |
|--------|----------|
| `draft` | Not synced - stays in Obsidian only |
| `ready` | Synced immediately, publishes on next build |
| `scheduled` | Synced with future date, auto-publishes when date arrives |

### Series to Category Mapping

| Series | Categories |
|--------|------------|
| Origins | Homelab, Origins |
| Foundation Layer | Homelab, Infrastructure |
| Containerization Deep-Dives | Homelab, Containers |
| Observability & Monitoring | Homelab, Monitoring |
| Automation & Bots | Homelab, Automation |
| Advanced Topics | Homelab, Advanced |
| Lessons Learned | Homelab, Lessons |

---

## Troubleshooting

### "No posts found with status: ready or scheduled"

All your posts have `status: draft`. Change at least one post to `status: ready` or `status: scheduled`.

### Post not appearing after sync

1. Check GitHub Actions: https://github.com/herms14/Clustered-Thoughts/actions
2. Verify the build completed successfully
3. Wait 2-3 minutes for GitHub Pages to update
4. Hard refresh the page (Ctrl+Shift+R)

### Scheduled post not publishing

- Scheduled rebuilds run at **9am Manila time (1am UTC)** daily
- If it's before 9am on the publish date, wait for the scheduled build
- You can manually trigger a build: GitHub repo → Actions → Run workflow

### Want to update an already-synced post

Make changes in Obsidian, then run:

```powershell
.\scripts\sync-obsidian-posts.ps1 -Force -Push
```

The `-Force` flag overwrites even if the post exists.

### Script execution policy error

If you get a security error, run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

Then run the sync script again.

---

## File Locations

| Item | Path |
|------|------|
| Obsidian Posts | `C:\Users\herms\OneDrive\Obsidian Vault\Hermes's Life Knowledge Base\07 HomeLab Things\Homelab Blog Posts\` |
| Blog Repo | `C:\Users\herms\Side Projects\Clustered-Thoughts\` |
| Sync Script | `C:\Users\herms\Side Projects\Clustered-Thoughts\scripts\sync-obsidian-posts.ps1` |
| Hugo Posts | `C:\Users\herms\Side Projects\Clustered-Thoughts\content\posts\` |

---

## Automation Schedule

| Event | Time | Action |
|-------|------|--------|
| Push to main | Immediate | Build and deploy |
| Daily schedule | 9am Manila (1am UTC) | Rebuild (publishes scheduled posts) |
| Manual trigger | Anytime | GitHub Actions → Run workflow |

---

## Example Workflow: Publishing a Week of Posts

```powershell
# In Obsidian, set up your posts:
# Post 4: status: ready (publishes today)
# Post 5: status: scheduled, publish_date: 2025-01-02
# Post 6: status: scheduled, publish_date: 2025-01-04
# Post 7: status: scheduled, publish_date: 2025-01-06

# Sync all at once
cd "C:\Users\herms\Side Projects\Clustered-Thoughts"
.\scripts\sync-obsidian-posts.ps1 -Push

# Post 4 goes live immediately
# Posts 5, 6, 7 auto-publish on their scheduled dates at 9am
```

---

*Last updated: December 30, 2025*
