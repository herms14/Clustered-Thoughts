---
title: An AI That Knows My Network Better Than I Do
date: 2026-10-06 08:01:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- ai
- automation
- claude
- homelab
description: I started using Claude Code out of laziness, not strategy. I was tired of switching between terminal windows, documentation tabs, and YAML files, trying to hold "which host runs which service at which IP" in my head at...
excerpt: I started using Claude Code out of laziness, not strategy. I was tired of switching between terminal windows, documentation tabs, and YAML files, trying to hold "which host runs which service at which IP" in my head at...
render_with_liquid: false
---

I started using Claude Code out of laziness, not strategy. I was tired of switching between terminal windows, documentation tabs, and YAML files, trying to hold "which host runs which service at which IP" in my head at the same time as whatever I was actually trying to fix. I thought: maybe I can just describe what I want and let something else track the details.

That turned out to be the right instinct, for reasons I didn't expect going in.

---

The first thing I gave it was a file at the root of my infrastructure vault — `CLAUDE.md`, loaded automatically at the start of every session. Not a technical artifact so much as a briefing document: cluster topology, VLAN layout, which services live where, SSH key locations, and — more useful than any of that — a numbered **Behavioral Rules** section, because "update the changelog" and "never touch the dead NAS interface" are rules I kept forgetting myself, let alone expecting an AI to infer.

Writing it made me understand my own infrastructure better than using it did. I had to articulate patterns I'd only ever felt. Why does production traffic sit on its own VLAN, separate from the Proxmox nodes themselves? Because I wanted Docker services walled off from the hypervisor layer after one bad config change took down more than it should have. That decision had been living in my head as a vague instinct. Writing it into a file made it a rule I could point back to.

The file has grown past a few hundred lines now, across a handful of linked documents rather than one giant blob: cluster topology, a credentials file (flagged sensitive, handled separately from everything else), a running changelog, and a task registry so that if I open two Claude Code sessions against the same repo by accident, the second one knows not to duplicate the first one's work.

> This isn't documentation for me. I know most of this by heart. It's documentation for a second brain that starts every session from zero and needs to get oriented in under thirty seconds.

---

The workflow shift happened gradually. At first Claude was just fixing YAML indentation — useful, not transformative. It changed when I stopped describing tasks and started describing outcomes.

"Add a new service. It needs persistent storage, a Traefik route, and a DNS entry. Update the changelog and task registry when you're done."

That one sentence touches four or five different systems and at least two documentation files. Before, I'd context-switch through each one, keeping a mental checklist of what I'd done and what was still pending. Now I state the goal, review what comes back, and correct what's wrong. The cognitive load moved from *orchestrating* to *reviewing*, which is a meaningfully easier job.

It doesn't always get it right the first time. I've caught it making assumptions I wouldn't have — guessing at an IP range instead of checking the actual allocation table, for one. But reviewing a wrong guess is still faster than being the one who has to remember the right answer from scratch every time.

---

The part I didn't anticipate was what this does to debugging.

"Glance's custom API widgets are erroring, 'Error fetching data,' didn't change anything recently" is a complete bug report now. It's enough for something to SSH into the relevant hosts, check container logs, trace the actual path a request takes, and come back with a cause rather than a guess. Once it was a Grafana datasource URL that silently changed after an update. Another time, a stale ARP entry on a Proxmox node after a container's MAC address changed — the kind of thing that looks like "ping works but TCP connections get refused" and sends you down completely the wrong path if you don't already know that specific symptom.

I'd have found both eventually. Not in the same twenty minutes, and not without the usual wrong turns debugging takes when you're reasoning from scratch instead of from a map you already have memorized.

---

The honest caveats:

It only knows what I've told it. If the documentation is stale, the suggestions are wrong in exactly the shape of the staleness — and I've hit this directly. A rotated SSH key never actually got redeployed everywhere the credentials doc claimed it had been, and that mismatch sat undiscovered for weeks because nothing forced a check against reality until something failed. Output quality tracks input quality, which sounds obvious until you're the one who let the input go stale.

It also doesn't replace understanding, it just removes the friction between having an idea and executing it. I still need to know how Traefik's routing actually works, how VLAN ACLs get evaluated, why DNS propagation delay causes intermittent failures that look like something else entirely. What's different is that *knowing* and *doing* used to be the same bottleneck, and now they're not.

---

If you want to try this yourself, start with the documentation, not the AI part. Write down what your infrastructure actually looks like — not as a task for a model, as a task for you. You'll find gaps in your own understanding before you find anything else. Handing that document to an assistant afterward is the easy part.

Worst case, you end up with documentation that's actually accurate. Best case, your relationship to your own systems changes. Both happened to me, and the second one mattered more than I expected it to.

---

*This is the second post in a series about building and maintaining a homelab. The next post covers why I ended up on Proxmox, and what I gave up to get there.*
