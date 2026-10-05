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
description: Six AI-assisted agents now find, research, apply, verify and document every OS and Docker update in my homelab. I approve each one with a single Discord reaction. Here's how it works, what's actually AI and what isn't, and the guardrails that let me sleep while it patches at 2 AM.
render_with_liquid: false
---

Every homelabber knows the feeling. You open a terminal on a VM you haven't touched in a month, and it tells you there are 51 updates waiting. Then you remember there are about 25 more machines like it, three Proxmox hosts underneath them, and a few dozen Docker containers that have quietly fallen behind.

Patching is the most important boring job in IT. It's also the one I kept putting off.

So I tried something. I gave the job to a team of AI-assisted "agents" built around OpenAI's **Codex**. I kept exactly one job for myself: saying **yes** or **no**.

This post explains how that system works. I've written it for two kinds of readers:

- **If you're curious about AI but not technical**, read the sections marked 🧭. They explain the idea in plain language, and you can skip the code.
- **If you run your own infrastructure**, the 🔧 sections cover the architecture, the guardrails, and the bugs I hit along the way.

---

## 🧭 The short version

Every night, the system does roughly what a careful junior sysadmin would do:

1. **Notices** what needs updating.
2. **Writes a ticket** for each machine or app.
3. **Reads the release notes** and warns me if an update looks risky.
4. **Asks me** for approval on Discord. I tap ✅ or ❌.
5. **Patches** the approved items between 2 and 5 AM, after taking a backup first.
6. **Checks its own work** a second time, independently.
7. **Writes up what happened** in the ticket, in a daily report, and in my personal notes.

I wake up to a report that reads something like *"4 machines patched, 2 apps updated, all verified, 1 update held back because it looked risky."*

The important part is what the AI is **not** allowed to do. It cannot patch anything I haven't approved. It cannot patch outside the 2–5 AM window. It cannot patch a machine that lacks a fresh backup. Most of the checking is done by plain, predictable code, not by AI.

---

## 🧭 First, an honest question: are these really "agents"?

"Agent" is the most overused word in tech right now, so here's a straight answer.

An **AI agent** is software that gets a goal ("patch this server"), works out the steps itself, uses tools to carry them out (running commands, reading output), and adjusts when something unexpected happens.

A **script** follows a fixed recipe: step 1, step 2, step 3, every time.

My system uses **both, on purpose**:

| Part of the job | Who does it | Why |
|---|---|---|
| Finding pending updates | Plain script | It's a fixed check. AI would only add randomness. |
| Filing and tracking tickets | Plain script | Bookkeeping has to be predictable. |
| Researching whether an update is risky | **AI (Codex)** | Reading release notes and judging impact is a judgement call. |
| Actually patching an OS | **AI (Codex)** | Real servers throw surprises: expired repository keys, held packages, config prompts. |
| Updating Docker apps | Plain script | The steps are always the same, so no AI is needed. |
| Verifying the result | Plain script | A checker should never be the same kind of thing as the doer. |
| Diagnosing a failure | **AI (Codex)** | Reading logs and forming a theory is exactly what language models are good at. |
| Writing the documentation | **AI (Claude Code)** | Turning raw data into readable notes is a writing task. |

The rule I settled on: **use AI where judgement helps, and use boring code where predictability matters.** Most of the safety comes from the boring code.

---

## 🧭 What the pipeline looks like

Imagine a small IT team. Each person has one job and passes work to the next person through a shared ticket board.

```
   ┌──────────────┐   finds updates    ┌──────────────┐  files tickets   ┌────────────────────┐
   │ 1. Auditor   │ ─────────────────▶ │ 2. Intake    │ ───────────────▶ │  GitLab issue      │
   │  (script)    │                    │  (script)    │                  │  board (the "to-do │
   └──────────────┘                    └──────────────┘                  │  list")            │
                                                                         └─────────┬──────────┘
                                                                                   │
            ┌──────────────────────────────────────────────────────────────────────┘
            ▼
   ┌──────────────────┐  plan + risk     ┌──────────────┐   ✅ / ❌    ┌────────────────────┐
   │ 3. Planner +     │ ───────────────▶ │  Discord     │ ◀────────── │   Me (the human)   │
   │  Risk reviewer   │                  │  message     │             └────────────────────┘
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

(Yes, Agent 6 runs before Agent 5. I numbered them before I realised you should verify something *before* you write it down as done.)

---

## 🔧 The building blocks

Nothing here is exotic. It's mostly tools I already ran:

| Component | Role |
|---|---|
| **Proxmox VE** (3-node cluster) | Hosts every VM and LXC container being patched |
| **Proxmox Backup Server** | Backups. The agent won't patch anything without a recent one. |
| **GitLab** (self-hosted) | The ticket board. One issue per machine (OS updates) or per Docker Compose stack (app updates). Labels act as a state machine. |
| **Discord** | Where I approve things and receive reports |
| **OpenAI Codex CLI** | The AI that patches, researches and triages, run headless with `codex exec` |
| **Claude Code** | The AI that writes documentation into my Obsidian vault |
| **A small Debian LXC** (`codex-agent-lxc`) | Where the agents live. One always-on Python service (`sre_agent.py`) runs the show. |
| **Python + SSH** | The glue, and nothing else. No Kubernetes, no message queue, no agent framework. |

### The ticket board is the state machine

Each GitLab issue moves through labels:

```
needs-plan → awaiting-approval → approved → patching → patched
                                                     ↘ patch-failed → (triage) → (verify-failed)
                                         ↘ rejected
```

The executor refuses to touch an issue unless it has `approved` **and** none of `patching / patched / patch-failed / rejected`. Because the state lives in labels, a crash or restart never loses track of anything. When the service comes back up, it just reads the board again.

---

## 🧭 A day in the life

Here's what actually happens over 24 hours.

**18:00 – Discovery.** A scan finds every machine with pending OS updates and every Docker container whose image has a newer version in its registry. Each gets a GitLab ticket, for example *"Container drift: docker-vm-core-utilities01 / paperless"*.

**Evening – Research.** For each app update, the AI looks up the version I'm running and the version available, reads the release notes, and writes a risk review. Here's a real one from tonight:

> 🧐 **Pre-approval risk review — paperless** · Risk: **HIGH** · Recommendation: **hold**
>
> Paperless 3.2 removes the NLTK configuration options and automatically applies database migrations, including a one-way conversion of AI settings. **Rolling back the image will not restore the previous data.** Take a database backup and review your NLTK/AI settings before approving.

I had already approved that update earlier in the day without reading anything. The reviewer **took my approval back** and asked me again. That's exactly what I want a careful colleague to do.

**Whenever I like – Approval.** Discord shows me a message per ticket:

> 🛠️ **#19 authentik-lxc / authentik** — postgresql 16.15 → 16.15 (rebuild), redis 8.10.1 → **8.10.2**
> 🟢 Low risk: security fixes, no breaking changes. React ✅ to approve, ❌ to reject.

I tap ✅. That's my entire job.

**02:00–05:00 – Patching.** For each approved ticket, one at a time:

1. Confirm a recent backup exists. If not, take one now.
2. Record the "before" state: installed packages, failed services, kernel version.
3. **OS updates:** hand the job to Codex. It SSHes in, runs the upgrade, and deals with anything unexpected.
4. **App updates:** tag the current image as a rollback point, pull the new one, restart, check health. **If the health check fails, roll back automatically.**
5. Reboot if needed (at most one Proxmox host per night).
6. Record the "after" state, close the ticket, and post a summary.

**05:30 – Verification + report.** A separate checker re-examines every patched item. Then a daily report lands in Discord: what changed, from which version to which version, and whether it was verified.

**06:00 – Documentation.** Claude Code writes the night's work into my Obsidian notes and links every ticket.

---

## 🔧 Agent 4, the SRE agent: where Codex actually earns its keep

OS patching is where an AI agent really beats a script. A script runs `apt upgrade` and dies on the first surprise. My very first live run hit one of those surprises right away: the GitLab Runner repository's signing key had **expired**, so `apt update` failed.

A script would have stopped there. Codex stopped too, because my prompt told it to fail safe on anything security-related rather than work around it. Its report explained exactly why. I changed the prompt to cover that case (refresh the vendor's key from its official source), re-ran it, and the VM patched, rebooted onto the new kernel and verified cleanly.

The core of the call is short:

```bash
codex exec --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema schema.json -o result.json \
  -C runs/ "$PROMPT" < /dev/null
```

Three things matter here:

- **`--output-schema`** forces Codex to finish with structured JSON (`status`, `packages_upgraded`, `reboot_required`, `issues_encountered`…), so the Python code can make decisions without parsing prose.
- **`< /dev/null`** is not optional. Without it, Codex running over a non-interactive SSH session sits waiting for stdin forever. I lost an evening to that.
- **`--dangerously-bypass-approvals-and-sandbox`** looks scary, and it is. The agent needs real root over SSH to patch real machines. The safety comes from **what surrounds the call**, not from the call itself: the approval gate, the time window, the backup gate, and a deterministic verification afterwards. Treat that flag as "I've put the guardrails somewhere else," never as "I don't need guardrails."

And I don't trust Codex's self-report. After it finishes, the Python code independently checks that the host is reachable, the pending-update count went down, no *new* services are failing, and the kernel matches what was expected after a reboot. If Codex says "success" but the checks disagree, the ticket is marked failed.

---

## 🔧 Docker updates: deliberately *not* AI

For containers I went the other way. Updating a Compose stack is always the same sequence:

```
docker tag <current image> <name>:sre-rollback-<timestamp>   # rollback point
docker compose pull <only the outdated services>
docker compose up -d <those services>
wait → check: running? not unhealthy? not restart-looping?
  ✗ → retag rollback image, compose up again, mark failed, start triage
```

No judgement is needed, so no AI. I tested the rollback path by forcing a health check to fail. The system rolled back by itself, filed the failure, and the AI triage agent correctly worked out *"this was a simulated failure for testing; the service is currently healthy on Python 3.11.17."*

Along the way I discovered that the Watchtower I'd set up for "automatic updates" had been doing **nothing for months**. It was in monitor-only mode and sending notifications to a server I had decommissioned. Automation you never check is just decoration.

---

## 🔧 Getting real version numbers (harder than it sounds)

"Updated from `sha256:6f31d6…` to `sha256:2a43…`" means nothing to a human. I wanted *"Python 3.11.16 → 3.11.17"*.

For the running version I read the image's labels (`org.opencontainers.image.version`, LinuxServer's `build_version`) and fall back to environment variables like `PG_VERSION` or a version-looking tag. For the *available* version, the agent talks to the registry API directly: it fetches the manifest, picks the `linux/amd64` entry from a multi-arch index, and reads the config blob's labels without pulling the image.

Two traps I hit:

- **Inherited labels lie.** GitLab's image reported version `24.04`. That's the Ubuntu base image's label, not GitLab's. I now ignore a label whose major version disagrees with the tag.
- **Indexes can be nested.** Authentik's image on GHCR is an index pointing to *another* index. My first version handled only one level and returned nothing.

---

## 🧭 The safety net, in plain language

If you remember one section, make it this one. Here's everything that stands between an AI and a broken server:

| Guardrail | What it prevents |
|---|---|
| **Nothing happens without my ✅** | Surprise changes. Only my Discord account's reaction counts. |
| **2–5 AM window only** | Breaking things while my family is streaming a movie |
| **Backup first, or no patch** | An unrecoverable mistake |
| **At most one Proxmox host per night** | Taking the whole cluster down at once |
| **Risk review before approval** | Me rubber-stamping an update with a one-way database migration |
| **Automatic rollback for apps** | A bad container update staying broken |
| **Independent verification** | Trusting the AI when it says "done" |
| **AI triage on failure** | Waking up to a cryptic error with no explanation |
| **Excluded hosts** | The automation patching the machines that run the automation |
| **Full audit trail** | Not knowing what happened. Every step goes to GitLab, Discord and a history file. |

None of these depend on the AI "deciding to be careful." They are enforced in code that runs before or after the AI.

---

## 🔧 Agent 6: the verifier that doesn't trust anyone

The verifier is intentionally boring and read-only. For every completed run at least 20 minutes old, it checks:

- **OS:** every upgraded package is at or above the version recorded (`dpkg --compare-versions`), no systemd units failed that weren't failing before, the reboot-required flag, and the remaining update count.
- **Containers:** each updated service is running, not `unhealthy`, and **still on the new image**. That last check catches a container that silently came back on its old image.

It posts a verdict on the ticket: *"🔎 Independent verification — pass. All looks good."* If the verdict is fail, it reopens the ticket, alerts Discord and starts AI triage.

I tested it with a fake run that claimed `bash` was upgraded to version 99.0 and that a container was on an image ID that doesn't exist. It flagged both. A checker you've never seen fail is a checker you can't trust.

---

## 🔧 Agent 5: letting an AI edit my notes (carefully)

My homelab documentation lives in an Obsidian vault on my desktop. That's my second brain, and the place I least want an AI to make a mess.

So the documentation agent runs on my PC, not on the server. It holds **zero** infrastructure credentials and is fenced in on every side:

1. Pull the list of undocumented runs from the server over SSH. Only runs that have been verified (or that failed) are included.
2. **Back up** every note it could possibly touch.
3. Run Claude Code headless (`claude -p`) with only `Read`, `Edit`, `Glob` and `Grep` tools allowed. No shell, no creating files, and the credentials note explicitly denied.
4. **Validate the result mechanically.** Did it edit only allowed files? Create or delete anything? Remove more than a handful of lines? Did it actually update the changelog?
5. On any violation, **restore everything from the backup** and report the failure.
6. On success, comment on each GitLab ticket: *"📝 Documented in the Obsidian vault."*

The first real run documented five patch runs in about 50 seconds. Its changelog entry was honest about the simulated failure and linked every ticket. It also padded its one-sentence summary with "I didn't edit these other files because…". AI is very willing to tell you what it *didn't* do. A tighter prompt fixed that.

---

## 🧭 What the morning looks like now

Each finished ticket ends with a closing note like this:

> 📋 **Patch summary — `codex-agent-lxc`** · ✅ patched
>
> - **Running kernel:** 7.0.14-20-pve (unchanged)
> - **Packages:** 55 upgraded, 0 new, 0 removed · **Pending updates:** 51 → 0
> - *(expandable table: every package, previous → current version)*
>
> **Issues / errors:** none · **Pending items:** none
>
> ✅ **All looks good** — update applied, verified healthy, nothing pending.

If something needs me, for example a reboot still pending or a failed update, the last line turns 🟡 or ❌ and says why.

My actual weekly effort is now: read a few risk reviews, tap ✅ a few times, and skim a morning report.

---

## Lessons learned

**1. Put the safety in the code, not the prompt.** Every critical rule (approval, window, backup, verification) is enforced by plain Python. My triage and review agents are read-only *because the prompt says so*. I know that's the weakest guarantee in the system, and I treat it that way.

**2. Never let the doer grade its own homework.** Codex's "success" is a claim. The verifier is a different program that checks facts.

**3. Use AI for judgement, not for bookkeeping.** My first instinct was to make everything an "agent." The most reliable parts ended up as the most boring ones.

**4. Make the human step tiny, but never zero.** One tap per change is little enough that I actually do it. Removing it would save me two minutes a week and cost me the ability to say "no, not tonight."

**5. A risk reviewer is worth more than I expected.** Withdrawing my own careless approval of a one-way database migration paid for the whole AI layer on day one.

**6. Small, boring bugs cost the most time.** A missing `< /dev/null`. Two processes overwriting the same state file. A label I forgot to remove. Not one of my problems was "the AI was too dumb." All of them were plumbing.

**7. Check your existing automation.** My "auto-updater" had been doing nothing for months, and I only found out because I built something to replace it.

---

## What's next

- **Separate identities per agent** in GitLab. Right now every agent comments as the same bot user.
- **Mechanically enforced read-only mode** for the triage and review agents, instead of trusting the prompt.
- **Detecting new version tags** for pinned images (`postgres:16` → `postgres:17`). Today it only catches rebuilds of the same tag.
- **Network isolation** for the agent container. It currently sits on the same VLAN as everything else, which is the biggest remaining gap.

If you're thinking about building something like this: start with the guardrails, not the AI. Once the approval gate, the backups and the independent checks exist, plugging in an AI agent is the easy part, and it's what makes the system feel less like a script and more like a colleague.

---

*Built with OpenAI Codex CLI, Claude Code, Proxmox VE, GitLab CE, Discord and a lot of Python. Total human input per change: one emoji.*
