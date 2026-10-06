---
title: What I Would Change Starting Over
date: 2026-10-06 08:27:00 +0800
categories:
- Homelab
- Lessons Learned
tags:
- advice
- homelab
- lessons
- retrospective
description: Three years in, the current setup works well — but the path here was inefficient, full of detours that taught their lessons the slow, expensive way. Here's what I'd actually tell myself at the start, with the specifics...
excerpt: Three years in, the current setup works well — but the path here was inefficient, full of detours that taught their lessons the slow, expensive way. Here's what I'd actually tell myself at the start, with the specifics...
render_with_liquid: false
---

Three years in, the current setup works well — but the path here was inefficient, full of detours that taught their lessons the slow, expensive way. Here's what I'd actually tell myself at the start, with the specifics attached rather than the vague version.

## Infrastructure as code, from the first VM

My earliest VMs came from clicking through the Proxmox GUI, with the only record of how they were configured living inside the VMs themselves — rebuilding one meant reconstructing settings from memory. Everything now runs through Terraform and Ansible: VMs are defined in code, configuration is a playbook, and rebuilding means running the same commands and getting the same result, not reconstructing anything.

> I assumed IaC was overkill for something this small. It isn't — the time spent writing the Terraform pays itself back the very first time you need to modify or recreate anything, and after that it's pure profit. Start with IaC even in its simplest form; the habit matters more than the sophistication of the first version.

## Document while you're still building, not after

For the first year, "documentation" meant stray comments in config files — remembering how something worked meant reverse-engineering it from the running system later. Now it goes into Obsidian as part of the change itself, not as a follow-up task, and it doesn't need to be polished to be useful. Documentation written in the moment is accurate. Documentation written a month later is missing exactly the details you'd have sworn you'd remember.

## Fewer services, understood properly

The temptation is to deploy everything Reddit mentions in the same thread — Prometheus, Grafana, Loki, Jaeger, Tempo, every dashboard someone shared a screenshot of. Most of what I deployed that way sat unused; I never understood it deeply enough to extract any value, so it just consumed resources and attention for nothing. Deploying one thing and actually learning it beats a shallow familiarity with five tools, every time.

## Segment the network earlier, but simpler than you'll be tempted to

I started flat — one subnet, everything on it — which worked right up until isolating IoT devices became urgent rather than theoretical. Then I over-corrected: too many VLANs before understanding inter-VLAN routing, which turned into weeks of debugging "connectivity issues" that were actually firewall rules behaving exactly as configured. The right middle: three VLANs to start (infrastructure, services, IoT), a real understanding of the routing between them, and more only once there's a concrete reason, not a hypothetical one.

## Backups before the third VM, not after the eighteenth

I had eighteen VMs running — eighteen things I'd have had to rebuild from nothing — before I configured automated backups at all. Backups should be close to the first thing you set up, not an afterthought bolted on once there's enough at stake to be scary. PBS is easy enough to deploy that there's genuinely no excuse: a few hours of setup buys months of not having to think about it.

## Monitoring that answers a question, not monitoring as decoration

Early dashboards showed every metric I could scrape — walls of graphs I never actually looked at, impressive to screenshot and useless in practice. Useful monitoring answers specific, actionable questions: is there a problem *right now*, what's actually consuming resources, how much headroom is left. Everything else is just noise wearing a chart. Start with alerts for things that need action, add dashboards only for numbers you'll genuinely check, and remove panels the moment you notice you've stopped looking at them.

## Default to LXC, reserve VMs for when you actually need one

Everything started as a full VM, each with gigabytes allocated regardless of what it actually used — the VM tax, paid repeatedly, for no real benefit. LXC is the better default for lightweight services; VMs earn their overhead when you genuinely need full isolation, a different kernel, or something non-Linux. I'd flip the default from day one instead of migrating my way there later.

## GitOps from the start, not retrofitted

Deployments used to mean an SSH session, manual file edits, and restarting containers by hand — no version control, no audit trail, no clean rollback if something went sideways. Now a push to GitLab triggers the pipeline, the history shows exactly what changed and when, and rolling back is reverting a commit instead of reconstructing a mental timeline. The setup cost is an afternoon. The payoff is every single deployment after that one.

## Fundamentals before the tools built on top of them

I learned Kubernetes before I'd really internalized containers, Traefik before I understood HTTP routing properly, Ansible before I understood SSH well enough to know what it was actually automating. Tools make dramatically more sense once you understand what they're abstracting — time spent on the boring fundamentals pays off in every tool built on top of them, which is most of the stack.

## The meta-lesson

I couldn't have followed any of this advice on day one, because I didn't yet know what I didn't know — the mistakes are what actually taught the lessons, not the other way around. The homelab is a learning environment first; making mistakes isn't a failure mode, it's the mechanism. The goal was never zero errors. It's not repeating the same one twice.

Start. Build something real. Break it. Fix it properly. Learn what actually happened. Repeat — on purpose, this time.

---

*This is the twenty-eighth post in a series about building and maintaining a homelab. The series continues with meta-topics about the homelab journey itself.*
