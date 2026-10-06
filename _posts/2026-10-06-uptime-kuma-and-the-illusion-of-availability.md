---
title: Uptime Kuma and the Illusion of Availability
date: 2026-10-06 08:15:00 +0800
categories:
- Homelab
- Observability & Monitoring
tags:
- homelab
- monitoring
- status
- uptime
description: 'Prometheus tells me what happened over time. Uptime Kuma tells me what''s true right now. Those sound like the same job described two ways, and they''re not: Prometheus is a time-series database I query when I already...'
excerpt: 'Prometheus tells me what happened over time. Uptime Kuma tells me what''s true right now. Those sound like the same job described two ways, and they''re not: Prometheus is a time-series database I query when I already...'
render_with_liquid: false
---

Prometheus tells me what happened over time. Uptime Kuma tells me what's true right now. Those sound like the same job described two ways, and they're not: Prometheus is a time-series database I query when I already suspect something's wrong. Uptime Kuma just checks — is this reachable, is this port open, does this URL return what I told it to expect — on a loop, with no interpretation required.

## It's deliberately, almost suspiciously simple

One container, one SQLite file, nothing else to run.

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
```

First launch creates an admin account, and you start adding monitors immediately. The simplicity is the actual feature: when the thing watching everything else goes down, you want it back fast, and "restore the data directory, start one container" is about as fast as that gets.

## The monitor types cover almost every real case

- **HTTP** — expects `https://grafana.hrmsmrflrii.xyz` to return 200. Anything else, it's red.
- **TCP** — is port 22 open? Doesn't care what's behind it, just whether the port answers.
- **DNS** — does the hostname still resolve to what I expect? DNS breaking silently takes down "working" services, because the service itself never noticed anything changed.
- **Docker** — reads container state directly off the Docker socket, so it's accurate without depending on the network path at all.

## The status page turned out more useful internally than I expected

A status page groups monitors and shows them publicly. I don't actually expose mine outside the network — but as an internal quick-glance health view, grouping matters a lot more than I assumed it would going in:

- **Core Services**: Traefik, Authentik, Pi-hole
- **Applications**: Grafana, Glance, GitLab
- **Media**: Jellyfin, Radarr, Sonarr
- **Infrastructure**: Proxmox, PBS, Synology

Scanning four groups takes seconds, and red in Core Services is a different priority than red in Media — the grouping does that triage for me before I've even clicked anything.

## Notifications needed tuning, or they're just noise

The first version notified on everything — up, down, recovered — and the result was a Discord channel full of blips: a container restarting during an update, a brief network hiccup, nothing that actually needed me. None of it was wrong, exactly, it was just too sensitive to be useful.

The fix: require multiple consecutive failed checks before notifying (three, not one), and only send a recovery notification if the outage was actually long enough to have been notified about in the first place. Repeat interval matters too — a thing that's still down doesn't need a reminder every five minutes; once an hour is enough to stay aware without becoming background noise I start ignoring.

## Maintenance windows stop planned work from looking like an outage

Updating containers or rebooting a host causes brief, expected downtime. Without a maintenance window, that's a down notification immediately followed by an up notification, for a non-event. Creating a window tells Uptime Kuma "expect this" — affected monitors go quiet for the duration, then resume normally.

I keep a recurring one for Sunday-morning update sessions, and create an ad-hoc window before anything unplanned.

## Feeding the status into Glance

```yaml
- type: custom-api
  url: http://192.168.40.13:3001/api/status-page/status
  template: |
    {{ if eq (.JSON.String "status") "allUp" }}
      All Services Operational
    {{ else }}
      Service Degradation Detected
    {{ end }}
```

One indicator — everything's fine, or something needs a look — rather than embedding the full Uptime Kuma UI. The detail is one click away in Uptime Kuma itself if the summary says to go look.

## The actual value was psychological, and I didn't expect that

Prometheus would eventually catch most of the same failures through symptoms — a service down shows up as a dropped metric eventually. But there's a real, not-entirely-rational difference between "something would alert me eventually" and "something is actively checking, right now, and showing green." The second one removes a low background hum of "is everything actually okay?" that the first doesn't, even though they cover mostly the same failures.

## What it doesn't tell you

Reachable isn't the same as correct. A service can answer HTTP 200 while its database connection is dead underneath. Green means "responded to the specific check I configured," not "is fully functional" — Uptime Kuma supports keyword and JSON-field checks for going deeper, but only for things you've already thought to check. I use plain HTTP checks for most services and rely on noticing functional breakage myself. Not comprehensive. Catches the outages, which are the urgent ones.

---

*This is the sixteenth post in a series about building and maintaining a homelab. Next: the Discord bots — and the three earlier versions that taught me what a bot shouldn't do before I built one that actually helps.*
