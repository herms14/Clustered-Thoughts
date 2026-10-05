---
title: 'My Accidental Journey Into Homelabbing: From Trip Photos to Full-Blown Infrastructure'
date: 2025-12-25 09:00:00 +0800
categories:
- Homelab
tags:
- networking
- origins
- proxmox
- synology
description: How a trip to Japan and the fear of losing cloud access led me to build a full homelab
excerpt: How a trip to Japan and the fear of losing cloud access led me to build a full homelab
cover: /assets/img/posts/homelab-cover.jpg
article_header:
  type: overlay
  theme: dark
  background_color: '#123'
  background_image:
    gradient: linear-gradient(135deg, rgba(0, 0, 0, .7), rgba(0, 0, 0, .45))
render_with_liquid: false
---

> This is the first post on Clustered Thoughts. It's mostly the backstory: how a phone full of Japan photos turned into a NAS, then a Raspberry Pi, then a Proxmox cluster with a VPN to Azure. The more technical posts come after this one.

It started with a trip to Japan in 2023. I took a ridiculous number of photos and videos, the way everyone does there. When I got home I started uploading them to Google Photos like I always did, and then got the usual message: you're out of storage, please pay for more.

That made me stop and think. If I kept paying every month to store my own memories, I'd eventually spend enough to buy a NAS anyway. And with a NAS, the photos would actually be mine, on hardware I control.

![A trip to Japan started it all](/Clustered-Thoughts/assets/img/posts/japan-trip.jpg)

Around the same time, Microsoft announced layoffs. I wasn't really worried about my job. What bothered me was how much I depended on access to the tools and cloud environments I used at work. If I left, all of that would be gone overnight. I wanted somewhere to keep learning that didn't depend on who I worked for.

So now I had two reasons. One was storing photos. The other was having my own technical playground where I could build things, break them, and rebuild them. Everything after that happened one "small upgrade" at a time.

## Picking a NAS

By December 2023 I was deep in NAS research. I wanted something closer to enterprise gear than a cheap consumer box, with room to grow so I wouldn't outgrow it in a year, and enough CPU to run more than file shares.

After a lot of spec sheets and more Reddit threads than I'd like to admit, I bought a **Synology DS923+**. The Plus line had the compute and flexibility I wanted, and I trusted it to last. Pretty much everything else in this post traces back to that purchase.

![Storage drives - the foundation of any homelab](/Clustered-Thoughts/assets/img/posts/hard-drives.jpg)

## The Raspberry Pi in the Drawer

Once the NAS was running, I started looking around for other things to improve. I remembered I had a Raspberry Pi sitting in a drawer, a hand-me-down from an officemate that I'd never used.

I put **Pi-hole and Unbound** on it to clean up DNS and speed up browsing a bit. It was supposed to be a tiny weekend project. It worked so well that I immediately wanted to do more.

![The humble beginnings of infrastructure tinkering](/Clustered-Thoughts/assets/img/posts/circuit-board.jpg)

## Self-Hosting My Media

With 10 TB of storage, the next idea was obvious. Why not host my own media and drop some streaming subscriptions? I started reading about the ARR stack, Docker, and media servers, and my mini PC slowly turned into a lab.

Streaming made the decision easy, honestly. Every service wanted its own subscription, prices kept going up, and shows disappeared without warning. If I was going to pay every month anyway, I'd rather put that money into something I own.

That's when it stopped being "a NAS" and became a homelab.

## Fixing the Network First

The ideas kept coming: Kubernetes, hybrid networking with Azure, separating IoT devices, seeing where traffic was going. None of it was going to work on my network at the time, which was a TP-Link mesh router and a cheap USB Wi-Fi dongle on my PC. No VLANs, no real routing, no visibility.

What I wanted was:

* IoT devices on their own segment
* Visibility into traffic
* A site-to-site VPN to Azure
* Reliable remote access
* One place to manage it all

It came down to **Ubiquiti UniFi** or **TP-Link Omada**. UniFi has the better reputation and UI, but it's hard to find in the Philippines, it's usually overpriced when you do, and shipping from Amazon can cost more than the gear. Omada did almost everything I needed, I could buy it locally, and it cost a lot less. So I went with Omada.

![Enterprise networking at home](/Clustered-Thoughts/assets/img/posts/network-cables.jpg)

## Building It Out

The base setup was an **ER605 gateway**, an **8-port managed switch**, and an **enterprise access point**. I also asked a colleague in the US to bring back a budget mini PC for me, so the NAS could stick to storage and the mini PC could run everything else.

For a while it was great. I set up VLANs and ACLs properly, and that's also when containers finally clicked for me, first Docker and then Docker Compose. The mini PC ended up running **Proxmox**, which turned out to be a really capable open-source hypervisor. I wrote about why I picked it over ESXi and Hyper-V in [Choosing Your Hypervisor](/Clustered-Thoughts/posts/choosing-your-hypervisor-why-proxmox-won/).

AI helped a lot here too. Even with my background, having ChatGPT and Claude Code to bounce ideas off made experimenting much faster. I go into that in [How AI Became My Infrastructure Co-Pilot](/Clustered-Thoughts/posts/how-ai-became-my-infrastructure-co-pilot/).

## The Mistake I Should Have Seen Coming

I ran the Omada controller as software on my NAS. Every time the NAS went down, even for a quick reboot, I lost management of my whole network.

Don't run your management plane on the same systems you're experimenting on. The funny part is that I used to warn enterprise customers about exactly this.
{:.warning}

I moved the controller onto its own hardware and the problem went away.

## Then It Kept Growing

I bought a second Minisforum mini PC and built a Proxmox cluster. I moved LXCs over to Docker containers, set up Kubernetes and a bunch of VMs, connected them to Azure Arc, and added a site-to-site VPN to Azure. Somewhere in there it stopped feeling like a hobby and started looking like a small company's infrastructure running in my house.

Security was next. If I was going to expose anything to the internet, port forwarding wasn't going to cut it. I wanted real inspection and proper control over what comes in and goes out, so I ordered a ProtectCLI firewall board and started redesigning the perimeter around zero-trust ideas. The bigger the setup gets, the more I care about limiting how far a single problem can spread.

## Version 2

Meanwhile the cables were getting out of hand. I'd started with a 3D-printed 10-inch rack from Printables.com, which was fine for a while. Once there was more expensive hardware in it, though, I wanted something sturdier, so I moved to a **DeskPi T2** rack with proper mounting, cable management, and airflow.

That's what I think of as version 2 of the homelab. It's tidy, and everything in it is there on purpose.

![The evolution from chaos to clean infrastructure](/Clustered-Thoughts/assets/img/posts/server-rack.jpg)

I'm now eyeing my old gaming PC and trying to decide what it becomes. Maybe a Plex transcoder, a backup NAS, or another Kubernetes node. I haven't decided.

## What I Want to Try Next: Local AI

Eventually I'd like to run LLMs locally. It would be a nice full circle, building something that cuts down on my ChatGPT and Claude subscriptions.

GPU and RAM prices are painful right now, so a dedicated AI machine is probably a year or two away. In the meantime I have a desktop with an **RTX 4080 Super**, and I want to see how far I can get running 70B models on it.

## What This Blog Is For

Mostly, it's my notes. I want a place to write down what I learn, what catches me off guard, and what blows up in my face, since those are usually the most useful lessons. I'm getting more into agentic AI and automation in the lab, so expect a fair amount of that too.

Roughly, here's what I'm planning to write about:

| Theme | Topics |
|---|---|
| **Origins** | How it started, and how AI became part of how I work |
| **Foundation** | Hypervisors, networking, Terraform, Ansible, documentation |
| **Containers** | Docker patterns, Traefik, Authentik, the media stack |
| **Observability** | Prometheus, Grafana dashboards, alerting |
| **Automation** | Discord bots, CI/CD pipelines, scheduled tasks |
| **Advanced topics** | Kubernetes, hybrid cloud with Azure Arc, zero-trust networking |
| **Lessons learned** | Mistakes, real costs, and what I'd do differently |

## Looking Back

None of this was planned. I wanted somewhere safe to keep my Japan photos and a place to keep learning, and every step after that was me fixing whatever the last step exposed.

If you're thinking about starting a homelab, I'd say start with whatever is actually bugging you. A full Google Photos account, a slow network, an old Pi in a drawer. You'll figure out the rest as you go. Version 2 of mine is done, and I'm already thinking about version 3.
