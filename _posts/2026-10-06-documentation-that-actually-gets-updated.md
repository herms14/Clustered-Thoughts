---
title: Documentation That Actually Gets Updated
date: 2026-10-06 08:06:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- documentation
- homelab
- obsidian
- process
description: Documentation rots. The words stay the same; the system they describe changes underneath them, and eventually you're reading instructions for something that no longer exists. I have direct proof of this failure mode...
excerpt: Documentation rots. The words stay the same; the system they describe changes underneath them, and eventually you're reading instructions for something that no longer exists. I have direct proof of this failure mode...
render_with_liquid: false
---

Documentation rots. The words stay the same; the system they describe changes underneath them, and eventually you're reading instructions for something that no longer exists. I have direct proof of this failure mode from my own vault, not a hypothetical one.

My credentials doc listed a specific SSH public key as "current," labeled with a rotation date. Months later, while bootstrapping a new container, I used that documented key verbatim — and it didn't work, because the key actually deployed across every host was a different one entirely. The rotation the doc described had apparently never actually completed, and nothing had forced a check against reality in the meantime. The doc wasn't lying on purpose. It was just old, in a way that looked exactly like current.

The fix I've landed on isn't clever: documentation updates are part of the task, not a follow-up to it. A change isn't done until the relevant doc reflects it. Not eventually — before I mark anything complete.

---

The structure has three layers, each with a specific job:

A changelog, dated and append-only, that records *what changed and when* — not a summary, a log. A task registry that tracks what's active, pending, or blocked, specifically so that if I run two sessions against the same repo at once, the second one checks the registry first instead of duplicating work the first one already claimed. And a set of numbered reference docs — network architecture, IP allocation, deployed services — that describe current state as tables, not prose.

> When you're troubleshooting at midnight, you don't want sentences. You want to scan a table and find the row. "PBS runs on node03 at `192.168.20.50:8007`, external at `pbs.hrmsmrflrii.xyz`" takes three seconds to read as a row and fifteen as a sentence, for the same information.

A separate file is flagged sensitive and handled with more care than the rest — passwords, API keys, tokens. That file has also been the source of the worst documentation-rot incident this vault has had: it ended up tracked in a public GitHub repo, live keys and all, discovered and purged well after the fact. The fix wasn't better formatting. It was `.gitignore` and a rotation, and a standing rule now that anything in that file gets double-checked before any commit touches it.

---

The coordination problem is real with three layers instead of one. My approach: every infrastructure change explicitly updates the changelog and the registry in the same pass as the actual work, not after. Working with an AI assistant makes this easier to actually hold to — I can say "update the changelog and task registry" as part of the request and trust it happens, rather than relying on my own discipline at 11 PM when the fix finally works and I just want to close the laptop.

---

Linking does real work here too. A note on, say, Immich backup procedure links to the credentials entry for its SSH key, which links to the SSH configuration doc, which links back to the changelog entry where the key was last touched. When something's wrong, following those links usually gets me to the actual cause faster than searching would.

What I got wrong early on: over-organizing. I tried to keep a tidy folder hierarchy with everything filed perfectly, and maintaining that hierarchy became its own chore — files piled up in an "unsorted" bucket because I couldn't decide where they belonged. I stopped caring about perfect filing and let numbering plus search plus links do the work folders were supposed to do. Finding things matters more than filing them correctly, and those turned out not to be the same skill.

---

A root-level instructions file — read automatically at the start of every session — serves as onboarding for an AI assistant, and writing it forced me to answer questions I'd only ever answered implicitly: which VLANs are for what, where credentials live, what the actual update protocol is. Answering those for an assistant meant answering them for myself, for the first time, in writing.

The update protocol matters more than the documentation's structure does. Elegant documentation that's six months stale is worse than scattered notes that are accurate today — the goal is accuracy, not organization, and the natural pull is always toward finishing the technical work and skipping the doc update because it feels like overhead. Fighting that pull, repeatedly, is most of what this actually is.

---

*This is the seventh post in a series about building and maintaining a homelab. The next post covers Docker Compose, and the thirty-container setup it eventually grew into.*
