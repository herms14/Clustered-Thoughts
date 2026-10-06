---
title: The Media Stack That Runs Itself
date: 2026-10-06 08:10:00 +0800
categories:
- Homelab
- Containerization Deep-Dives
tags:
- homelab
- jellyfin
- media
- radarr
- sonarr
description: 'The first version of this was manual: download something, rename it, drop it in the right folder, refresh the library. That works for a handful of files. It falls apart the moment you want more than a handful, which is...'
excerpt: 'The first version of this was manual: download something, rename it, drop it in the right folder, refresh the library. That works for a handful of files. It falls apart the moment you want more than a handful, which is...'
render_with_liquid: false
---

The first version of this was manual: download something, rename it, drop it in the right folder, refresh the library. That works for a handful of files. It falls apart the moment you want more than a handful, which is exactly when the *arr stack — Radarr, Sonarr, Prowlarr, and friends — starts to make sense.

It's a longer setup than the problem sounds like it should need. But once it's wired correctly, it runs for months without me touching it.

All of it lives on one host: `docker-vm-media01`, `192.168.40.11`. Everything below runs there via Docker Compose.

## What each piece actually does

- **Prowlarr** (`:9696`) manages indexers — the search sources — and syncs those settings to Radarr and Sonarr automatically, so I configure search sources once instead of per-app.
- **Radarr** (`:7878`) handles movies: searches indexers through Prowlarr, sends the result to a download client, imports the finished file.
- **Sonarr** (`:8989`) does the same for TV, plus season/episode tracking and monitoring for shows that are still airing.
- **Deluge** (`:8112`) and **SABnzbd** (`:8081`) do the actual downloading — BitTorrent and Usenet respectively. The *arr apps coordinate; they don't fetch anything themselves.
- **Jellyfin** (`:8096`) serves the library — scans folders, pulls metadata, streams to whatever's playing it.

(I run Lidarr, Prowlarr, Bazarr, Overseerr/Jellyseerr, and a couple of others alongside these — same pattern, same host, not worth separate sections.)

## The thing that actually breaks: paths

The one lesson that mattered more than all the others combined: every container needs to agree on the same path for the same file.

Here's the failure mode, concretely. Deluge downloads to `/data/Downloading`. If Radarr is looking for the finished file under a different mount — say `/media/movies` because nobody standardized the compose files — the import silently fails to find it, even though the file is sitting right there on disk, one directory over, in a different container's view of the filesystem.

The fix is a unified `/data` mount across every container that touches media: `/data/Downloading`, `/data/Completed`, and the library paths Jellyfin reads from, all mapped identically everywhere. Once every container sees the same paths, Radarr finds exactly what it expects, where it expects it.

> This is also what makes hardlinks work. A hardlink is a second directory entry pointing at the same bytes on disk — so Deluge can keep seeding a torrent while Jellyfin serves the same file, without a second copy ever existing. Hardlinks only work *within a single filesystem*, though. If downloads land on one disk and the library lives on another, you silently get copies instead of hardlinks — same behavior, double the disk usage, no error message telling you why.

## NFS made the hardlink problem worse before it made it better

My media lives on a Synology NAS, mounted over NFS into the Docker host. NFS hardlinks don't always behave like local-filesystem hardlinks — depending on export settings and mount options, a "hardlink" can silently degrade into a full copy and nothing tells you.

I noticed because disk usage kept climbing on a volume that should have been roughly stable. It took longer than I'd like to admit to connect "disk filling up" to "hardlinks aren't actually linking." The fix was on both ends — NFS export options on the NAS, matching mount flags on the client — and the specific combination that works depends enough on your NAS and NFS version that I won't pretend my exact flags are universally correct. Worth testing for real rather than assuming it's working: create a file, hardlink it, delete the original, confirm the "linked" copy still has content.

## The request flow, when it's working

1. A request comes in through Jellyseerr
2. Jellyseerr hands it to Radarr
3. Radarr searches via Prowlarr's indexers
4. Radarr sends the best result to Deluge or SABnzbd
5. The client downloads (and, for torrents, keeps seeding)
6. Radarr detects completion, renames, hardlinks into the media folder
7. Jellyfin picks up the new file and adds it to the library

Any one of these seven steps can fail independently, and when something's wrong, step 1 is almost never where the actual problem is — it's almost always a path mismatch two or three steps downstream.

## Quality profiles are a quieter trade-off than they look

Radarr and Sonarr grab releases according to a quality profile — the rule set for "what's good enough." Mine: prefer 1080p, accept 720p, reject 4K outright, because nothing in this stack transcodes 4K smoothly. Custom formats layer on top of that to prefer or avoid specific release groups.

The thing that isn't obvious until you hit it: quality settings interact with what your indexers actually have. Set the profile too strict relative to your indexers' real inventory, and nothing matches — Radarr sits there "wanted" forever, not because the content doesn't exist, but because nothing on your indexers clears the bar you set. It's a balance between standards and what's actually available, and the failure mode (silence, not an error) makes it easy to mistake for a different bug entirely.

## Surfacing it on Glance needed a small aggregator

Radarr and Sonarr have APIs, but not in a shape Glance's `custom-api` widget can render directly without a lot of per-widget template logic. I built a small Flask service — `media-stats-api`, running on `docker-vm-core-utilities-1` (`192.168.40.13:5054`) — that queries both APIs and returns one combined JSON blob: wanted/downloading/downloaded counts for movies and episodes.

```json
{
  "stats": [
    {"label": "WANTED MOVIES", "value": 15, "color": "#f59e0b"},
    {"label": "MOVIES DOWNLOADING", "value": 9, "color": "#3b82f6"},
    {"label": "EPISODES DOWNLOADING", "value": 98, "color": "#8b5cf6"}
  ]
}
```

Glance hits that one endpoint instead of two. This pattern — small aggregator API in front of something that doesn't speak dashboard natively — shows up everywhere in this homelab. I'll come back to it properly in the Glance post, since the same trick solves half of what makes that dashboard useful.

## Two media servers, on purpose

Plex runs on the Synology NAS directly and handles smart-TV apps, remote access, and sharing with people who don't want to think about any of this. Jellyfin runs in Docker and is the no-account, no-phone-home version I actually tinker with. Both read the same library — it exists once, served twice, for two different audiences.

## What still annoys me

Configuration sprawl. Each app has its own web UI, its own database, its own export format. Prowlarr syncs *some* settings to Radarr/Sonarr, not all of them. Backing this up means backing up several independent config directories, each with its own quirks if you ever need to restore one.

Recyclarr exists specifically to standardize *arr configuration against community-maintained presets, and I haven't committed to it — partly laziness, partly because the current setup clears the bar of "works well enough that fixing it isn't worth the afternoon." That threshold is doing more work in this homelab than I'd like to admit, and it's probably fine.

---

*This is the eleventh post in a series about building and maintaining a homelab. Next: turning Glance from a links page into the dashboard I actually check every morning.*
