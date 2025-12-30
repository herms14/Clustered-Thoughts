---
title: "My Accidental Journey Into Homelabbing: From Trip Photos to Full-Blown Infrastructure"
description: "How a trip to Japan and the fear of losing cloud access led me to build a full homelab ecosystem"
date: 2025-12-25
slug: my-accidental-journey-into-homelabbing
categories:
    - Homelab
tags:
    - origins
    - synology
    - proxmox
    - networking
cover:
    image: /Clustered-Thoughts/images/homelab-cover.jpg
    alt: "Server rack with glowing lights"
    caption: "What started as photo storage became this"
---

It all started from a trip to Japan back in 2023. I took a ridiculous amount of videos and photos, tiny slices of memory I wanted to keep forever while exploring that wonderful country. When I got home and started sorting through everything, it hit me just how important these moments were. Naturally, I uploaded them to Google Photos like I always did, until I got that familiar notification that I was out of space and needed to pay for more. That made me pause. If I kept paying every month just to store my own memories, I would eventually spend enough to buy a NAS anyway, and I would also gain something the cloud could never give me: real privacy and full control over my data.

![A trip to Japan started it all](/Clustered-Thoughts/images/japan-trip.jpg)

Around that same time, Microsoft announced layoffs. I was not scared of losing my job because I trusted my skills, but I was scared of losing access to the technologies I worked with every day. All the tools, platforms, and cloud environments I relied on could disappear overnight if I no longer worked there. I realized how much I had taken that access for granted. I wanted a way to continue learning and experimenting regardless of which cloud provider I worked for in the future.

So the motivation behind building my homelab suddenly doubled. It was no longer only about storing memories. It became a way to preserve my technical playground, a space where I could learn, break things, rebuild them, and stay sharp without relying on any employer. With that mindset, everything escalated quickly.

## The NAS Decision

By December of 2023, I was already deep into researching what kind of NAS to get. I wanted something reliable and closer to enterprise grade rather than a flimsy consumer box. Expansion mattered because I did not want to outgrow my storage after a year. After comparing specs and reading countless Reddit threads, I eventually settled on Synology's DS923+. The "plus" line offered the compute power and flexibility I wanted, with a platform built for long term use. That decision opened the door to everything that followed.

![Storage drives - the foundation of any homelab](/Clustered-Thoughts/images/hard-drives.jpg)

## The Raspberry Pi Awakening

Once the NAS was running smoothly, I began wondering what else I could improve at home. That was when I remembered an unused Raspberry Pi tucked in a drawer, a hand me down from an officemate that I had never found a use for. Suddenly, I had one. I set up Pi-hole with Unbound to clean up DNS traffic and speed up my browsing. It was meant to be a tiny upgrade, but once everything worked seamlessly, something in my brain flipped.

![The humble beginnings of infrastructure tinkering](/Clustered-Thoughts/images/circuit-board.jpg)

## The Self-Hosted Media Stack

With 10 TB of storage available, the next idea came naturally: why not self host my media and stop paying for streaming subscriptions? I began exploring the ARR stack, Docker, media servers, and automation workflows. My mini PC quickly turned into a lab.

The state of streaming made the decision even easier. Everything felt fragmented. Each app had its own subscription, prices kept increasing, shows vanished without warning, and exclusives were scattered everywhere. I wanted a single place to organize the media I already owned without relying on half a dozen apps. If I was going to spend money every month, I would rather invest in a system where I owned the experience, not rented it.

That was the moment the homelab truly began.

## Networking: The Foundation

As more ideas appeared, such as Kubernetes clusters, hybrid networking with Azure, segmentation for IoT, and proper traffic visibility, I realized none of it would work without a solid foundation. Before anything else, I needed to fix the basics: networking.

Up until then, my home network relied on a consumer grade TP-Link mesh router and a cheap USB Wi-Fi dongle on my PC. It worked, but not for the architecture I had in mind. There were no VLANs, no advanced routing capabilities, no visibility, and no security.

So I made a list of what I wanted:

* Proper segmentation for IoT
* Full visibility into traffic flows
* Site to site VPN with Azure
* Reliable remote access and management
* Centralized SDN style control

My search narrowed to two ecosystems, Ubiquiti UniFi and TP-Link Omada.

Ubiquiti had the reputation, the UI, and the community, but not the availability. In the Philippines, UniFi gear is rare and often overpriced, and Amazon shipping costs more than the devices themselves. Omada, on the other hand, offered nearly everything I needed, was readily available, and was far more cost effective.

So Omada became the backbone of my network.

![Enterprise networking at home](/Clustered-Thoughts/images/network-cables.jpg)

## Building the Infrastructure

I built the foundation with an ER605 gateway, an 8 port managed switch, and an enterprise grade access point. To offload workloads properly, I asked a colleague in the US to bring home a budget mini PC so that my NAS could focus on storage.

For a while, everything worked beautifully. I dove into VLANs and ACLs, and designed my network with real segmentation. That was also when containerization finally clicked. I started with Docker, then Docker Compose, and the mini PC became a flexible service host powered by Proxmox, a surprisingly capable open source hypervisor that tied everything together nicely.

AI accelerated the journey as well. Even as a senior engineer, having ChatGPT and Claude Code as instant technical sounding boards made experimentation faster and smoother. They were not mentors, but tireless co-pilots who never slept.

## Learning from Mistakes

Eventually, the cracks began to show. Running the Omada controller as software on my NAS was a mistake. Whenever the NAS went down, even for a moment, I lost access to the entire network's management plane.

That painful realization reinforced a core infrastructure rule: **never put your management plane on top of the systems you are actively experimenting on**. The irony was that this was the exact pitfall I constantly warned enterprise customers about.

Moving the controller to dedicated hardware solved the problem instantly.

## The Escalation Continues

From there, the escalation continued.

I bought another Minisforum mini PC and built a Proxmox cluster. I migrated LXCs into Docker containers, deployed Kubernetes, created VMs, connected them to Azure Arc, and set up a site to site VPN to Azure so my environment behaved like a real hybrid cloud. At some point, it stopped feeling like a hobby and started looking like a miniature enterprise running inside my house.

Then came security. If I planned to expose services externally, I needed a real firewall, not simple port forwarding. I needed intelligent inspection, proper segmentation enforcement, and complete control over what entered and exited my network. So I ordered a ProtectCLI firewall board and began redesigning my perimeter with true zero trust principles. As environments grow, minimizing blast radius becomes essential.

## Version 2.0

While this was happening, my cables multiplied like vines. Initially, I used a 3D printed 10 inch rack from Printables.com. It worked fine at first, but once the hardware became more expensive, the setup deserved something sturdier and cleaner. I upgraded to a DeskPi T2 rack, which offered proper mounting, cable routing, and airflow.

**Version 2 of the homelab was born**: tidy, functional, and intentional.

![The evolution from chaos to clean infrastructure](/Clustered-Thoughts/images/server-rack.jpg)

Now I am looking at my old gaming PC, wondering what role it should play next. Plex transcoder, backup NAS, another Kubernetes node, or something entirely different. The possibilities seem endless.

## The Next Frontier: Local AI

The next frontier I hope to reach is local LLM hardware.

It feels like a full circle, building an AI stack that can eventually reduce my ChatGPT and Claude subscriptions. From trip photos to private cloud to AI inference, the escalation has been wild.

I am not there yet, since GPU and RAM prices are extremely high. A dedicated AI rig will have to wait another year or two. For now, I plan to optimize what I already have. My desktop with an RTX 4080 Super is next on the list, and I want to experiment with running 70B models locally to understand what is possible with consumer hardware today.

---

## So What Is This Blog For?

This blog is not only a story of how my homelab began. It is the beginning of a long term documentation effort, one where I share the lessons I learn, the mistakes I make, and the architecture patterns that work or fail.

Here, I plan to write about:

* The lessons I learn
* The gotchas that catch me off guard
* The best practices I discover
* The failures that teach me more than successes
* The security principles I reinforce
* The experiments that succeed
* The experiments that explode

As I continue exploring agentic AI automation, self healing infrastructure, and AI driven workflows inside my ecosystem, I plan to document those journeys as well. If my homelab is going to evolve, I want this blog to evolve alongside it.

## What's Coming

This blog will cover my homelab journey across several themes:

- **Origins** — How it all started and why AI became my infrastructure co-pilot
- **Foundation** — Hypervisors, networking, Terraform, Ansible, and documentation strategies
- **Containerization** — Docker patterns, Traefik, Authentik, and the complete media stack
- **Observability** — Monitoring with Prometheus, Grafana dashboards, and alerting
- **Automation** — Discord bots, CI/CD pipelines, and scheduled task management
- **Advanced Topics** — Kubernetes, hybrid cloud with Azure Arc, and zero-trust networking
- **Lessons Learned** — Mistakes I made, the true costs, and what I'd do differently

Each post will dive into what I built, why I built it, and the gotchas I encountered along the way.

---

This homelab is no longer just a project. **It is an ecosystem.**
And this blog is where the ecosystem gets recorded, refined, and shared.

Version 2 of my homelab is complete.
Version 3 is already forming in my head.
Somewhere beyond that, version 10 is waiting.

**Stay tuned. The journey is just getting started.**
