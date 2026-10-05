---
title: How I Used Codex to Automate My Homelab Patch Management (Without Letting It Run Wild)
date: 2026-10-05 09:00:00 +0800
categories:
- Homelab
- AI
tags:
- agents
- ai
- automation
- claude
- codex
- docker
- homelab
- patching
- proxmox
- sre
description: Notes on the six small agents that now find, research, apply, check and document OS and Docker updates in my homelab, which parts are actually AI, and the guardrails that let me sleep while it patches at 2 AM.
excerpt: Notes on the six small agents that now find, research, apply, check and document OS and Docker updates in my homelab, which parts are actually AI, and the guardrails that let me sleep while it patches at 2 AM.
render_with_liquid: false
---

> This post is about the patching setup running in my homelab right now: six small "agents" built around OpenAI Codex and Claude Code that find, research, apply, check, and document OS and Docker updates across my Proxmox cluster. If you're curious about AI but don't run servers, the first few sections and [the guardrails](#the-guardrails) should make sense without the code, so feel free to skip those blocks. If you do run your own infrastructure, the rest is my notes on how it's built and what went wrong along the way.

You probably know the feeling. You SSH into a VM you haven't touched in a month and it tells you there are 51 updates waiting. Then you remember there are about 25 more machines like it, three Proxmox hosts under them, and a few dozen Docker containers that have quietly fallen behind.

Patching is one of the most important jobs in IT and also one of the most boring, and I kept putting it off. So I tried handing it to a set of AI-assisted agents and keeping only one job for myself: saying yes or no.

This is the follow-up to my post on [giving AI agents a control plane for my homelab](/Clustered-Thoughts/posts/ai-agent-control-plane/), where I started working out how to let agents near my cluster safely. You don't need to read that one first.

## The Short Version

Every night, the system does roughly what a careful junior sysadmin would:

1. Finds what needs updating.
2. Opens a ticket for each machine or app.
3. Reads the release notes and warns me if something looks risky.
4. Asks me on Discord whether to go ahead.
5. Patches whatever I approved between 2 and 5 AM, after taking a backup.
6. Has a separate program check the results.
7. Writes it all up in the ticket, a daily report, and my Obsidian notes.

In the morning I get something like "4 machines patched, 2 apps updated, all verified, 1 update held back because it looked risky."

What matters most is what the AI can't do. It can't patch anything I haven't approved, it can't patch outside the 2 to 5 AM window, and it can't patch a machine that doesn't have a recent backup. The AI doesn't enforce any of that. Plain Python code around it does.

## Are These Really Agents?

It's a fair question. "Agent" gets slapped on everything right now.

The way I think about it, an agent gets a goal like "patch this server," figures out the steps, runs them, and adjusts when something unexpected happens. A script does the same fixed steps every time.

My setup uses both, and that's deliberate:

| Part of the job | Who does it | Why |
|---|---|---|
| Finding pending updates | Script | It's a fixed check. AI would only add randomness. |
| Opening and tracking tickets | Script | Bookkeeping should be predictable. |
| Researching whether an update is risky | AI (Codex) | Reading release notes and judging impact takes judgement. |
| Patching an OS | AI (Codex) | Real servers throw surprises like expired repo keys, held packages, and config prompts. |
| Updating Docker apps | Script | The steps never change, so there's no need for AI. |
| Checking the result | Script | The thing doing the checking shouldn't be the same kind of thing that did the work. |
| Figuring out why something failed | AI (Codex) | Reading logs and coming up with a theory is what language models are good at. |
| Writing the documentation | AI (Claude Code) | Turning raw data into readable notes is a writing job. |

The rule I ended up with: use AI where judgement helps, and plain code where I need things to be predictable. Most of the safety comes from the plain code.

## How It Fits Together

Picture a small IT team where everyone has one job and passes work along through a shared ticket board:

```
   ┌──────────────┐   finds updates    ┌──────────────┐  files tickets   ┌────────────────────┐
   │ 1. Auditor   │ ─────────────────▶ │ 2. Intake    │ ───────────────▶ │  GitLab issue      │
   │  (script)    │                    │  (script)    │                  │  board (the "to-do │
   └──────────────┘                    └──────────────┘                  │  list")            │
                                                                         └─────────┬──────────┘
                                                                                   │
            ┌──────────────────────────────────────────────────────────────────────┘
            ▼
   ┌──────────────────┐  plan + risk     ┌──────────────┐  approve /   ┌────────────────────┐
   │ 3. Planner +     │ ───────────────▶ │  Discord     │ ◀─ reject ── │   Me (the human)   │
   │  Risk reviewer   │                  │  message     │              └────────────────────┘
   │  (AI)            │                  └──────┬───────┘
   └──────────────────┘                         │ approved
                                                ▼
                                    ┌───────────────────────┐   fails?   ┌─────────────────┐
                                    │ 4. SRE agent (AI)     │ ─────────▶ │ Triage (AI)     │
                                    │ backup → patch →      │            │ "here's why"    │
                                    │ reboot → health check │            └─────────────────┘
                                    └───────────┬───────────┘
                                                ▼
                                    ┌───────────────────────┐
                                    │ 6. Verifier (script)  │  ← checks again, independently
                                    └───────────┬───────────┘
                                                ▼
                                    ┌───────────────────────┐
                                    │ Daily report (Discord)│
                                    └───────────┬───────────┘
                                                ▼
                                    ┌───────────────────────┐
                                    │ 5. Documenter (AI)    │  → my Obsidian notes
                                    └───────────────────────┘
```

Yes, Agent 6 runs before Agent 5. I numbered them before it occurred to me that you should check something before writing it down as done.

### What It's Built With

Nothing fancy. Most of it was already running in my lab:

| Component | Role |
|---|---|
| Proxmox VE (3-node cluster) | Hosts every VM and LXC being patched |
| Proxmox Backup Server | Backups. Nothing gets patched without a recent one. |
| GitLab (self-hosted) | The ticket board. One issue per machine for OS updates, or per Docker Compose stack for app updates. |
| Discord | Where I approve things and get reports |
| OpenAI Codex CLI | Patches, researches, and investigates failures, run headless with `codex exec` |
| Claude Code | Writes the documentation into my Obsidian vault |
| A small Debian LXC (`codex-agent-lxc`) | Where the agents live. One Python service (`sre_agent.py`) runs everything. |
| Python and SSH | The glue. No Kubernetes, no message queue, no agent framework. |

### The Ticket Board Holds the State

Each GitLab issue moves through a set of labels:

```
needs-plan → awaiting-approval → approved → patching → patched
                                                     ↘ patch-failed → (triage) → (verify-failed)
                                         ↘ rejected
```

The patching code won't touch an issue unless it's labelled `approved` and has none of `patching`, `patched`, `patch-failed`, or `rejected`. Since the state lives in GitLab and not in memory, a crash or restart doesn't lose anything. When the service starts again it just reads the board.

## A Typical Day

Here's what happens over 24 hours:

**6 PM.** A scan finds every machine with OS updates waiting and every Docker container with a newer image build available. Each gets a GitLab ticket, like "Container drift: docker-vm-core-utilities01 / paperless".

**Evening.** For each app update, Codex looks up the version I'm running and the new one, reads the release notes, and posts a risk review on the ticket.

**Whenever I get to it.** Discord shows me one message per ticket and I react to approve or reject. That's all I do.

**2 to 5 AM.** Approved tickets get patched one at a time, with a backup first.

**5:30 AM.** A separate checker goes over everything that was patched, and then a daily report goes to Discord.

**6 AM.** Claude Code writes up the night's work in my Obsidian notes, with links to each ticket.

Here's a real risk review from the night I wrote this:

> **Pre-approval risk review: paperless.** Risk: HIGH. Recommendation: hold.
>
> Paperless 3.2 removes the NLTK configuration options and automatically applies database migrations, including a one-way conversion of AI settings. Rolling back the image will not restore the previous data. Take a database backup and review your NLTK/AI settings before approving.

I'd already approved that update earlier in the day without reading anything. The reviewer took my approval back and asked me again. That's what I'd want a careful coworker to do.

A low-risk one looks more like this:

> **#19 authentik-lxc / authentik**: postgresql 16.15 → 16.15 (rebuild), redis 8.10.1 → 8.10.2.
> Low risk: security fixes, no breaking changes.

## Agent 4: Where Codex Is Actually Worth It

OS patching is where an AI agent really does better than a script. A script runs `apt upgrade` and falls over at the first surprise. My very first live run hit one straight away: the signing key for the GitLab Runner repository had expired, so `apt update` failed.

Codex stopped too, but only because I'd told it to stop on anything security-related rather than work around it, and its report explained exactly what was wrong. I added instructions for that case (refresh the vendor's key from its official source) and ran it again. The VM patched, rebooted onto the new kernel, and passed its checks.

For each approved ticket, the SRE agent:

1. Makes sure there's a recent backup, and takes one if there isn't.
2. Records the "before" state: installed packages, failed services, kernel version.
3. Hands the upgrade to Codex, which SSHes in, runs it, and deals with whatever comes up.
4. Reboots if needed, but never more than one Proxmox host per night.
5. Records the "after" state, closes the ticket, and posts a summary.

The Codex call itself is short:

```bash
codex exec --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema schema.json -o result.json \
  -C runs/ "$PROMPT" < /dev/null
```

A few notes on it.

`--output-schema` makes Codex finish with JSON (`status`, `packages_upgraded`, `reboot_required`, `issues_encountered` and so on), so my Python code can act on the result without trying to parse a paragraph.

`< /dev/null` is required. Without it, Codex running over a non-interactive SSH session sits there waiting for input forever. That cost me a whole evening.

`--dangerously-bypass-approvals-and-sandbox` is as scary as it sounds. The agent needs real root access over SSH to patch real machines, so I can't sandbox it. The safety has to come from everything around the call: my approval, the time window, the backup check, and the independent check afterwards.

<div class="notice--warning" markdown="1">

That flag means you've put the guardrails somewhere else. It doesn't mean you can skip them.

</div>

I also don't take Codex's word for it. When it's done, the Python code checks for itself that the host is reachable, the number of pending updates went down, no new services are failing, and the kernel is what it should be after a reboot. If Codex says it worked and the checks disagree, the ticket gets marked as failed.

## Docker Updates Don't Use AI

For containers I went the other way. Updating a Compose stack is the same steps every time, so there's no judgement involved and no reason to use AI:

```
docker tag <current image> <name>:sre-rollback-<timestamp>   # rollback point
docker compose pull <only the outdated services>
docker compose up -d <those services>
wait → check: running? not unhealthy? not restart-looping?
  if any check fails: retag rollback image, compose up again, mark failed, start triage
```

I tested the rollback by forcing a health check to fail. It rolled itself back, marked the ticket failed, and the triage agent correctly worked out that "this was a simulated failure for testing; the service is currently healthy on Python 3.11.17."

<div class="notice--success" markdown="1">

**Check the automation you already have**

While building this I found that the Watchtower container I'd set up for automatic updates hadn't done anything in months. It was in monitor-only mode and sending notifications to a server I'd shut down long ago.

</div>

### Getting Real Version Numbers

A message like "updated from `sha256:6f31d6…` to `sha256:2a43…`" is useless to a person. I wanted "Python 3.11.16 → 3.11.17."

For the version that's running, I read the image labels (`org.opencontainers.image.version`, or LinuxServer's `build_version`) and fall back to things like a `PG_VERSION` environment variable or a tag that looks like a version. For the new version, the agent asks the registry API directly. It grabs the manifest, picks the `linux/amd64` entry, and reads the labels from the config without pulling the image.

Two things tripped me up:

* **Labels from the base image.** GitLab's image said it was version `24.04`. That's the Ubuntu base image's label, not GitLab's. Now I ignore any label whose major version doesn't match the tag.
* **Nested indexes.** Authentik's image on GHCR is an index that points to another index. My first version only looked one level deep and came back with nothing.

## The Guardrails

If you only read one section, read this one. These are the things that stand between an AI and a broken server:

| Guardrail | What it prevents |
|---|---|
| Nothing happens without my approval | Surprise changes. Only my Discord account's reaction counts. |
| 2 to 5 AM only | Breaking things while my family is watching a movie |
| Backup first, or no patch | A mistake I can't undo |
| At most one Proxmox host per night | Taking the whole cluster down at once |
| Risk review before I approve | Me approving a one-way database migration without reading it |
| Automatic rollback for containers | A bad update staying broken |
| A separate check afterwards | Trusting the AI when it says it's done |
| AI triage when something fails | Waking up to an error with no explanation |
| Excluded hosts | The automation patching the machines it runs on |
| Everything logged | Not knowing what happened. Every step goes to GitLab, Discord, and a history file. |

None of these rely on the AI choosing to be careful. They're all in code that runs before or after it.

## Agent 6: The Checker

The verifier is deliberately simple and only reads things. For every run that finished at least 20 minutes ago, it checks:

* **OS updates:** every upgraded package is at least the version recorded (using `dpkg --compare-versions`), no systemd units are failing that weren't failing before, whether a reboot is still needed, and how many updates are left.
* **Containers:** each updated service is running, isn't marked unhealthy, and is still on the new image. That last check catches a container that quietly came back up on the old one.

It then leaves a comment on the ticket saying whether everything passed. If something fails, it reopens the ticket, pings me on Discord, and starts the triage agent.

To test it, I gave it a fake run that claimed `bash` had been upgraded to version 99.0 and that a container was on an image ID that doesn't exist. It caught both. I wouldn't trust a checker I'd never seen fail.

## Agent 5: Letting an AI Edit My Notes

My homelab documentation lives in an Obsidian vault on my desktop. It's my second brain, and the last place I want an AI making a mess. So the documentation agent runs on my PC instead of the server, has no infrastructure credentials at all, and is boxed in pretty tightly:

1. It only pulls runs that have been checked (or that failed) from the server over SSH.
2. It backs up every note it might touch before starting.
3. Claude Code runs headless (`claude -p`) with only the `Read`, `Edit`, `Glob`, and `Grep` tools. No shell, no new files, and the credentials note is explicitly off limits.
4. Afterwards, code checks what it did. Did it only edit allowed files? Did it create or delete anything? Did it remove more than a few lines? Did it actually update the changelog?
5. If anything looks wrong, everything gets restored from the backup and I get told.
6. If it all looks fine, it comments on each GitLab ticket to say the run was documented.

The first real run wrote up five patch runs in about 50 seconds. The changelog entry was honest about the simulated failure and linked every ticket. It also tacked on a few sentences explaining which files it hadn't edited and why, which nobody asked for. A stricter prompt fixed that.

## What My Mornings Look Like

Each finished ticket ends with a summary comment like this:

> **Patch summary: `codex-agent-lxc`** (patched)
>
> - Running kernel: 7.0.14-20-pve (unchanged)
> - Packages: 55 upgraded, 0 new, 0 removed. Pending updates: 51 → 0
> - (expandable table with every package, old version → new version)
>
> Issues/errors: none. Pending items: none.
>
> All looks good. Update applied, verified healthy, nothing pending.

If something needs my attention, like a reboot that's still pending or an update that failed, the last line says so and explains why. My part each week is reading a few risk reviews, approving a few things, and skimming a morning report.

## What I Learned

**Put the safety rules in code, not in the prompt.** Approval, the time window, backups, and verification are all enforced in Python. The triage and review agents only stay read-only because the prompt tells them to, and I know that's the weakest part of the whole thing.

**Don't let the thing doing the work check its own work.** When Codex says it succeeded, that's a claim. The verifier is a separate program that checks the facts.

**AI for judgement, plain code for bookkeeping.** My first instinct was to make everything an agent. The most reliable parts turned out to be the simplest ones.

**Make my part small, but don't remove it.** One tap per change is easy enough that I actually do it. Removing it would save me maybe two minutes a week, and I'd lose the ability to say "not tonight."

**The risk reviewer was worth more than I expected.** It pulled back my careless approval of a one-way database migration on the first day.

**The small bugs took the longest.** A missing `< /dev/null`. Two processes writing to the same state file. A label I forgot to remove. None of my problems were the AI not being smart enough. They were all plumbing.

## What's Next

* Giving each agent its own GitLab identity. Right now they all comment as the same bot user.
* Making the triage and review agents read-only in code instead of trusting the prompt.
* Noticing new version tags on pinned images (like `postgres:16` to `postgres:17`). Right now it only catches rebuilds of the same tag.
* Putting the agent container on its own network. It's on the same VLAN as everything else, and that's the biggest gap I have left.

## Final Thoughts

Thinking back to that VM with 51 updates, the AI wasn't really what fixed it. Codex is great at the messy bits like an expired key or an odd config prompt, but it's one box in the diagram. What made me comfortable letting it run at 2 AM was everything around it: my approval, the backups, the separate checks, and the logs.

If you're thinking about building something like this, I'd start with the guardrails and add the AI after. Once those are in place, plugging in an agent is the easy part.

*Built with OpenAI Codex CLI, Claude Code, Proxmox VE, GitLab CE, Discord, and a lot of Python.*
