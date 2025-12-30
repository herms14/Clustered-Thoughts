---
title: "How AI Became My Infrastructure Co-Pilot"
date: 2025-12-27
draft: false
description: "How Claude Code accelerated my homelab journey by 10x - real examples, workflows, and lessons learned"
tags: ["homelab", "ai", "claude", "automation", "devops"]
categories: ["homelab"]
author: "Hermes Miraflor II"
---

It all started with frustration.

When I started building my homelab seriously in late 2024, I was already using ChatGPT occasionally for coding questions and architectural decisions. Need to decide between a monolithic Docker Compose stack or splitting services across multiple hosts? Ask the AI to weigh the tradeoffs. Unsure whether to expose a service via Cloudflare Tunnels or a self-hosted reverse proxy? Get a breakdown of security implications in seconds.

But something shifted when I discovered Claude Code - an AI that could actually see my terminal, read my files, and execute commands with my permission.

The first time it debugged a Prometheus query that had been frustrating me for hours, I realized this was not just a fancy autocomplete. It was a genuine collaborator. One that never got tired, never judged my mistakes, and never forgot a syntax pattern once it had seen my codebase.

That moment changed how I approached every homelab project that followed.

---

## What AI Does Well

### 1. Instant Technical Sounding Board

Before AI, I would spend hours on Reddit, Stack Overflow, and technical documentation trying to understand why something was not working. The feedback loop was slow: post a question, wait for responses, try the suggestions, post again when they did not work. With complex infrastructure issues, this cycle could stretch across days.

Now I can describe the problem in plain English and get targeted suggestions immediately. The AI can read my configuration files, check my logs, and propose solutions based on my actual setup rather than generic advice.

**Real example from my session logs:**

> "Glance container can't reach my Media Stats API on localhost:5054"

Claude immediately identified the issue: Docker containers have isolated network namespaces. `localhost` inside the container refers to the container itself, not the host machine. The container was trying to connect to itself, not to the API running on the Docker host.

The fix was straightforward once you understood the problem: use `172.17.0.1` (the Docker bridge gateway IP) instead of `localhost`. This allows the container to route traffic back to the host machine where the API was actually running.

That debugging session took 5 minutes. Without AI, it might have taken hours of Googling "Docker container localhost connection refused" and wading through dozens of Stack Overflow answers before finding the relevant one.

### 2. Pattern Recognition Across Codebases

One of the most underrated capabilities of AI assistants is their ability to recognize and replicate patterns from your existing code. This is not about generating boilerplate from scratch. It is about maintaining consistency as your codebase grows.

When I needed to add a new Discord bot to my homelab management suite, Claude could examine my existing bot implementations (Argus for container monitoring, Mnemosyne for media notifications) and generate a new one that followed the same conventions:

- Same logging format with timestamps and severity levels
- Same channel restriction checks to prevent commands in wrong channels
- Same error handling patterns with user-friendly messages
- Same configuration structure using environment variables
- Same Docker Compose patterns for deployment

This kind of consistency is tedious to maintain manually but trivial for an AI that can see all your code at once.

### 3. Documentation That Stays In Sync

Documentation rot is one of the biggest challenges in any infrastructure project. You make a change, forget to update the docs, and three months later you are staring at outdated instructions wondering why nothing works.

My homelab documentation exists in three places:

| Location | Purpose | Audience |
|----------|---------|----------|
| `docs/` folder | Technical reference with exact commands | Future me debugging at 2 AM |
| GitHub Wiki | Beginner-friendly explanations | Anyone following along |
| Obsidian Vault | Personal notes including credentials | Me only, synced via OneDrive |

Claude helps keep these synchronized. When I make a change, it can update all three locations following the established conventions I have documented. A single service deployment might require updating `docs/SERVICES.md`, the wiki's service catalog page, and my personal Obsidian notes with any new credentials.

#### The CLAUDE.md System

This synchronization only works because I invested time in creating a `CLAUDE.md` file at the root of my repository. Think of it as an instruction manual for any AI that works on my codebase. It contains:

- **Infrastructure overview**: IP addresses, network topology, service locations
- **Documentation locations**: Where each type of documentation lives and how they differ
- **Conventions**: Naming patterns, file structures, commit message formats
- **Protected configurations**: Things that should never be modified without explicit permission
- **Multi-session workflow**: How to pick up work from previous sessions

Here is the critical insight: **Claude does not remember anything between sessions.** Every time I start a new conversation or run out of context tokens, it is a fresh start. The CLAUDE.md file solves this by giving every new session immediate access to the full context of my infrastructure.

#### Multi-Session Continuity

Beyond CLAUDE.md, I maintain several context files in a `.claude/` directory:

```
.claude/
├── active-tasks.md     # Work currently in progress
├── session-log.md      # Recent session history
├── conventions.md      # Standards and patterns
└── context.md          # Detailed infrastructure reference
```

When I start a new session, Claude reads these files first. If a previous session ran out of tokens mid-task, the `active-tasks.md` file contains:

- What was completed
- What remains to be done
- Specific instructions for resuming

This system means I can spin up multiple Claude instances in different terminal windows, or come back the next day after token exhaustion, and pick up exactly where I left off. The AI essentially "remembers" through documentation rather than persistent memory.

### 4. Learning Accelerator

Complex infrastructure concepts used to require hours of reading documentation, watching tutorials, and trial-and-error experimentation. Topics like:

- Prometheus relabeling and metric transformation
- Traefik middleware chains and ForwardAuth flows
- Authentik provider configuration and group mappings
- Terraform state management and module patterns

I understand these faster when I can ask "why does this work?" and get an explanation tailored to my specific configuration. Not a generic tutorial, but an explanation that references my actual files.

#### Tutorial Generation for Future Reference

Beyond real-time explanations, I have developed a habit of asking Claude to generate detailed tutorials for complex deployments. These get stored in my Obsidian vault under a dedicated folder.

For example, after deploying Authentik with Traefik ForwardAuth, I asked Claude to document the entire process step-by-step. The resulting tutorial includes:

- Prerequisites and dependencies
- Exact configuration files with inline comments
- Common gotchas and how to avoid them
- Verification steps to confirm everything works
- Troubleshooting section for known issues

Six months from now, when I need to modify the setup or replicate it, I have a complete reference written by the same AI that helped me build it originally. The tutorial reflects my exact infrastructure, not some generic guide that might use different directory structures or network configurations.

---

## Real Debugging Sessions

Let me share some actual debugging sessions that demonstrate how AI-assisted troubleshooting works in practice.

### The DNS Resolution Mystery

After deploying several VMs via Terraform, I noticed something strange: some containers could resolve internal DNS names while others could not. The same queries would work from one VM but fail from another, even though they were on the same network segment.

I described the symptoms to Claude:

> "docker-utilities can resolve gitlab.hrmsmrflrii.xyz but docker-media gets NXDOMAIN"

The debugging process was methodical:

1. **Check the basics**: Both VMs had the same `/etc/resolv.conf` pointing to my Pi-hole DNS server at `192.168.90.53`. That ruled out configuration drift.

2. **Test DNS directly**: Using `dig` from both hosts showed the same results - the DNS server was responding correctly to both.

3. **Check Docker's DNS**: Here was the problem. Docker containers use their own DNS resolution, configured in `/etc/docker/daemon.json`. On docker-media, this file was missing, so Docker was using its default DNS servers (Google's 8.8.8.8) instead of my internal DNS.

4. **The fix**: Create the daemon.json file with the correct DNS settings and restart Docker:

```json
{
  "dns": ["192.168.90.53"]
}
```

The whole session took about 10 minutes. Without AI, I might have spent hours checking firewall rules, VLAN configurations, or network ACLs before realizing the problem was Docker-specific.

### The Path Mismatch Nightmare

Jellyfin showed an empty media library even though Radarr and Sonarr reported that movies and TV shows were successfully downloaded. The files existed on disk, but Jellyfin could not see them.

This one was a classic homelab gotcha involving Docker volume mounts and hardlinks.

**The symptoms:**
- Radarr logs showed successful downloads and imports
- Files existed in `/downloads/movies/` on the host
- Jellyfin library scan found nothing
- Storage usage seemed higher than expected

**Root cause**: The ARR stack was configured with inconsistent paths. Download clients saved to `/downloads/movies`, but Radarr's root folder was set to `/data/media/movies`. These were different Docker volume mounts pointing to different host directories.

This matters because the ARR applications use hardlinks to "move" completed downloads to the media library instantly without copying data. Hardlinks only work within the same filesystem. My configuration had downloads on one mount and media on another, making hardlinks impossible.

Claude helped me redesign the entire path structure:

```
/data/
├── torrents/
│   └── movies/     # Download client saves here
└── media/
    └── movies/     # Radarr root folder, same filesystem
```

With a unified `/data` mount shared across all containers, hardlinks work correctly and storage usage dropped by 40% (no more duplicate files).

### The GitLab 403 Forbidden

My Chronos Discord bot suddenly could not close GitLab issues. The error was frustratingly vague: `403 Forbidden`.

This is where AI debugging really shines - it can systematically eliminate possibilities:

**Step 1: Verify token validity**
```bash
curl -H "PRIVATE-TOKEN: $TOKEN" https://gitlab.example.com/api/v4/user
```
Result: Token was valid, returned user information.

**Step 2: Check token scopes**
The token had `api` scope, which should allow full API access including issue management.

**Step 3: Check project membership**
```bash
curl -H "PRIVATE-TOKEN: $TOKEN" https://gitlab.example.com/api/v4/projects/2/members
```
Found the issue! The token belonged to one user, but the project only listed a different user as a member.

**The fix**: Add the correct user to the project via GitLab's rails console:

```ruby
user = User.find_by(username: 'myuser')
project = Project.find(2)
project.add_member(user, :maintainer)
```

Total debugging time: 15 minutes. The systematic approach eliminated dead ends quickly.

---

## What AI Cannot Do

Understanding AI limitations is just as important as leveraging its strengths. Here is what I have learned about the boundaries.

### 1. Access External Services Directly

Claude cannot log into my Proxmox web UI, click through Authentik's admin panel, or interact with any service that requires a browser or graphical interface. For those tasks, I still need to:

- Take screenshots and share them for analysis
- Describe what I see on screen
- Execute the suggested changes manually

This means configuration that lives in web UIs (like Omada Controller policies or Grafana dashboard layouts) requires more back-and-forth than file-based configuration.

### 2. Make Judgment Calls About Architecture

AI can present options with tradeoffs, but certain decisions require understanding my specific context:

- **Growth trajectory**: Will this homelab stay small or expand to 10 nodes?
- **Time investment**: Do I want to learn Kubernetes properly or just get something working?
- **Risk tolerance**: How much downtime is acceptable during upgrades?
- **Complexity budget**: Am I willing to maintain this in 2 years?

Claude can help me think through these questions, but the final call is always mine. Architecture decisions that seem equivalent on paper often have very different long-term implications.

### 3. Know What Changed Outside Our Conversation

If I manually SSH into a server and edit a configuration file, Claude does not know until I tell it or ask it to read the file again. There is no persistent awareness of my infrastructure state.

This is why the `CLAUDE.md` and `.claude/` documentation system matters so much. The AI's "memory" exists entirely in files that I maintain. When those files are accurate and up-to-date, Claude can work effectively. When they drift from reality, problems arise.

#### How CLAUDE.md Grows Over Time

My CLAUDE.md file started as a simple list of IP addresses and service URLs. Over months of collaboration, it has evolved into a comprehensive infrastructure manual:

- New sections get added when patterns emerge (the "Protected Configurations" section came after I accidentally broke a Grafana dashboard)
- Troubleshooting tips get documented after painful debugging sessions
- Conventions get formalized when inconsistencies cause problems

Every few weeks, I review the file and update it based on what has changed. This maintenance takes about 30 minutes but saves hours of re-explaining context in future sessions.

### 4. Replace Understanding

The biggest trap is accepting AI suggestions without understanding them. Early on, I would copy-paste commands and configurations without knowing why they worked. This created two problems:

1. When things broke, I could not debug them myself
2. I was not actually learning, just following instructions

Now I have developed specific habits:

#### Ask for Explanations Before Execution

Before Claude runs any non-trivial command, I ask it to explain what the command does and why. For example:

> "Before running that iptables command, explain what each flag does and what will change on my system"

This slows things down slightly but ensures I understand what is happening. If the explanation reveals something I did not expect, I can ask questions before making changes.

#### Verify Against Official Documentation

For anything security-related or anything I have not seen before, I verify Claude's suggestions against official documentation. AI can hallucinate command flags that do not exist or configuration options that were deprecated years ago.

#### Build Mental Models

Instead of just fixing the immediate problem, I try to understand the underlying system well enough to fix similar problems myself. If Claude explains that Docker containers have isolated network namespaces, I make sure I understand what that means and why it matters, not just the specific IP address to use.

---

## My Workflow

After months of iteration, here is the workflow that works best for me:

```
1. Start fresh session or resume from active-tasks.md
2. Describe the problem or goal in plain language
3. Let Claude investigate (read files, check logs, explore)
4. Discuss proposed solutions - ask "why" questions
5. Review any commands before execution
6. Implement together, verifying each step
7. Update session-log.md with what was done
8. Update relevant documentation (all three locations)
9. Mark task complete in active-tasks.md
```

This workflow transforms a solo homelab project into pair programming with an infinitely patient partner. The documentation steps at the end ensure that knowledge accumulates rather than getting lost when the conversation ends.

---

## The Multiplier Effect

Here is a concrete accounting of what I have built with AI assistance over the past month:

| Category | Items | Notes |
|----------|-------|-------|
| Discord Bots | 4 | Argus (monitoring), Mnemosyne (media), Chronos (tasks), Athena (AI queue) |
| Grafana Dashboards | 5 | Proxmox cluster, Synology NAS, Omada network, Container status, Traffic analysis |
| Custom APIs | 4 | Media Stats, Reddit integration, NBA Stats, Life Progress widget |
| Documentation Pages | 25+ | Technical references, wiki pages, personal notes |
| Ansible Playbooks | 15+ | Service deployments, configuration management, monitoring setup |
| Terraform Modules | 3 | VM provisioning, LXC containers, network configuration |

Would I have built all this without AI? Eventually, probably. But it would have taken 6 months instead of 3 weeks. The acceleration is not just about speed. It is about maintaining momentum. When every debugging session is quick, you stay motivated to tackle the next project. When problems drag on for days, you lose enthusiasm and the homelab stagnates.

---

## Common Pitfalls

### 1. Over-Reliance

If you cannot debug a basic problem without AI, you have not learned enough. I make a deliberate point to understand solutions before implementing them. Sometimes I will ask Claude to guide me through debugging manually rather than just giving me the fix.

The goal is augmented capability, not dependency.

### 2. Context Window Limits

Long conversations eventually hit token limits. When this happens, Claude loses access to earlier parts of the conversation and may forget important context. I have learned to:

- **Start fresh sessions for new problems** rather than continuing exhausted conversations
- **Reference documentation files** instead of re-explaining context verbally
- **Keep session logs** so the next Claude instance can read what happened before
- **Use the active-tasks.md file** as a handoff document between sessions

### 3. Hallucinated Commands

AI sometimes suggests commands that do not exist, flags that were deprecated, or configuration options that are not supported by my specific version. This happens more often with:

- Older or less common tools
- Version-specific features
- Platform-specific variations (Linux vs macOS commands)

I always verify unfamiliar commands against official documentation before running them, especially anything that modifies system configuration or could cause data loss.

### 4. Security Blindspots

AI assistants try to be helpful, which sometimes means they will include sensitive information in generated code or configuration files. I have learned to:

- Never commit AI-generated files without reviewing them for hardcoded secrets
- Use environment variables and secrets management instead of inline credentials
- Maintain a strong `.gitignore` to prevent accidental credential exposure

---

## The Future

The collaboration between homelabbers and AI is just beginning. Here is what I am exploring next:

### Local LLMs

Running language models locally on my RTX 4080 Super opens up possibilities:
- **Privacy**: Infrastructure queries stay on my network
- **Cost**: No API fees for routine questions
- **Customization**: Fine-tuning on my specific codebase and documentation

I am experimenting with 70B parameter models to understand what is possible with consumer hardware today.

### Agentic Automation

Current AI assistants require human approval for each action. The next frontier is autonomous agents that can:
- Monitor infrastructure and detect anomalies
- Propose and implement fixes with minimal oversight
- Chain together multi-step operations

My Athena bot is an early experiment here, queuing tasks for AI processing and tracking their status.

### Knowledge Graphs

Instead of flat documentation, imagine an AI that understands the relationships between your infrastructure components:
- "Show me everything that depends on the DNS server"
- "What will break if I restart the Traefik container?"
- "Trace the path from external request to database query"

This is harder than it sounds, but the payoff would be immense.

---

## Conclusion

AI has not replaced my need to understand infrastructure. If anything, it has amplified it. The better I understand my systems, the better I can collaborate with AI to extend them.

What AI has replaced is the tedious parts: searching through documentation, remembering syntax, maintaining consistency across files, and debugging common issues. That frees up mental energy for the interesting parts: architecture decisions, security design, and building things that actually matter to me.

The homelab has become a testbed for AI-augmented infrastructure management. Every experiment teaches me something new about both AI capabilities and infrastructure patterns. And every improvement to my documentation and workflow makes the AI more effective, creating a virtuous cycle.

If you are starting your own homelab journey, consider bringing an AI co-pilot along. Not as a replacement for learning, but as an accelerator. Build the documentation habits early. Keep session logs. Maintain your context files. The investment pays dividends every single day.

---

## What's Next

In the next post, I will cover **choosing your hypervisor** - why I went with Proxmox over ESXi and Hyper-V, and how to set up a proper cluster from scratch.

---

## Resources

- [Claude Code](https://claude.ai/code) - The AI assistant I use for infrastructure work
- [My GitHub Repository](https://github.com/herms14/Proxmox-TerraformDeployments) - Real session logs and documentation
