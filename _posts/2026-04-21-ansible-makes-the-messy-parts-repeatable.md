---
title: Ansible Makes the Messy Parts Repeatable
date: 2026-04-21 08:00:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- ansible
- automation
- configuration
- homelab
description: Terraform gives you a VM. Ansible turns it into something useful. Those are different problems, and I learned that the hard way by trying to make Terraform do both.
excerpt: Terraform gives you a VM. Ansible turns it into something useful. Those are different problems, and I learned that the hard way by trying to make Terraform do both.
render_with_liquid: false
---

Terraform gives you a VM. Ansible turns it into something useful. Those are different problems, and I learned that the hard way by trying to make Terraform do both.

Provisioners that SSH in and run commands work, technically. They're fragile in practice, because the abstraction doesn't fit: Terraform wants to answer "does this resource exist," and Ansible wants to answer "has this configuration converged." Forcing one tool to answer the other's question is where things get flaky.

---

The core property that matters is idempotency: running the same playbook twice should produce the same result. If a file already has the right content, don't touch it. If a package is already installed, don't reinstall it. This is what lets you re-run playbooks on a schedule without worrying about what they'll do to something that's already correct.

Configuration drifts quietly: someone SSHs in and tweaks a setting by hand, an update changes a default, six months pass and nobody remembers what the intended state was supposed to be. A playbook is both the documentation of intended state and the enforcement of it. The first time I re-ran one expecting zero changes and got three, I understood exactly what that property was protecting me from.

---

My Ansible controller is a dedicated VM at `192.168.20.30` (same box that later ended up hosting Helios, the little FastAPI control-plane tool I built and then forgot about for four months, which is a story for a different post). It has SSH access to everything, organized through an inventory that groups hosts by function: Proxmox nodes, Docker hosts, each with group-level variables for the default SSH user and Python interpreter.

Playbooks target groups ("for all docker_hosts, do X") rather than listing hosts individually, so the inventory is the one place that needs to know what exists and where.

---

Most playbooks follow the same shape: ensure a directory structure, template configuration files in from Jinja2, deploy via Docker Compose, wait for a health check, register DNS if there's an external route. The pattern repeats across the monitoring stack, the media stack, the Discord bot host, different specifics, recognizable structure, which makes troubleshooting faster because I already know roughly where to look.

Secrets go through Ansible Vault: an encrypted file alongside the playbooks, decrypted at runtime with a password file that's excluded from version control. It's not perfect security; the password file exists somewhere and that somewhere matters. But it beats plaintext values in YAML, which is the failure mode I'm actually avoiding, and a failure mode this repo has hit before in a different file entirely: a credentials doc that ended up tracked in a public GitHub repo with live API keys sitting in it, found and purged the hard way. Vault wouldn't have prevented that specific mistake, but it's the same category of discipline.

---

The handoff between Terraform and Ansible is the part I'm least proud of. Terraform creates a resource and knows its IP; Ansible's inventory needs to find out. I use a script that pulls Terraform outputs and regenerates the inventory, which mostly works but has enough edge cases and timing quirks that I don't fully trust it unattended. I tried wiring Ansible directly into Terraform's `remote-exec` provisioner once, calling it immediately after creation, and found it worse: the network isn't always up yet, cloud-init isn't always finished, and debugging a failure inside that chain is miserable. Separating "create" from "configure" into two deliberate steps is slower and more reliable, which is a trade I'll take every time.

---

Debugging is genuinely one of Ansible's strengths. `-v` gives basics, `-vvv` shows the actual SSH commands, `-vvvv` shows connection-level detail. When a task fails, the error usually names the task and the reason directly (something like "task 14 failed, file didn't exist") rather than cascading into something you have to reconstruct from a stack trace.

What I underestimated early on: the time a playbook costs to write pays back slowly, then all at once. Writing one for a service I thought I'd only ever deploy once felt like overhead: why not just SSH in and configure it by hand? But services move between hosts over a cluster's lifetime more often than you'd expect, and the playbook that cost an hour to write has saved far more than that by the third time I needed it again.

---

*This is the sixth post in a series about building and maintaining a homelab. The next post covers documentation, specifically what happens when the three places you keep it disagree with each other and with reality.*
