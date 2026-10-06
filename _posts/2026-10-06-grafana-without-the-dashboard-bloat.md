---
title: Grafana Without the Dashboard Bloat
date: 2026-10-06 08:13:00 +0800
categories:
- Homelab
- Observability & Monitoring
tags:
- dashboards
- grafana
- homelab
- visualization
description: My first Grafana dashboard had sixteen panels — CPU, memory, disk I/O, network throughput, container counts, every metric I could think to add, arranged in a grid because a grid is what Grafana defaults to giving you.
excerpt: My first Grafana dashboard had sixteen panels — CPU, memory, disk I/O, network throughput, container counts, every metric I could think to add, arranged in a grid because a grid is what Grafana defaults to giving you.
render_with_liquid: false
---

My first Grafana dashboard had sixteen panels — CPU, memory, disk I/O, network throughput, container counts, every metric I could think to add, arranged in a grid because a grid is what Grafana defaults to giving you.

It was useless. Not inaccurate — every number was correct — but when I opened it, there was nowhere for my eyes to land. I'd scan randomly across sixteen panels hoping something would jump out, and nothing ever did unless a problem was already dramatic enough that I'd have noticed some other way first.

## A dashboard should answer one question

The fix wasn't more panels or better layout. It was treating each dashboard as the answer to a specific question instead of a general-purpose data dump:

- **Container Status** answers "are all my containers actually running?"
- **NAS Storage** answers "am I about to run out of space?"
- **Network Overview** answers "who's using the bandwidth right now?"

Each one has exactly one job. Opening Container Status means I'm checking container health — not also reviewing network throughput, because that's a different question with its own dashboard.

## Container Status is the one I actually open daily

A stat panel at the top shows total running containers — if that number drops, something stopped, full stop. Below it, a table: one row per container, status, uptime, resource usage, colored green/red by state.

```promql
container_memory_usage_bytes{name!=""}
+ on(name) group_left(image) container_start_time_seconds{name!=""}
```

Sort by memory, see what's actually consuming resources. Sort by start time, see what restarted recently — which is usually the first clue when something's misbehaving, since a container that just restarted eight times in an hour is telling you something before any alert does.

## The Synology dashboard, translated from SNMP

SNMP metrics arrive with cryptic names, so the dashboard's job is translation: disk temperatures become a heatmap, volume usage becomes gauges, and RAID status becomes a single stat with an explicit value mapping — because `1` meaning "healthy" is not something you want to have to remember mid-incident.

```promql
# RAID status, value-mapped: 1=Normal, 2=Repairing, 3=Migrating, 4=Expanding
synology_raid_status{instance="192.168.20.32"}
```

This dashboard is *supposed* to be boring — every gauge in a comfortable range, RAID reading "Normal," temperatures unremarkable. The moment it gets visually interesting is the moment something needs attention, and that's the entire design goal.

## Template variables, so one dashboard covers every host

```yaml
Name: host
Query: label_values(node_uname_info, nodename)
```

Queries reference `$host` instead of a hardcoded IP, and a dropdown at the top switches context without touching a single query. Container dashboards get a container variable the same way; network dashboards get an interface variable. Same pattern everywhere: filter by entity, let the variable pick the entity.

## Embedding in Glance needs two settings flipped first

```ini
[security]
allow_embedding = true

[auth.anonymous]
enabled = true
org_role = Viewer
```

Anonymous Viewer access is the uncomfortable-sounding part, and on an internal-only network it's the right trade — the alternative is a dashboard widget that can't load without a login prompt, which defeats the entire point of a dashboard you glance at. Getting the iframe URL's panel ID, theme, and org parameters right the first time rarely happens; a blank iframe with no error is the normal first result.

## Dashboards as JSON in Git, not as database rows

```yaml
# config/provisioning/dashboards/default.yml
providers:
  - name: 'default'
    type: file
    options:
      path: /var/lib/grafana/dashboards
```

Dashboards get exported to JSON and provisioned on startup rather than built-and-hoped-for in the UI. Changes go through Git, same as everything else in this homelab. This mattered more in practice than it sounds like it should: I've rebuilt Grafana from scratch twice — once after a failed update, once migrating hosts — and both times, having every dashboard as a tracked JSON file meant recreation took minutes instead of reconstructing panels from memory.

## Query performance becomes a real variable at scale

Early dashboards had queries that scanned every series on every page load, and load times stretched into multiple seconds.

```promql
# slow — scans every series
sum(rate(http_requests_total[5m]))

# fast — filters before aggregating
sum(rate(http_requests_total{job="api"}[5m])) by (status)
```

`$__rate_interval` instead of a hardcoded window lets Grafana pick a sane interval automatically; `topk(10, ...)` caps table rows instead of returning everything; thirty-second refresh for anything I actually watch live, five minutes for historical panels nobody needs updating that fast. None of these are individually dramatic, but together they're the difference between a dashboard that loads instantly and one I hesitate to open.

## The actual lesson

A dashboard is an interface, not an archive. It shouldn't try to display every metric available to it — it should answer a specific question fast, be boring when things are fine, and be obvious the one time they're not. I still have more dashboards than I need, and I cull the ones that never get opened. The three I actually use daily — container status, storage capacity, network overview — earned their place by getting opened; everything else is a leftover from curiosity that's since moved on.

---

*This is the fourteenth post in a series about building and maintaining a homelab. Next: SNMP — the protocol older than me that's still how you get metrics out of a NAS and a managed switch.*
