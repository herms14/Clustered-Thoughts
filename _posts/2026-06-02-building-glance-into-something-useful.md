---
title: Building Glance Into Something Useful
date: 2026-06-02 08:00:00 +0800
categories:
- Homelab
- Containerization Deep-Dives
tags:
- customization
- dashboard
- glance
- homelab
description: I tried a few dashboard tools before Glance stuck. Homepage was mostly a links page. Heimdall felt dated the moment I opened it. Grafana is excellent at metrics and actively wrong for "what should I check first thing in...
excerpt: I tried a few dashboard tools before Glance stuck. Homepage was mostly a links page. Heimdall felt dated the moment I opened it. Grafana is excellent at metrics and actively wrong for "what should I check first thing in...
render_with_liquid: false
---

I tried a few dashboard tools before Glance stuck. Homepage was mostly a links page. Heimdall felt dated the moment I opened it. Grafana is excellent at metrics and actively wrong for "what should I check first thing in the morning": too much precision, not enough summary.

Glance landed in the middle: lightweight, YAML-configured, and (the part that actually mattered) able to render a `custom-api` widget pointed at anything that returns JSON. If a service has an API, it can end up on this dashboard, whether or not Glance has native support for it.

## The custom-api widget is doing most of the real work

Most dashboard tools support a fixed list of integrations. Glance lets you fetch any URL, parse the JSON, and render it through a Go template. That one feature is why my dashboard shows container status from a custom aggregator, download progress from the *arr APIs, calendar events pulled from an Obsidian REST API plugin, and a "life progress" percentage from a small personal API I built just for that one number.

Go templates have a real learning curve if you haven't touched them (`.JSON.String "path.to.field"` to pull a value, `range` to iterate a list), but once those two patterns click, almost anything JSON-shaped is renderable.

## The `localhost` gotcha cost me more time than it should have

Glance runs in its own container. My aggregator APIs run on the Docker host directly. I pointed a widget at `http://localhost:5054` and got nothing back, with no error that pointed at the actual cause.

The reason: `localhost` inside a container refers to the container itself, not the host it's running on. The fix is the Docker bridge gateway address (`172.17.0.1` on a default bridge network), which does route from inside a container back out to the host.

```yaml
- type: custom-api
  url: http://172.17.0.1:5054/api/stats
```

The alternative is putting the API in a container too and using Docker's internal DNS (container names resolve within a shared network). I use the bridge-gateway route instead, mostly because my aggregator APIs (like `media-stats-api` on `192.168.40.13:5054`) predate me containerizing everything else.

## Pages as separate questions, not one big grid

- **Home.** The morning check: status, calendar, anything that needs attention. Scannable in under ten seconds.
- **Media.** Download progress and library state, relevant only when I've actually requested something.
- **Compute.** VM/container health, relevant when debugging or doing maintenance.
- **Storage.** NAS capacity and backup status, relevant when something's filling up.

Each page answers one question. Splitting by *when I'd actually open it* turned out to matter more than splitting by topic.

## The container status widget needed its own aggregator too

Glance fetches one URL per widget, and I wanted container state across multiple Docker hosts in one view. Same pattern as the media stats problem: a small Flask service queries the Docker socket on each host, combines the results, returns one JSON response with status, uptime, and resource usage per container, grouped by host.

```json
{
  "hosts": [
    {"name": "docker-vm-media01", "containers": [
      {"name": "radarr", "status": "running", "cpu": "1.2%"}
    ]}
  ]
}
```

The template renders colored badges (green running, red stopped), and anything unhealthy is visually obvious without reading a single number. This aggregator-API-plus-template shape isn't built into Glance; you build the aggregation layer yourself every time you need data Glance can't natively combine. It's not elegant. It's the second time I've written essentially the same fifty lines of Flask this month, and it probably won't be the last.

## Grafana panels embed, with two settings flipped

Glance's `iframe` widget can point directly at a Grafana panel URL for genuine time-series visualization: disk trends, network throughput, anything that benefits from seeing a shape over time rather than a single number. That requires two things enabled on the Grafana side first:

```ini
[security]
allow_embedding = true

[auth.anonymous]
enabled = true
org_role = Viewer
```

Anonymous Viewer access sounds alarming out of context. In context (a dashboard that only exists on the internal network), the alternative is re-authenticating to see a panel on a page that's supposed to load instantly, which defeats the point of a dashboard. The iframe URL itself needs the right panel ID, theme, and org parameters, and getting those wrong just renders a blank box with no indication of what's missing. Expect some trial and error the first time.

## The calendar widget is the most fragile thing on the page, on purpose

Obsidian's Local REST API community plugin exposes vault content over HTTP. I fetch my daily note, parse scheduled events out of it, and render them on Home. This depends on Obsidian actually running, the plugin being configured, and my laptop being reachable over Tailscale: three independent points of failure for one widget.

It's worth building anyway, as long as the failure mode is graceful. The widget shows "unavailable" instead of breaking the page when any of those three things isn't true. A fragile integration you can see failing is fine. A fragile integration that takes the rest of the dashboard down with it is not.

## Configuration lives in Git, not in the app

The Glance YAML deploys through the same Ansible workflow as everything else: edit, commit, push, deploy. That makes experimenting with a new widget low-stakes: break something, `git log` shows exactly what changed, roll back.

The file itself is past 400 lines at this point. I've kept it as one file rather than splitting by page, mostly because Glance hot-reloads on save and one file is faster to grep through than five.

## What I'd do differently

Start with fewer widgets. The early version tried to display every metric I could reach, and the result was noise: too much to scan, nothing that stood out. Cutting widgets after the fact is harder than adding them, because you've already gotten used to each one being there. Start minimal, and only add a widget once you've actually caught yourself wanting that number and not having it.

---

*This is the twelfth post in a series about building and maintaining a homelab. Next: the monitoring stack, Prometheus, alert rules, and the specific thresholds that stopped my phone from buzzing constantly.*
