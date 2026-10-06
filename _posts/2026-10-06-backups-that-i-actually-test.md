---
title: Backups That I Actually Test
date: 2026-10-06 08:24:00 +0800
categories:
- Homelab
- Advanced Topics
tags:
- backup
- homelab
- pbs
- proxmox
- recovery
description: Eighteen VMs, six LXC containers, zero automated backups. I had Terraform configs and Ansible playbooks, which meant I could technically "rebuild everything" — but that confidence didn't survive the first real question...
excerpt: Eighteen VMs, six LXC containers, zero automated backups. I had Terraform configs and Ansible playbooks, which meant I could technically "rebuild everything" — but that confidence didn't survive the first real question...
render_with_liquid: false
---

Eighteen VMs, six LXC containers, zero automated backups. I had Terraform configs and Ansible playbooks, which meant I could technically "rebuild everything" — but that confidence didn't survive the first real question: what about the configs I'd tweaked by hand after the fact? The API keys sitting in environment files that never made it into a repo? Months of Prometheus metrics that no playbook was going to regenerate? Time to actually get serious about this.

## Why Proxmox Backup Server, specifically

| Option | Why not |
|---|---|
| Restic + NFS | Works, but manual integration, no web UI, nothing automated |
| Veeam | Real enterprise features, licensing complexity I had no appetite for |
| Manual Proxmox snapshots | Built in, but "manual" is the whole problem — they don't happen reliably if a human has to remember |
| **PBS** | Native Proxmox integration, one-click from the VE UI, incremental-forever, dedup, built-in verification |

The tradeoff is standing up a dedicated PBS instance — I run it as an LXC (CT100) on node03, at `192.168.20.50:8007`. Minimal resource overhead, full functionality, worth the extra container.

## Two datastores, split by how fast I need the data back

A 1TB NVMe (`daily`) handles daily backups where restore speed actually matters — if I need yesterday back, I need it back *now*. A 4TB HDD (`main`) handles weekly/monthly archives, where "slower but cheaper per GB" is the right trade for "when did that config actually break" scenarios.

Deduplication changes the storage math more than I expected going in: all eighteen VMs share the same base Ubuntu image, same packages, mostly the same configuration. After the first full backup cycle, 400GB of total VM disk compressed down to 85GB of actual stored data — a 4.7:1 ratio. That 4TB HDD is going to last years, not months, almost entirely because of chunk-level dedup rather than anything I configured deliberately.

Retention is split by how much I'd actually miss something: Traefik, Authentik, Grafana, and Glance get daily backups on the fast datastore, seven days retained. Everything else gets weekly backups on the HDD, four weekly plus two monthly. Fast restores for the things I'd notice breaking in minutes; reasonable storage for everything else.

## Testing restores is the part everyone skips

A backup you haven't restored from is hope wearing a backup's clothes — hope the job actually ran, hope the data isn't silently corrupted, hope the restore path even works end to end. I test monthly: pick a random VM, restore it to a throwaway VM ID, boot it, confirm it actually works, delete it.

```bash
qmrestore pbs-daily:backup/vm/107/2026-01-11T02:00:00Z 999 --storage local-lvm
qm start 999
# ...verify it boots and services respond...
qm stop 999 && qm destroy 999
```

Twenty minutes a month, and it's the only thing standing between "I have backups" and "I believe I have backups."

Restore times, for reference: a 20GB VM off the SSD datastore takes about 3 minutes; the same size off the HDD datastore, about 8; a single-file restore, roughly 30 seconds. Not instant, but nowhere near painful for a homelab.

## Reachable from my phone, same as everything else

PBS's web UI goes through Traefik with a Let's Encrypt cert, same pattern as every other internal service:

```yaml
http:
  routers:
    pbs:
      rule: Host(`pbs.hrmsmrflrii.xyz`)
      service: pbs
      tls:
        certResolver: letsencrypt
```

> One login gotcha that cost me a genuinely confused twenty minutes: enter just `root` in the username field, not `root@pam`. The realm dropdown appends `@pam` automatically — typing it yourself gives you a login that silently doesn't match what the dropdown already added.

## What deploying this actually taught me

- **LXC is the right call here, not a VM.** No reason PBS needs full-VM overhead for what it does.
- **Bind mounts beat NFS for the datastores.** Direct host mounts get native disk performance; NFS adds latency you'll feel on every restore.
- **A backup job that fails silently is worse than no backup job at all** — at least "no backup" doesn't lie to you. PBS status now feeds into Uptime Kuma, so a stalled job shows up the same way a down service would.

## What's still missing

Offsite replication. PBS supports syncing to a remote PBS instance, and I haven't set that up yet — which means if the house burns down, none of this local redundancy helps at all. Eventually that means a friend's PBS instance or cloud storage as a real second copy. For now, the genuinely critical stuff also lives in git repos and cloud services independently of PBS — not a complete answer, but not purely local either.

---

*This is the twenty-fifth post in a series about building and maintaining a homelab. The next post covers mistakes I made so you don't have to.*
