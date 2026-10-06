---
title: Why Proxmox Won (And What I Gave Up)
date: 2026-10-06 08:02:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- homelab
- hypervisor
- proxmox
- virtualization
description: I started with ESXi. That's what serious people used, or so I'd absorbed from enough forum threads to believe it uncritically.
excerpt: I started with ESXi. That's what serious people used, or so I'd absorbed from enough forum threads to believe it uncritically.
render_with_liquid: false
---

I started with ESXi. That's what serious people used, or so I'd absorbed from enough forum threads to believe it uncritically.

Then I spent two days trying to get a Realtek NIC recognized with a custom ISO, and reconsidered my priorities.

---

The problem with ESXi in a homelab isn't capability, it's friction. VMware maintains a strict hardware compatibility list, and consumer mini-PC hardware isn't on it. My boxes have Realtek network adapters; ESXi ships no drivers for them. You can inject community-maintained drivers into a custom image — I did — and it works, until an update wipes the network stack and you're rebuilding the image on an afternoon you didn't budget for that.

The free tier compounds it: no vMotion, no live migration, no API access for automation, an 8-vCPU-per-VM ceiling that rarely bites in practice but still reads as "you're being nudged toward a purchase." After the Broadcom acquisition, licensing got less predictable on top of that. I didn't want infrastructure sitting on rules that might change under me.

Hyper-V was the other obvious option — I'd used it professionally, the tooling's fine, PowerShell makes sense once you accept the verbosity. But Microsoft discontinued the free standalone Hyper-V Server, and what's left needs Windows Server licensing I didn't want to depend on for something meant to run indefinitely. There's also a simpler mismatch: my workloads are almost entirely Linux, and running a Windows hypervisor under Linux guests works, but nothing about the tooling ever quite feels native.

---

Proxmox won by being the practical choice rather than the exciting one.

It's free in the way that actually means free — the paid subscription unlocks enterprise repos and support, the no-subscription repo is fully functional for everything I run. Built on Debian, so hardware support is just "whatever Debian supports," and my Realtek NICs worked without a custom image. Clustering was two commands: create on the first node, join from the rest. No external controller, no separate license tier gating it off.

And then there's LXC, which turned out to be the actual deciding factor, and I almost didn't weigh it properly going in.

---

LXC containers aren't Docker containers — they're full Linux systems sharing the host kernel, with their own filesystem and network namespace, starting in roughly the time it takes to type the start command. My current cluster runs eleven of them: a dashboard, a reverse proxy, SSO, DNS, home automation, the media stack, a Discord bot host, and a few others — most sized at 1-2 cores and 1-4GB RAM depending on what they're actually doing. The equivalent set of minimal VMs would eat several times that just in OS overhead before any workload runs.

The tradeoff is isolation: VMs get hardware-level separation, LXC containers share a kernel. For a homelab where I control every workload, that tradeoff is fine. I wouldn't run anything multi-tenant this way. But for a reverse proxy or a dashboard or a DNS resolver, the isolation I'm giving up isn't isolation I actually needed.

The one real caveat, and I found this out the hard way: unprivileged LXCs drop a kernel capability (`CAP_MAC_ADMIN`) that Docker's nesting mode wants. Two of my Docker-in-LXC hosts started failing to *create* new containers — not run existing ones, just create — with an AppArmor permission error that took real digging to trace back to that dropped capability rather than the AppArmor profile itself. Existing containers kept working; only fresh `docker run` calls broke. It's still an open, unresolved tradeoff on my task list: go privileged (less secure) or retain the specific capability (more surgical, more fragile). I haven't picked yet.

---

What I gave up is ecosystem. VMware has decades of enterprise tooling, certifications, job listings that name vSphere specifically. Proxmox skills don't translate to a resume line the way vSphere does. I've accepted that this homelab serves curiosity more than career signaling, and that tradeoff is fine for me specifically — it might not be for you.

---

Current layout: node01 is the workhorse — all eleven LXCs, the Docker-based media/utilities stack, and it doubles as the Tailscale subnet router for remote access. Node02 runs a single GitLab CI/CD runner VM. Node03 is the repurposed desktop, a Ryzen 9 5900XT, running Immich and the GitLab server itself — the two workloads that actually want the extra cores.

That's not the layout I started with. I ran a nine-VM Kubernetes cluster on this same hardware for a few months, purely to learn it, and decommissioned every node once the learning curve flattened out — those IPs are sitting free now. I also ran an Azure Hybrid Lab for Fabric and hybrid identity work, same story: learned what I wanted, tore it down. The architecture isn't static. It's distribute-by-purpose, keep the heavy stuff where the cores are, and retire anything whose job was "teach me X" once X is actually learned.

Backups run to a dedicated Proxmox Backup Server. If a node dies, I restore from PBS or migrate the workload elsewhere. Not enterprise HA, but resilient enough that I sleep fine. All of it cost zero dollars in licensing.

---

If I started over, same choice. Proxmox has rough edges — a subscription nag on login that never goes away, a storage model with a real learning curve — but it does what I need without an artificial ceiling I have to negotiate around.

---

*This is the third post in a series about building and maintaining a homelab. The next post covers network segmentation, and the VLAN mistakes that taught me more than the VLANs themselves did.*
