---
title: "Choosing Your Hypervisor: Why Proxmox VE Won"
description: "Comparing Proxmox VE, VMware ESXi, and Hyper-V for homelab use - and why Proxmox emerged as the winner"
date: 2025-12-30
slug: choosing-your-hypervisor-why-proxmox-won
categories:
    - Homelab
    - Infrastructure
tags:
    - proxmox
    - virtualization
    - hypervisor
    - esxi
    - hyper-v
cover:
    image: /images/server-rack.jpg
    alt: "Server infrastructure"
    caption: "Choosing the right hypervisor is foundational"
    relative: false
---

Proxmox VE emerged as the best hypervisor for my homelab because it is free, enterprise-capable, hardware-agnostic, and operationally efficient. Compared to ESXi and Hyper-V, it delivers clustering, containers, and automation without licensing friction. My current two-node Proxmox cluster runs more than 18 virtual machines and LXC containers reliably on commodity hardware.

---

## The Evaluation Criteria

When I outgrew a single-server Docker setup, I needed a real hypervisor platform that could support clustering, automation, and mixed workloads. I evaluated three options commonly used in both enterprise and homelab environments:

- **Proxmox VE** - Open-source, Linux-based
- **VMware ESXi** - Enterprise standard
- **Microsoft Hyper-V** - Windows ecosystem

The comparison below summarizes how each platform stacked up for my use case.

| Feature | Proxmox VE | VMware ESXi | Hyper-V |
|---------|-----------|-------------|---------|
| **Cost** | Free and open source | Free tier is limited; vSphere is costly | Requires Windows Server licensing |
| **Clustering** | Built-in | Requires vCenter | Requires Failover Clustering |
| **Container Support** | Native LXC | None | None (VM-only) |
| **Web Interface** | Feature-complete and responsive | Polished | Functional via Windows Admin Center |
| **Hardware Support** | Broad, commodity-friendly | Strict HCL | Dependent on Windows drivers |
| **Community** | Active and homelab-friendly | Enterprise-centric | Windows-focused |

---

## Why ESXi Didn't Make the Cut

VMware ESXi is the industry benchmark for virtualization, and it was my initial preference. In practice, several constraints made it unsuitable for my environment.

### Hardware Compatibility Friction

My Minisforum mini PCs use Realtek NICs. ESXi does not support these adapters natively, which means relying on custom ISOs with community drivers. Even then, stability is inconsistent, and updates frequently break compatibility.

### Free Tier Limitations

The free ESXi license significantly restricts functionality:

- No live migration (vMotion)
- No high availability
- No API access for automation
- A limit of eight vCPUs per VM

To unlock these features, vCenter is required, which introduces recurring costs measured in thousands of dollars per year. For a homelab, that trade-off is difficult to justify.

### Licensing Uncertainty Post-Acquisition

Following Broadcom's acquisition of VMware, licensing models and product direction have become less predictable. Many homelab users are already migrating away in anticipation of further restrictions.

---

## Why Hyper-V Fell Short

Hyper-V is technically solid, but it carries structural limitations that didn't align with my goals.

### Licensing Constraints

Microsoft discontinued the free Hyper-V Server. Today, running Hyper-V requires Windows Server, which introduces one of the following compromises:

- Purchasing licenses
- Relying on 180-day evaluation editions
- Operating in a gray area of compliance

None of these are ideal for a long-term lab.

### Windows-Centric Operational Model

While PowerShell is powerful, managing Linux-heavy workloads from a Windows-first platform felt unnatural. I wanted my hypervisor to align with Linux tooling, workflows, and conventions end-to-end.

---

## Why Proxmox VE Won

Proxmox VE met every requirement with minimal friction and no artificial constraints.

### Open Source and Truly Free

Proxmox VE is fully open source. The paid subscription provides enterprise support and access to a stabilized update channel, but it is optional. I run production workloads using the no-subscription repositories without issues.

### Native LXC Container Support

LXC containers were the decisive factor. They provide:

- Near-native performance
- Extremely fast startup times
- Minimal memory overhead
- An ideal balance between isolation and efficiency

For example, my Discord bots run comfortably in an LXC container using 512 MB of RAM. The same workload inside a VM would realistically require at least 2 GB.

### Simple, Built-In Clustering

Creating a cluster takes minutes and requires no external components:

```bash
# On the first node
pvecm create homelab-cluster

# On additional nodes
pvecm add 192.168.20.20
```

Once joined, live migration, shared storage, and high availability are immediately available.

### A Web Interface That Scales

The Proxmox web UI is practical rather than decorative. It provides:

- Real-time console access via noVNC and xterm.js
- Integrated storage and backup management
- Firewall configuration
- Clear cluster visualization

Everything needed for daily operations is accessible without third-party tools.

![Infrastructure that scales with your needs](/images/network-cables.jpg)

### Full API Coverage

Every action exposed in the UI is also available via API. This makes automation with Ansible or Terraform straightforward and predictable, without workarounds or unsupported hacks.

---

## Current Cluster Architecture

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

### Node Responsibilities

| Node | Purpose | Workloads |
|------|---------|-----------|
| **node01** | Infrastructure & Kubernetes | Ansible, 9 K8s VMs |
| **node02** | Services & Applications | Docker hosts, core services |

This two-node architecture provides clear separation: infrastructure automation and Kubernetes on node01, application workloads on node02.

---

## Storage Design

| Storage | Type | Purpose |
|---------|------|---------|
| `local-lvm` | LVM-Thin | High-performance VM disks |
| `VMDisks` | NFS (Synology) | Shared storage for migration |
| `ISOs` | NFS | Installation media |
| `Backups` | NFS | Automated vzdump backups |

The Synology NAS provides shared storage accessible from both nodes, enabling live migration and centralized backups.

---

## Cloud-Init and Templates

Templates are where Proxmox becomes a force multiplier. My Ubuntu 24.04 templates include:

- QEMU guest agent pre-installed
- Preconfigured SSH keys
- Cloud-init for dynamic networking and hostnames

Provisioning a new VM takes roughly 30 seconds:

```bash
# Clone template
qm clone 9000 150 --name new-service-vm

# Configure networking
qm set 150 --ipconfig0 ip=192.168.40.50/24,gw=192.168.40.1

# Start the VM
qm start 150
```

Within a minute, the VM is running, has an IP address, and is accessible via SSH.

---

## Lessons Learned

### Separate Management From Experimentation

Running critical services (like network controllers) on experimental infrastructure introduces unnecessary risk. Management components should be isolated and boring by design.

> **My mistake**: I initially ran the Omada network controller on my NAS. Every time I rebooted for experiments, I lost network management visibility.

### Plan for IOMMU Early

If GPU passthrough is even a remote possibility, enable IOMMU in BIOS and kernel parameters from day one. Retrofitting it later is painful.

```bash
# Add to /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

### Isolate Storage Traffic

Cluster communication and storage traffic should not share the same network. In my setup, VLAN 20 handles cluster traffic, while NFS uses dedicated interfaces.

### Start with Two Nodes

A two-node cluster is perfectly viable for a homelab. You don't need three nodes to start - I scaled down from three to two and the cluster runs fine. Add nodes when you need the capacity.

---

## Post-Setup Validation

After deployment, verify the following:

- All nodes appear in the web UI
- Live migration succeeds between nodes
- Backups run on schedule
- Firewall rules are enforced
- API access works (`pvesh get /nodes`)

---

## What's Next

The next post will cover **network segmentation**, focusing on VLAN design to isolate management, services, IoT devices, and experimental workloads.

---

## Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Proxmox No-Subscription Repository](https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo)
- [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)

---

*This post is part of the Homelab Blog Series.*
