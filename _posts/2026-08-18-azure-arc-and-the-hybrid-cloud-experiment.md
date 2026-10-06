---
title: Azure Arc and the Hybrid Cloud Experiment
date: 2026-08-18 08:00:00 +0800
categories:
- Homelab
- Advanced Topics
tags:
- azure
- cloud
- homelab
- hybrid
description: 'The homelab runs entirely on-premises; my day job runs on Azure. Azure Arc is the bridge between those two facts: it onboards on-prem resources into Azure''s management plane without actually moving them anywhere. A VM...'
excerpt: 'The homelab runs entirely on-premises; my day job runs on Azure. Azure Arc is the bridge between those two facts: it onboards on-prem resources into Azure''s management plane without actually moving them anywhere. A VM...'
render_with_liquid: false
---

The homelab runs entirely on-premises; my day job runs on Azure. Azure Arc is the bridge between those two facts: it onboards on-prem resources into Azure's management plane without actually moving them anywhere. A VM in Proxmox shows up in the same Azure portal as a VM that's actually running in Azure, gets the same policies applied, and reports to the same Log Analytics workspace. The line between "on-prem" and "cloud" gets blurrier than I expected, in a genuinely useful way.

## The pieces

- A **site-to-site VPN** (OPNsense on my side, Azure VPN Gateway on theirs) gives reliable connectivity without exposing anything to the open internet.
- **Azure Arc agents** on each on-prem VM open an *outbound* connection to Azure, so the machine can be managed without any inbound firewall rule ever needing to exist. It just shows up in the portal as an Arc-enabled server.
- **Microsoft Sentinel** (the renamed Azure Sentinel) aggregates logs from everywhere (Arc servers, actual Azure VMs, network devices), giving me SIEM functionality without running my own log pipeline.

Onboarding a machine is a two-step affair: generate the onboarding script in the Azure portal, run it on the target.

```bash
curl -O https://aka.ms/azcmagent-linux
chmod +x azcmagent-linux
./azcmagent-linux connect \
  --resource-group rg-homelab \
  --tenant-id <tenant-id> \
  --subscription-id <subscription-id>
```

Within a few minutes the machine is visible in Azure: inventory, policy evaluation, log queries, all of it. Because the agent's connection is outbound-only, this works through almost any firewall as long as outbound HTTPS isn't blocked, which is the detail that actually makes it practical for a home network.

## What I actually get out of it

| Capability | What it does for me |
|---|---|
| Centralized monitoring | Azure Monitor Agent ships logs/metrics to one Log Analytics workspace, I query on-prem and cloud machines from the same place |
| Policy enforcement | Azure Policy audits config drift across machines automatically, instead of me manually checking each one |
| Security posture | Microsoft Defender for Cloud scores Arc-enabled machines against the same benchmarks as cloud resources |

The Sentinel piece specifically replaces what would otherwise be a DIY SIEM: syslog forwarders ship logs from my Linux boxes to a collector, the collector ships to Sentinel, and analytics rules flag the suspicious patterns. I don't maintain any Elasticsearch-shaped infrastructure to make that work. Cost is consumption-based and my homelab's actual log volume (a couple GB a day) keeps the bill low enough to ignore.

> The outbound-only connection model is the whole trick here, and it's worth internalizing if you're coming from a "cloud resources need inbound access" mental model. Nothing about Arc requires punching a hole in my firewall. The agent dials out, and Azure does everything else through that one connection.

## What this actually changes

A VM in Proxmox no longer has to be *purely* on-premises in any meaningful management sense. It can participate in Azure monitoring and policy while the compute stays exactly where it is. That's the actual shape of hybrid cloud in enterprise environments: workloads sit wherever makes sense (on-prem for latency, cloud for burst, edge for specific constraints), while management stays consistent regardless of where the thing actually runs. Having that pattern running in miniature at home made it click in a way reading about it never did.

## The real limitations

- **The VPN adds latency.** Fine for management operations; noticeable the moment you try anything high-frequency across the tunnel.
- **Integration is partial, not universal.** Some Azure services quietly assume the resource actually lives in Azure, and Arc-enabled machines get partial support on those.
- **Cost isn't zero, even if it's small.** Log Analytics bills per GB ingested, Sentinel adds its own per-GB analytics cost. At homelab log volumes this rounds to pocket change, but it's a line I'd actually watch if I ever scaled logging up.

## Why this was worth the VPN setup

Hybrid cloud isn't a niche pattern. It's close to the default in enterprise environments, and understanding how Arc actually works (the VPN, the outbound-agent model, policy spanning both sides of the boundary) transfers directly to problems I run into at work. The homelab became a working miniature of the thing I was trying to understand conceptually, and that turned out to matter more than any tutorial would have.

---

*This is the twenty-third post in a series about building and maintaining a homelab. The next post covers zero-trust networking with Tailscale.*
