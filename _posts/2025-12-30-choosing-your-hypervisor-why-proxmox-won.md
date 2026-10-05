---
title: 'Choosing Your Hypervisor: Why Proxmox VE Won'
date: 2025-12-30 09:00:00 +0800
categories:
- Homelab
- Infrastructure
tags:
- esxi
- hyper-v
- hypervisor
- proxmox
- virtualization
description: Comparing Proxmox VE, VMware ESXi, and Hyper-V for homelab use, and why Proxmox ended up being my pick
excerpt: Comparing Proxmox VE, VMware ESXi, and Hyper-V for homelab use, and why Proxmox ended up being my pick
cover: /assets/img/posts/server-rack.jpg
article_header:
  type: overlay
  theme: dark
  background_color: '#123'
  background_image:
    gradient: linear-gradient(135deg, rgba(0, 0, 0, .7), rgba(0, 0, 0, .45))
render_with_liquid: false
---

> Short answer: I went with Proxmox VE because it's free, it runs fine on cheap hardware, and clustering, containers and an API all come in the box. My two-node cluster runs more than 18 VMs and LXC containers on a pair of mini PCs. The rest of this post is how I got there, and a few things I wish I'd known before setting it up.

At some point a single Docker host stopped being enough for me. I wanted clustering, automation, and a mix of VMs and containers, which meant I needed a proper hypervisor. I had worked with all three of the usual suspects in my day job, so I sat down and compared them for what a homelab actually needs.

These are my notes from that comparison, plus how the cluster looks today.

## The Three Options

I looked at the platforms you see most often in both enterprise and homelab setups:

* **Proxmox VE**: open source, Linux-based
* **VMware ESXi**: the enterprise standard
* **Microsoft Hyper-V**: the Windows option

Here's how they compared for my use case:

| Feature | Proxmox VE | VMware ESXi | Hyper-V |
|---------|-----------|-------------|---------|
| **Cost** | Free and open source | Free tier is limited; vSphere is costly | Needs Windows Server licensing |
| **Clustering** | Built in | Needs vCenter | Needs Failover Clustering |
| **Container support** | Native LXC | None | None (VMs only) |
| **Web interface** | Complete and responsive | Polished | Works, via Windows Admin Center |
| **Hardware support** | Broad, works on commodity gear | Strict HCL | Depends on Windows drivers |
| **Community** | Active and homelab-friendly | Enterprise-focused | Windows-focused |

## Why ESXi Didn't Make the Cut

ESXi was actually my first choice. It's the industry benchmark and I knew it well. It fell apart pretty quickly once I tried it on my own hardware, though.

**My NICs weren't supported.** My Minisforum mini PCs have Realtek network adapters, and ESXi doesn't support those out of the box. You can build a custom ISO with community drivers, but stability is hit or miss and updates tend to break it.

**The free tier is very limited.** You don't get vMotion, you don't get high availability, you don't get API access for automation, and VMs are capped at 8 vCPUs. Unlocking any of that means vCenter, which costs thousands of dollars a year. I couldn't justify that for a lab.

**Nobody knows where licensing is going.** Since Broadcom bought VMware, the licensing and product direction have been hard to predict. A lot of homelab people I follow have already moved off it.

## Why Hyper-V Fell Short

Hyper-V is technically solid. I just kept running into things that didn't fit.

Microsoft dropped the free Hyper-V Server, so today you need Windows Server. That leaves you buying licenses, rebuilding on 180-day evaluation copies, or sitting in a compliance gray area. I didn't want any of those for something I planned to run for years.

The other issue was more about feel. Most of my workloads are Linux, and managing them from a Windows-first platform felt awkward, even with PowerShell. I wanted my hypervisor to live in the same Linux world as everything running on it.

## Why Proxmox VE Won

Proxmox ticked every box, and I didn't hit any artificial limits along the way.

### It's Actually Free

Proxmox VE is fully open source. There's a paid subscription that gets you enterprise support and a more stable update channel, but it's optional. I run everything off the no-subscription repositories and haven't had problems.

### LXC Containers

This was the deciding factor for me. LXC containers start almost instantly, run at close to native speed, and barely use any memory. My Discord bots, for example, run happily in an LXC with 512 MB of RAM. In a VM I'd realistically give them at least 2 GB.

### Clustering Takes Minutes

No extra components, no separate management server:

```bash
# On the first node
pvecm create homelab-cluster

# On each additional node
pvecm add 192.168.20.20
```

Once the nodes join, you get live migration, shared storage, and high availability.

### A Web UI You Can Live In

The Proxmox web UI isn't pretty, but it does the job. Console access (noVNC and xterm.js), storage, backups, the firewall, and a view of the whole cluster are all there. I rarely need anything else for day-to-day work.

![Infrastructure that scales with your needs](/Clustered-Thoughts/assets/img/posts/network-cables.jpg)

### Everything Has an API

Anything you can do in the UI, you can do through the API. That's what makes Ansible and Terraform work cleanly against it, without hacks or unsupported workarounds.

## My Current Cluster

```
┌──────────────────────────────────────────────────────────────┐
│                     Proxmox VE Cluster                       │
│                      "homelab-cluster"                       │
├─────────────────────────────┬────────────────────────────────┤
│          node01             │            node02              │
│       192.168.20.20         │         192.168.20.21          │
├─────────────────────────────┼────────────────────────────────┤
│   VM Host (Infra & K8s)     │    Service Host (Apps)         │
│                             │                                │
│ - Ansible Controller        │ - Traefik (Reverse Proxy)      │
│ - K8s Controllers (3)       │ - Authentik (SSO)              │
│ - K8s Workers (6)           │ - GitLab + Runner              │
│                             │ - Docker Utilities VM          │
│                             │ - Docker Media VM              │
│                             │ - Immich (Photos)              │
│                             │ - Syslog Server                │
└─────────────────────────────┴────────────────────────────────┘
```

The split is simple. node01 handles infrastructure and Kubernetes (Ansible plus 9 K8s VMs), and node02 runs the applications (the Docker hosts and core services).

### Storage

| Storage | Type | Purpose |
|---------|------|---------|
| `local-lvm` | LVM-Thin | Fast local VM disks |
| `VMDisks` | NFS (Synology) | Shared storage for migration |
| `ISOs` | NFS | Installation media |
| `Backups` | NFS | Scheduled vzdump backups |

The Synology NAS provides shared storage to both nodes, which is what makes live migration and centralized backups possible.

### Cloud-Init Templates

Templates are where Proxmox really saves me time. My Ubuntu 24.04 templates come with the QEMU guest agent installed, my SSH keys in place, and cloud-init set up for networking and hostnames. A new VM takes about 30 seconds:

```bash
# Clone the template
qm clone 9000 150 --name new-service-vm

# Set networking
qm set 150 --ipconfig0 ip=192.168.40.50/24,gw=192.168.40.1

# Start it
qm start 150
```

Within a minute it's up, has an IP, and I can SSH in.

## Things I Wish I'd Known Earlier

**Keep management away from your experiments.** Critical things like network controllers shouldn't sit on hardware you're constantly rebooting. I learned this one personally: I ran the Omada controller on my NAS, and every time I rebooted the NAS for an experiment, I lost visibility of my whole network. I wrote more about that in [my origin story](/Clustered-Thoughts/posts/my-accidental-journey-into-homelabbing/).

**Turn on IOMMU from day one.** If there's any chance you'll want GPU passthrough later, enable IOMMU in the BIOS and kernel parameters now. Adding it later is a pain.

```bash
# Add to /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

**Separate storage traffic from cluster traffic.** In my setup, VLAN 20 carries cluster traffic and NFS goes over its own interfaces.

**Two nodes is fine to start with.** You don't need three. I actually went from three down to two and the cluster has been fine. Add nodes when you need the capacity.

## A Quick Post-Setup Checklist

Once it's running, I'd check that:

* All nodes show up in the web UI
* Live migration works between nodes
* Backups run on schedule
* Firewall rules are actually enforced
* The API responds (`pvesh get /nodes`)

## Wrapping Up

If you're picking a hypervisor for a homelab today, I think Proxmox is the easy recommendation, especially on mini PCs or anything with consumer network cards. ESXi and Hyper-V are both good products. They just come with licensing and hardware baggage that doesn't make sense at home.

Next, I want to write about network segmentation and how I've split my VLANs for management, services, IoT, and the stuff I'm still experimenting with.

## Resources

* [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
* [Proxmox No-Subscription Repository](https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo)
* [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
