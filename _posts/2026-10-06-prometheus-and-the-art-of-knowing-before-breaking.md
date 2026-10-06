---
title: Prometheus and the Art of Knowing Before Breaking
date: 2026-10-06 08:12:00 +0800
categories:
- Homelab
- Observability & Monitoring
tags:
- homelab
- metrics
- monitoring
- prometheus
description: The first time an alert told me a disk was getting full before a container crashed because it couldn't write, I understood why people bother with a monitoring stack at all. Before that, it felt like graphs for the sake...
excerpt: The first time an alert told me a disk was getting full before a container crashed because it couldn't write, I understood why people bother with a monitoring stack at all. Before that, it felt like graphs for the sake...
render_with_liquid: false
---

The first time an alert told me a disk was getting full *before* a container crashed because it couldn't write, I understood why people bother with a monitoring stack at all. Before that, it felt like graphs for the sake of graphs — accurate, pretty, and not actually changing what I did.

The stack is the boring, well-documented one on purpose: Prometheus for metrics, AlertManager for routing notifications, Grafana for the visuals. Node Exporter covers host basics (CPU, memory, disk, network) on every Proxmox node and Docker host. cAdvisor adds per-container numbers. SNMP Exporter translates whatever the Synology NAS and the switches are willing to say over SNMP. Every scrape runs every fifteen seconds.

The model takes a second to internalize if you're used to push-based monitoring: Prometheus *pulls*. Your service exposes a metrics endpoint; Prometheus scrapes it on a schedule. If a target stops responding, Prometheus notices immediately — it shows up as `down`, which is itself useful signal, not just an absence of signal.

## The target list, growing one host at a time

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets:
          - '192.168.20.20:9100'  # node01
          - '192.168.20.21:9100'  # node02
          - '192.168.40.11:9100'  # docker-vm-media01
          - '192.168.40.13:9100'  # docker-vm-core-utilities-1
```

Three Proxmox nodes, several Docker hosts, one NAS. Every new host is the same four steps: add the target, install Node Exporter, confirm it's scraping on Prometheus's Targets page, then build the dashboard panels and alert rules. After the fourth or fifth host it stops requiring thought.

## My first alert rules were useless, and loud about it

CPU over 50%? Alert. Memory over 60%? Alert. My phone buzzed constantly over conditions that corrected themselves in under a minute — a backup running, a service starting cold. None of it needed me.

```yaml
- alert: HighCPUUsage
  expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 10m
```

The `for: 10m` clause is the entire fix. Don't fire unless the condition has held for ten straight minutes — that one clause eliminated nearly all the noise, because almost nothing that's actually fine stays elevated for ten minutes.

What I alert on now, specifically: disk space above 85%, memory sustained above 85%, any target down for more than two minutes, container restart count above three in an hour. Each of those correlates with something I'd actually want to act on, which is a much shorter list than "everything I could technically measure."

> The disk-space rule paid for itself the first week it existed. A warning fired on `/var/lib/docker` sitting at 87% on one Docker host — old images and dead volumes, fifteen minutes of cleanup. A week later the same alert fired on a *different* host, same fix. Before this existed, I'd have found out when a container failed to start because it couldn't write, which is a worse way to learn the same fact.

## cAdvisor turns a Docker host from a black box into something legible

cAdvisor needs privileged access and a handful of host filesystem mounts to see what it sees, which feels like a lot to grant for a metrics exporter — but the payoff is per-container CPU, memory, network, and disk I/O, which Node Exporter alone can't give you.

```yaml
cadvisor:
  image: gcr.io/cadvisor/cadvisor:latest
  privileged: true
  ports:
    - "8081:8080"
  volumes:
    - /:/rootfs:ro
    - /var/run:/var/run:ro
    - /sys:/sys:ro
    - /var/lib/docker/:/var/lib/docker:ro
```

Without it, "CPU is high on this host" is where the investigation ends. With it, "CPU is high because *this specific container* is transcoding" is where it starts — which is the difference between a five-minute fix and an afternoon of guessing.

## Routing alerts somewhere I'll actually see them

Discord, because I'm already in it constantly, and a notification that arrives where I'm not looking doesn't function as a notification.

```yaml
route:
  receiver: 'discord'
  routes:
    - match:
        severity: critical
      receiver: 'discord-critical'
      repeat_interval: 1h
```

Critical alerts re-fire hourly until resolved; everything else re-fires every four hours. That split matters — it keeps a genuinely unresolved critical issue from going quiet after one notification, without making every warning as insistent as the thing that actually needs me right now.

## Retention is a decision, not a default

Prometheus keeps everything unless told otherwise, which eventually means running out of disk for no reason you'd notice until it's already a problem. Mine's capped at ninety days or fifty gigabytes, whichever hits first — enough runway to spot a slow capacity trend, not so much that old data I'll never query sits around consuming disk indefinitely.

## What I'd do differently

Start with fewer collectors. Early on I turned on every exporter, scraped every metric it offered, and built dashboards for most of them — and the overwhelming majority of that data has never once been looked at since. It just sits in the TSDB, slowing queries down a little and adding nothing.

The version I'd build now: add a metric when I catch myself actually wanting it, not preemptively, because "might be useful someday" is how you end up with ninety days of a time series nobody has ever queried.

---

*This is the thirteenth post in a series about building and maintaining a homelab. Next: turning raw Prometheus data into Grafana dashboards that are boring when things work and obvious when they don't.*
