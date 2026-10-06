---
title: Flat Networks and the Lessons They Teach
date: 2026-10-06 08:03:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- homelab
- networking
- security
- vlans
description: When I started, everything lived on one network — Proxmox nodes, Docker containers, smart-home gadgets, my own workstation, all on the same /24. It worked fine, until the day it didn't.
excerpt: When I started, everything lived on one network — Proxmox nodes, Docker containers, smart-home gadgets, my own workstation, all on the same /24. It worked fine, until the day it didn't.
render_with_liquid: false
---

When I started, everything lived on one network — Proxmox nodes, Docker containers, smart-home gadgets, my own workstation, all on the same /24. It worked fine, until the day it didn't.

Flat networks don't fail catastrophically. They fail in ways that are hard to debug and harder to contain, because when everything can talk to everything, there are no natural boundaries to reason about. A misconfigured device can scan the whole network. You learn this the uncomfortable way, which is the only way I seem to learn things.

---

I didn't understand VLANs intuitively. The concept is simple — tag traffic so switches know which logical network it belongs to — but the practical implications took longer to land.

The mental model that actually helped: VLANs are rooms in a building. Everyone in a room hears each other fine. To reach another room you go through a doorway, and there's a guard at that doorway deciding what's allowed through.

My actual layout, seven VLANs plus a dedicated firewall segment:

| VLAN | Name | Subnet | Purpose |
|------|------|--------|---------|
| 10 | Internal | 192.168.10.0/24 | Main LAN, workstations |
| 20 | Homelab | 192.168.20.0/24 | Proxmox nodes, automation hosts |
| 30 | IoT | 192.168.30.0/24 | Smart-home devices |
| 40 | Production | 192.168.40.0/24 | Docker services, user-facing apps |
| 50 | Guest | 192.168.50.0/24 | Guest WiFi |
| 60 | Sonos | 192.168.60.0/24 | Speakers — they needed their own segment for multicast, not security |
| 90 | Management | 192.168.90.0/24 | Switches, APs, Pi-hole |
| 91 | Firewall | 192.168.91.0/24 | OPNsense |

The principle: infrastructure is sacred, production services are semi-trusted, IoT is untrusted, management interfaces are reachable from basically nowhere except my own workstation.

---

Getting this working took more than switch configuration. Proxmox needed VLAN-aware bridges. The firewall needed explicit rules for what could cross each boundary. The first time I touched those rules, I locked myself out — tightened a rule that happened to block the VLAN I was connected through, and had to walk to the physical switch to recover via console.

> Always have an out-of-band path to your own management plane before you start writing deny rules. I keep one admin device with a standing bypass rule specifically so a bad ACL edit doesn't turn into a trip to the server closet. It's cost me exactly the convenience you'd expect, and saved me more than that back.

---

The firewall policy is deny-by-default, exceptions carved out explicitly. Production services reach the internet but not other internal VLANs directly — except specific ports where there's a real reason, like metrics scraping into the homelab VLAN. IoT reaches the internet for whatever cloud dependency it has and nothing else internal; those devices have no reason to see the NAS, and I'd rather not find out what happens if one tries. Every VLAN gets DNS, because nothing works without it and that's the one rule I don't make exceptions to.

The overhead is real — every new service means deciding which VLAN it belongs on, every integration between services means checking whether the traffic is actually allowed to flow, and I've broken things more than once by forgetting a rule. But troubleshooting got easier, not harder, once the model was explicit: if something can't connect, the first question is "should it be allowed to," and the firewall logs answer that directly instead of leaving me to guess.

---

The network gear is TP-Link Omada — switches, access points, a cloud controller. I picked it mostly for local availability and price over UniFi; the software is a little less polished but it's never been the bottleneck.

OPNsense is still a work in progress, honestly, not a finished story. It's meant to take over as primary DNS resolver from Pi-hole, with Pi-hole staying on as secondary. The bring-up has taken longer than I expected — a fresh install that only had a WAN interface auto-assigned and no LAN, a leftover DHCP client process silently overriding the static IP I'd set on every renewal, and as of the most recent session, it's still not reliably reachable cross-VLAN from my own workstation even after fixing the routing and firewall rules I thought were the problem. Pi-hole is still doing the actual DNS work today. I'm leaving this paragraph honest rather than aspirational, because the aspirational version of this post would have shipped months ago and OPNsense still wouldn't be done.

---

Looking back, I probably overcomplicated this for a homelab — a simpler two-VLAN split would have covered most of the actual security concerns with a fraction of the ongoing overhead. But the learning transferred. VLANs, firewall rule evaluation order, network boundaries — I've used this understanding professionally, not just at home.

If you're starting from zero: begin with two or three VLANs, not eight. Add complexity when you understand specifically why you need it, not because a guide told you seven is the right number.

---

*This is the fourth post in a series about building and maintaining a homelab. The next post covers Infrastructure as Code with Terraform — and the local state file I still haven't gotten around to making less fragile.*
