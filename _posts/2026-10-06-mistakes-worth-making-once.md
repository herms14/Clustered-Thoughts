---
title: Mistakes Worth Making Once
date: 2026-10-06 08:25:00 +0800
categories:
- Homelab
- Lessons Learned
tags:
- debugging
- homelab
- lessons
- mistakes
description: Every homelabber accumulates a collection of these — not theoretical risks, actual failures that burned real hours of debugging. Here's mine, specific numbers and all, documented so you can make different mistakes than...
excerpt: Every homelabber accumulates a collection of these — not theoretical risks, actual failures that burned real hours of debugging. Here's mine, specific numbers and all, documented so you can make different mistakes than...
render_with_liquid: false
---

Every homelabber accumulates a collection of these — not theoretical risks, actual failures that burned real hours of debugging. Here's mine, specific numbers and all, documented so you can make different mistakes than I did.

**Management plane on experimental infrastructure.** I ran the Omada network controller on my Synology NAS — made sense on paper, the NAS is always on. Until I rebooted the NAS for routine maintenance and lost all network management visibility at the exact moment I needed it. The controller now runs in its own dedicated LXC on a stable node.

> Never put your management plane on anything you also use for experimentation. If you can imagine yourself rebooting it on a whim, it's the wrong home for something you need during an incident.

**Path mismatches across the media stack.** qBittorrent downloaded to `/downloads/movies`. Radarr expected `/data/media/movies`. Jellyfin scanned `/media/movies`. Three different paths that didn't line up meant Radarr's imports *worked* but copied files instead of hardlinking — silently doubling storage — and Jellyfin showed random missing files because the paths it scanned weren't the paths anything actually wrote to. Fix was a unified mount structure: every container mounts `/data` at the identical path, downloads go to `/data/torrents/`, media goes to `/data/media/`, and hardlinks work because it's genuinely the same filesystem underneath, not three containers' worth of separate mount namespaces pretending to agree.

> Plan your path structure before the first container goes live, not after the third one disagrees with the first two.

**Docker's `localhost` is a trap.** Glance was configured to fetch from `http://localhost:5054` and every custom widget errored. Inside the Glance container, `localhost` means *the Glance container* — not the host the API was actually running on. Fix: the Docker bridge gateway (`172.17.0.1`), or container names if both are on the same Docker network.

> In Docker, `localhost` is never what your intuition says it is. Check which network namespace you're actually in before debugging anything else.

**Exporter upgrades silently rename metrics.** A Grafana dashboard built on cAdvisor's `container_cpu_usage_seconds_total` broke outright after a cAdvisor upgrade — the new version exports `container_cpu_usage_seconds`, no `_total` suffix, and the old query just returned nothing with no error to point at why:

```promql
sum(rate(container_cpu_usage_seconds_total{name=~".+"}[5m])) by (name)
or
sum(rate(container_cpu_usage_seconds{name=~".+"}[5m])) by (name)
```

> Pin exporter versions, or build dashboards that degrade gracefully across a rename. "It worked yesterday" is not a debugging strategy when the metric itself quietly stopped existing.

**Two different kinds of permission denied.** A GitLab token scoped `read_api` could list issues for a Discord bot just fine, then threw 403 the moment it tried to close one — closing requires `api` scope, not `read_api`, and separately, the token's user needed actual project membership, not just a valid token.

> When an API 403 shows up, check the token's scope *and* the underlying user's permissions. Either one alone can look identical from the outside.

**Backups that failed silently for six months.** Nightly Proxmox backups, configured once, trusted completely — until I actually needed a restore and discovered they'd been failing for months because the storage backing them had quietly filled up, with no email alert configured and nothing monitoring for it. I test restores monthly now: pick a VM, restore to a throwaway ID, confirm it boots, delete it. Twenty minutes for the difference between hoping and knowing.

> A backup you haven't restored from is not a backup — it's a belief about a backup.

**Hardcoded secrets in "quick" test scripts.** A one-off script with an API key typed directly into the source, something like `API_KEY = "sk-test-replace-me-before-committing"` — and forgetting to remove it before almost pushing. Now: environment variables only, pre-commit hooks that scan for key-shaped strings, and periodic grep audits as a backstop for the hooks.

> Type zero secrets directly into code, starting from the very first script. The "I'll remove it before I commit" plan fails exactly as often as you'd expect.

**Eight VLANs before understanding inter-VLAN routing.** Services couldn't reach each other, I spent hours chasing firewall rules that were working exactly as configured, and eventually flattened back down to three: infrastructure (Proxmox, Ansible), services (Docker, applications), and IoT (cameras, smart home) — clean separation without routing complexity I wasn't ready to reason about yet.

> Start with fewer VLANs than you think you need. You can always split further once you understand why you're splitting.

**Guessing before reading the log.** Something broke, I tried fixes based on hunches for two wasted hours, then finally checked `docker logs` and found the actual answer in the first ten lines.

> Logs first, always — `docker logs`, `journalctl`, whatever's native to the thing that broke — then connectivity, then config, then hypothesize. Skipping straight to hypothesizing is how you lose two hours to something that was printed the whole time.

**Kubernetes for things that needed none of what Kubernetes offers.** Weeks learning K8s concepts for services that could have stayed in Docker Compose the entire time; simple deployments turned into multi-file manifests for no operational benefit. Most of it moved back to Compose.

> Kubernetes earns its complexity for multi-replica services that need real auto-scaling or sophisticated rollouts — or when learning Kubernetes itself is the actual goal. For a dashboard running one container, it's pure overhead. Compose covers the overwhelming majority of what a homelab actually needs.

---

Each of these taught something specific, and the lessons genuinely compound — the homelab got more reliable in direct proportion to how many of these I stopped repeating. The goal isn't avoiding mistakes entirely; it's making new ones instead of the same old one twice.

---

*This is the twenty-sixth post in a series about building and maintaining a homelab. The next post covers the true cost of homelabbing.*
