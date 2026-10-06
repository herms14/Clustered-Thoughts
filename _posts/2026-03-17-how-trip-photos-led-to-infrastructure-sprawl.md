---
title: How Trip Photos Led to Infrastructure Sprawl
date: 2026-03-17 08:00:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- beginner
- homelab
- personal
description: I didn't plan any of this. A Synology NAS bought to back up trip photos turned into Docker, Plex, and eventually a three-node Proxmox cluster.
excerpt: I didn't plan any of this. A Synology NAS bought to back up trip photos turned into Docker, Plex, and eventually a three-node Proxmox cluster.
render_with_liquid: false
---

I didn't plan any of this.

The Synology NAS was supposed to solve one problem: thousands of trip photos from the Philippines (Boracay, mostly) scattered across hard drives with no real backup. A friend suggested a NAS. So I bought one, set it up, and felt briefly accomplished.

Then I found out it could run Docker, more or less by accident, one of those "install this package?" prompts in DSM. Within a week I had Plex running, serving video to the living room TV. That felt like magic at the time.

Then Plex kept buffering, because the NAS's own CPU couldn't keep up with transcoding. The fix people recommended was offloading that work to a dedicated machine, so I bought a Minisforum mini PC. Small, quiet, one job: transcode video. That was the whole plan.

That machine sat idle more than it transcoded. I started reading about Proxmox while waiting for things to buffer, installed it on the mini PC, and within a couple of months had a second one specifically so I could cluster them (three-node quorum, because two nodes without a tiebreaker is apparently not actually clustering). Then the network couldn't handle traffic cleanly across everything I was now running, so I bought managed switches. Then VLANs, because "everything on one subnet" stopped being fine the moment I had more than four things talking to each other. Then Terraform, because clicking through the Proxmox UI to create yet another VM had stopped being tolerable.

You see where this goes.

---

What I didn't expect was how much I'd learn, and how little of it came from tutorials. The real learning happened at 2 AM, debugging something that had to be fixed before work. I once burned three hours on DNS because I'd pointed an internal domain at the wrong interface. It resolved correctly about 80% of the time, which is a uniquely infuriating failure mode, since "it works" and "it's broken" look identical until you've retried four times.

There's a specific kind of frustration that comes from a system you built yourself: when it breaks, there's no one else to blame. There's also a specific kind of satisfaction in knowing exactly which log to check, because you're the one who wrote the thing that's failing.

---

The current setup, as of this writing, is a three-node Proxmox cluster I call MorpheusCluster, two Minisforum boxes and a repurposed desktop running a Ryzen 9 5900XT that does the heavier lifting (Immich, GitLab). Eleven LXC containers handle most of the lightweight services; five VMs cover the rest. Seven VLANs split infrastructure from production services from IoT from guest WiFi, with a dedicated management VLAN for the switches themselves. I ran a Kubernetes cluster on it for a while, purely to learn (nine VMs, three control-plane and six workers), and decommissioned the whole thing once I'd learned what I came for and it was just burning RAM. I also ran a hybrid Azure lab for a few months to learn Fabric and hybrid identity, and retired that too, for the same reason: once the learning plateaus, the resource cost stops being worth it.

That NAS still holds the trip photos. It's the seed everything else grew out of, and at this point it's almost historical. I'll scroll past old Boracay photos and remember that all I originally wanted was redundant storage.

I have something close to a rack now. Not a full one. Close enough that the distinction feels academic.

---

Homelabs aren't really about the hardware. They're about curiosity that has consequences you actually feel. When something breaks here, media stops playing, a dashboard goes dark, someone in the house asks why the internet is slow. That feedback loop teaches faster than documentation does, because documentation doesn't page you at 11 PM.

I wouldn't say this has a destination. Services get decommissioned once the learning's done (Kubernetes and the Azure lab are proof I actually mean that, not just something I say), and new ones replace them. There's always another integration to build, another way to break something I built two months ago.

If you're wondering whether to start (a NAS, a single VM, one container), the answer is probably yes. Not because you'll end up with a cluster. Because you'll end up understanding something about how systems actually fail, which you can't get any other way.

I thought I was solving a photo storage problem. I was learning how to think about systems. The photos are still backed up, for what it's worth. That part worked.

---

*This is the first post in a series about building and maintaining a homelab. The next post covers how an AI assistant ended up knowing my network topology better than I do.*
