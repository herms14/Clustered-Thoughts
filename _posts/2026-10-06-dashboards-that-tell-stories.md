---
title: Dashboards That Tell Stories
date: 2026-10-06 08:29:00 +0800
categories:
- Homelab
- Observability & Monitoring
tags:
- dashboards
- design
- glance
- homelab
- monitoring
description: A number going up or down isn't an insight until you know what to do about it. Most dashboards I've built, before this one, made exactly that mistake — they displayed information without committing to any meaning. The...
excerpt: A number going up or down isn't an insight until you know what to do about it. Most dashboards I've built, before this one, made exactly that mistake — they displayed information without committing to any meaning. The...
render_with_liquid: false
---

A number going up or down isn't an insight until you know what to do about it. Most dashboards I've built, before this one, made exactly that mistake — they displayed information without committing to any meaning. The question that actually changed things: when I open this, what should I know in the first five seconds? Not "what data exists here" but "what action, if any, do I need to take." That reframing changed every decision after it.

## The wall-of-graphs phase

My first Grafana dashboard was sixteen panels — CPU over time, memory by container, network throughput, disk I/O, all individually accurate and collectively useless for a quick check. The actual problem is cognitive load: sixteen graphs is sixteen things to evaluate, your eye doesn't know where to start, you scan randomly hoping something obvious jumps out, and if nothing does you assume everything's fine — which is a dangerous assumption when "fine" was never actually established, just not contradicted by a glance.

> A dashboard should answer one question at a time. Not "show me everything" — "is there a problem right now, yes or no."

## Glance's constraints turned into the actual design principle

Glance isn't a metrics platform, it's a homepage with widgets — no complex visualizations, no correlating time series, just a handful of things shown prominently. That limitation turned out to be the useful part: instead of "what can I display," the real question became "what do I need to see first thing in the morning," and the answer was never historical trends. It was current status, full stop.

My actual Home page answers three questions in under five seconds: is everything running, is anything alerting, what's the resource situation. It leans on the real widgets I settled on after a few rounds of pruning — Clock, Weather, Service Health, and a few non-infra panels (bookmarks, markets, tech news) that keep it from feeling like a wall of red/green only. If the service health widget is green across the board, I don't need details — I need to know *whether* to look closer, and the details only matter once that answer is yes.

## Boring is the whole design goal

When the dashboard looks boring — all green, nothing demanding attention — that's the dashboard working correctly. Interesting is bad: bright colors, non-zero problem counts, a visible alert panel all mean something needs investigation. This inverts the usual dashboard aesthetic, where "impressive" and "busy" get conflated. Mine is trying to look unremarkable. Unremarkable means nothing's on fire.

Visual hierarchy does the heavy lifting here. The real Container Monitoring dashboard (Compute page, built on top of `docker_container_running` and friends from the Docker-stats exporters) breaks containers down by host with color-coded counts — total containers in blue, utilities-host containers in purple, media-host containers in pink — specifically so a glance tells you *which* host's numbers moved, not just that something somewhere did. Color and position communicate faster than reading: a flash of red in peripheral vision gets attention before the brain has consciously parsed why. Status overview sits top-left, where a Western reader's eye lands first; historical detail lives further right and down, by design, not convention.

## Context is what actually turns a number into an insight

"CPU: 85%" is a number. "CPU: 85% (normal range: 40-60%)" is a question worth asking. "CPU: 85%, 10 minutes after a container restart" is an answer that doesn't need a follow-up question at all. My widgets carry that context where it's cheap enough to compute — the backup status widget (a small custom API behind Glance's `custom-api` widget type, polled every 10 minutes) doesn't just show a protected-VM count, it shows the count *changing*, which is what actually flags "something didn't get backed up last night" instead of making me notice a static number is wrong.

That context is genuinely expensive to build — it means aggregating across hosts, comparing against a baseline, and adding a human-readable interpretation on top, rather than just exposing a raw metric. But it's the difference between a dashboard that displays data and one that tells you what the data means.

## The widgets that earned a permanent spot, and why

- **Clock and weather** — trivially simple, but they're the context that makes everything else legible: high CPU at 3 AM during a known backup window is expected; the same spike at noon on a Saturday is not.
- **Service health** — reachability for the services that matter, nothing more. If the dots are green, the network and the services behind them are both fine, and that's the first and fastest thing worth confirming.
- **Container status, aggregated across hosts** — one API pulling from every Docker host's exporter, because any single host's view was never the picture I actually needed; what matters is the cluster-wide count moving.
- **Grafana embeds** — for the things that genuinely need a real chart (disk trends, throughput over time), deliberately kept off the primary page and available one click deeper.
- **Calendar** — scheduled maintenance and backup windows, so "unusual" and "expected" don't get confused with each other at a glance.

## Pages are scoped to a question, not a topic

Home answers "is everything okay right now." Media answers "what's happening with downloads and the library." Compute answers "how are the VMs and containers actually performing." Storage answers "am I close to running out of space anywhere." I don't need media stats in front of me while checking infrastructure health, so the pages stay separate — each one optimized for the one question it exists to answer, instead of one page trying to answer all of them at once.

## This took three iterations, not one

Version one had too much information; I cut hard. Version two, after cutting, had too little context to actually act on; I added interpretation back in deliberately rather than just more data. Version three fixed inconsistent color/position language that had crept back in across the cuts. Every iteration came from actually using it — noticing when I couldn't find something fast, noticing which widgets I'd started ignoring because they weren't earning their space, noticing when a real problem wasn't obvious until it was already too late to catch early. Dashboards aren't a one-time build; the needs shift as the infrastructure does, and a widget that mattered six months ago might just be noise now.

> The test I actually use for dashboard quality: show it to someone who's never seen this infrastructure, and see if they can tell, in ten seconds, whether things are healthy. If they can't, the dashboard makes sense only to the person who built it — which is a common failure mode, and a sign the labels, colors, or layout need to do more of the explaining.

## Closing thoughts on the whole series

Most of this infrastructure runs unattended most of the time, which is the entire point of building it this way — the dashboard exists specifically for the moments attention *is* needed: catching a problem early, understanding what changed, deciding what to do next. Those moments should cost as little time and cognitive effort as I can design away. That's not a display-of-data goal. It's an interface-to-understanding goal, and it's the same goal that's been underneath every post in this series — Terraform, Ansible, LXC, the vault itself, all of it exists to make the infrastructure legible to future-me, not just operational.

Thirty posts ago this started as a NAS meant to back up trip photos. It became a three-node cluster, a second knowledge base that's more reliable than the systems it describes, and — somewhere in the middle of writing this series — the reason I understand how production infrastructure actually behaves, not just how it's diagrammed. That was never really the plan. It's a better outcome than the plan would have been.

---

*This is the thirtieth and final post in this series about building and maintaining a homelab.*
