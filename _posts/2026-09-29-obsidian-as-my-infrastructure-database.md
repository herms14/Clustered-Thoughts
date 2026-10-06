---
title: Obsidian as My Infrastructure Database
date: 2026-09-29 08:00:00 +0800
categories:
- Homelab
- Meta & Process
tags:
- claude
- homelab
- knowledge-management
- obsidian
- second-brain
description: Somewhere along the way, Obsidian stopped being a note-taking app and became the actual source of truth for my infrastructure, not by design, more by accumulation crossing a threshold I didn't notice until after the...
excerpt: Somewhere along the way, Obsidian stopped being a note-taking app and became the actual source of truth for my infrastructure, not by design, more by accumulation crossing a threshold I didn't notice until after the...
render_with_liquid: false
---

Somewhere along the way, Obsidian stopped being a note-taking app and became the actual source of truth for my infrastructure, not by design, more by accumulation crossing a threshold I didn't notice until after the fact.

The moment it became obvious: I was debugging a Traefik route and asked Claude Code to check the config. It pulled the route definition from the vault, not from the server, because the vault had the *documented* configuration, and the running server might have drifted from it since. My notes had quietly become more trustworthy than the thing they were describing.

## How it actually got here

The vault started as personal notes: credentials, half-formed ideas, things I didn't want to lose. Documenting infrastructure decisions there came next, mostly because Obsidian was already open. Session logging came after that, once I noticed how much context I was losing between sittings. The structure emerged from use rather than upfront design: numbered files per major topic (`01 - Network Architecture.md`, `02 - Proxmox Cluster.md`, and onward as new services arrived), `wikilinks` between related concepts, tags where links weren't quite enough, daily notes for the session context that would otherwise just evaporate.

What actually made it a *database*, rather than just notes, was the integration with Claude Code: a `CLAUDE.md` file at the repo root that tells Claude where things live, what the documentation patterns are, and what the update protocol is. When I ask it to add a service, part of the task, every time, is "update the relevant Obsidian files." The AI becomes the interface to the knowledge base, not just a tool that occasionally reads it.

That changes the actual dynamics of knowledge management: I don't have to remember to update documentation, because updating it is baked into the workflow itself. I don't have to organize things perfectly, because Claude can search and traverse the vault regardless. I don't have to hold the mental context myself, because the vault holds it for me. What IP does the backup server use? Check the vault. When did I last touch Traefik, and why? Check the session log and the changelog entry from that day.

## Where this beats a password manager outright

I tried a password manager first. Fine for web logins, awkward the moment the secret isn't a clean username/password pair: API keys with specific scopes, service tokens tied to one integration, SSH passphrases, database credentials with a rotation history worth remembering. A password manager wants a discrete pair. Infrastructure secrets come with context a discrete pair can't hold.

Obsidian's free-form notes handle that naturally: an entry for PBS can carry the API user, the token, the exact command to generate a new one, which services actually consume it, and a note on when it was last rotated, all in one place, in prose, instead of forced into fields that don't fit.

> A note that labels a credential "current" is only as trustworthy as the discipline behind keeping it current. The moment that label and the real deployed value drift apart, the vault isn't lying exactly, it's just wrong with total confidence. Treat "current" as a claim worth spot-checking against the actual running system occasionally, not a fact to build on blindly.

The vault syncs through OneDrive, which isn't a hardened secrets vault by any stretch, but is secure enough for my actual threat model. The genuinely sensitive stuff also lives in Ansible Vault and environment variables separately. Obsidian is where I look *first*, not the only place it exists.

## Daily notes catch what formal documentation misses entirely

Every infrastructure session gets a note: what I did, what broke, what's still unfinished. Five minutes at the end of a session, and it pays off weeks later in a way I didn't expect the first time it happened: reading a six-month-old note and recovering context I'd genuinely forgotten. *"Changed the firewall rule for VLAN 40 because Prometheus scraping was being blocked."* Past-me, leaving a note for present-me who had no memory of the decision at all.

These notes aren't polished, and that's the point. Formal documentation describes the intended state of the system. Session notes describe what actually happened, mess and all, and the mess is frequently the useful part.

## The linking model does more work than it gets credit for

Every doc touching Kubernetes links back to the Kubernetes overview note; every doc mentioning PBS links to the PBS doc. That builds a graph where related information just surfaces, without me having to remember it exists. Backlinks make it bidirectional: standing on the Kubernetes doc, I can see every session note where I debugged something K8s-related, every service that runs on it, every config file that references it. The structure comes from use, not from a taxonomy I designed in advance and then had to maintain.

## What Claude's actual interaction with this looks like

At the start of a session, Claude reads the context files (`CLAUDE.md`, the active task registry, the changelog), which gives it a working picture of what exists and what's mid-flight before I say anything. When we work on something together, it reads the relevant doc and updates it as part of finishing the task, not as a separate step I have to remember to ask for.

The effect is genuinely collaborative rather than me delegating busywork: I provide direction, Claude handles the detail work of keeping documentation synchronized with reality. Neither of us does this well alone. I don't have the patience for meticulous updates after every change, and Claude doesn't have the judgment for what's actually worth recording versus noise. Together, something gets maintained that neither of us would keep up on our own.

## Why "database" and not just "notes"

Because it's queryable in a way loose notes usually aren't. I can ask which services run on VLAN 40, which credentials haven't been rotated recently, which documentation references an IP I'm about to change, answered through content search and link traversal, not a formal schema. A traditional database optimizes for structured queries you knew to design for. Obsidian optimizes for the exploratory kind, when you don't know exactly what you're looking for and the graph gets you there anyway.

## The maintenance tax is real, and I treat it like gardening

Stale documentation accumulates. Links break when files move. Old session notes reference things that no longer exist. I review recent notes every few weeks, fix what's broken, and cut what's gone stale, not because the vault needs to be perfect, but because "useful" and "polished" are different goals, and only one of them is worth chasing here.

## What I'd actually tell someone starting this

Don't try to design the perfect system up front. Start with notes about whatever you're already doing, link them loosely, and let structure emerge from actual use rather than a taxonomy you invent before you have anything to organize. If you're pairing this with AI assistance, write the context file that describes your structure honestly. The AI will only use what you tell it exists, so the file and the vault converge over time, not on day one.

## The meta-observation

Infrastructure *work* is the easy part to reconstruct. I can always look up how to configure a Traefik route again. What's genuinely hard to reconstruct is *why* I made a specific choice six months ago, what I tried first that didn't work, what context made one option better than the alternative at the time. That tacit knowledge is the actual thing the vault preserves. The homelab itself could be rebuilt from nothing in a weekend. The reasoning behind it is the part I'd actually miss, and it's the part this whole system exists to keep.

---

*This is the twenty-ninth post in a series about building and maintaining a homelab. It covers meta-topics about managing the homelab itself rather than specific technical systems.*
