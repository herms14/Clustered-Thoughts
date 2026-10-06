---
title: LXC and the Art of Not Wasting RAM
date: 2026-10-06 08:20:00 +0800
categories:
- Homelab
- Infrastructure Deep Dives
tags:
- containers
- homelab
- lxc
- proxmox
description: 'I tried to spin up a Kubernetes cluster for learning and Proxmox refused — insufficient memory. Checking my allocations explained why: 32GB allocated against a 28GB node. Nothing was actually using that much; it was all...'
excerpt: 'I tried to spin up a Kubernetes cluster for learning and Proxmox refused — insufficient memory. Checking my allocations explained why: 32GB allocated against a 28GB node. Nothing was actually using that much; it was all...'
render_with_liquid: false
---

I tried to spin up a Kubernetes cluster for learning and Proxmox refused — insufficient memory. Checking my allocations explained why: 32GB allocated against a 28GB node. Nothing was actually using that much; it was all paper commitment. Traefik's VM alone had 8GB reserved for a service using maybe 200MB of actual RAM — a single Go binary.

That's the VM tax, and it was quietly eating all my headroom.

## Where the overhead actually comes from

Every VM carries weight that has nothing to do with the workload running inside it: a full kernel (even minimal Ubuntu wants ~500MB just for that), system services you never touch, reserved memory for emulated hardware, and a duplicate copy of `apt`/`bash`/`coreutils` per VM. For a reverse proxy, that's a three-bedroom apartment for a hamster.

LXC is the middle ground: containers share the host kernel, each gets its own filesystem/network/process tree, and the overhead mostly disappears — boot times drop from ~30 seconds to ~2. The tradeoff is isolation. A VM is its own machine; an LXC container is a namespaced chroot with better manners. For services that don't need hardware-level isolation — which, in practice, is most of what I run — that trade is an easy yes.

## The actual migration

Plan: move three services off VMs and onto LXC, reclaim ~20GB.

| Service | Before (VM) | After (LXC) |
|---|---|---|
| Traefik (CT203, `192.168.40.20`) | 8GB | 2GB |
| Authentik (CT204, `192.168.40.21`) | 8GB | 4GB (Postgres + Redis still need room) |
| docker-media, 14 containers (CT205, `192.168.40.11`) | 18GB | 8GB — still generous, no longer absurd |

Blue-green made this safe: stand up the LXCs on temporary IPs, copy data while the VMs kept running, test thoroughly, then do the cutover — stop the VMs, reassign the production IPs to the LXCs, restart. DNS and Traefik's own routes never had to change, since the services came back up on the exact same IPs. If anything had gone wrong, restarting the VMs would have put me back exactly where I started.

```bash
pct create 203 local:vztmpl/ubuntu-24.04-standard.tar.zst \
  --hostname traefik-lxc \
  --cores 2 \
  --memory 2048 \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 0
```

`nesting=1` is what lets Docker run containers inside the container at all. `--unprivileged 0` (privileged mode) is what makes Docker actually work reliably once it's running — more on why below.

> There's real community discourse against ever running privileged LXCs. For a homelab where Proxmox itself is already the isolation boundary from physical hardware, I think that's the wrong risk model to import wholesale — a privileged LXC here is a pragmatic trade, not a production security posture. Your mileage (and threat model) may vary.

## AppArmor was the first real wall

Docker inside the LXC tried to start a container and failed with an opaque `apparmor_parser` error. The fix:

```yaml
services:
  traefik:
    security_opt:
      - apparmor=unconfined
```

The reasoning: the Proxmox host is already providing isolation. Asking Docker to *also* enforce AppArmor inside an LXC just creates two overlapping enforcement layers that step on each other. Every service in these LXCs gets this option now — it's boilerplate I add without thinking about it.

> This fixed the symptom I hit in January. It's worth saying plainly that AppArmor-in-LXC is not a fully solved problem for me — I've since heard from other LXC hosts in this cluster that similar Docker container-creation failures can resurface in a different shape even with this flag set, tied to capabilities an unprivileged LXC drops by default rather than AppArmor specifically. If you hit a `docker run` failure that `apparmor=unconfined` doesn't fix, the capability is the next thing to check, not a sign this flag didn't work.

## NFS without NFS awareness

The media LXC (CT205) needs the Synology NAS share where the actual media files live. Two options: mount NFS directly inside the container, or bind-mount a share the Proxmox host already has mounted. I went with the bind mount — the host already has the NFS share live, so passing it through is one less thing that can break inside the container:

```bash
# in /etc/pve/lxc/205.conf
mp0: /mnt/pve/Proxmox-Media,mp=/mnt/media
```

The container just sees `/mnt/media` as a local path. Docker containers inside mount that like any other local directory — no NFS client config, no NFS awareness, at the container level at all.

## The cutover, and the numbers after

Stopping the three VMs, reassigning IPs to the LXCs, and restarting took under a minute end to end — the kind of changeover that's scarier to plan than to execute. Boot times after: Traefik's LXC comes up in ~3 seconds versus ~45 for the VM it replaced; Authentik in ~8 seconds versus ~60. That difference changes how casually I'll restart something — a VM restart was a "do I have five minutes" decision, an LXC restart isn't.

Memory allocation across the affected nodes dropped from 62GB to 42GB. The 20GB I got back was exactly enough for the Kubernetes cluster that started this whole investigation.

## What I'd tell myself before doing this again

- **Don't build Docker images inside an LXC.** AppArmor restrictions during the `RUN` phase of a build cause hangs and unhelpful errors far more often than runtime does. Pull pre-built images and mount code as a volume instead; build custom images somewhere else (a VM, or CI).
- **LXC root filesystems have to be local storage.** You cannot put an LXC's rootfs on NFS — it'll refuse outright. This genuinely surprised me since it's a non-issue for VMs.
- **Blue-green is worth the extra setup every time.** Being able to fully test the new thing before committing, with an instant rollback sitting right there, is what made this feel like a non-event instead of a maintenance window.

And where I still reach for a VM instead: anything needing a kernel version the Proxmox host doesn't have, GPU passthrough, Windows (obviously), and databases where I actually want the harder isolation boundary. Everything else — web apps, reverse proxies, media servers, monitoring — LXC wins on resource efficiency without costing me anything I actually needed.

---

*This is the twenty-first post in a series about building and maintaining a homelab. The next post covers Kubernetes at home — and whether, after all this LXC enthusiasm, I still think it's worth running.*
