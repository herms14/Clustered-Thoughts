---
title: How AI Became My Infrastructure Co-Pilot
date: 2025-12-27 09:00:00 +0800
categories:
- Homelab
- Automation
tags:
- ai
- automation
- claude
- devops
description: How Claude Code sped up my homelab work, with real debugging sessions, the CLAUDE.md setup, and the limits I've learned to respect
excerpt: How Claude Code sped up my homelab work, with real debugging sessions, the CLAUDE.md setup, and the limits I've learned to respect
cover: /assets/img/posts/ai-brain.jpg
article_header:
  type: overlay
  theme: dark
  background_color: '#123'
  background_image:
    gradient: linear-gradient(135deg, rgba(0, 0, 0, .7), rgba(0, 0, 0, .45))
render_with_liquid: false
---

> This post is about how I use Claude Code, an AI coding agent that runs in my terminal, to build and run my homelab. I cover what it's good at, a few real debugging sessions, the `CLAUDE.md` file that keeps it useful from one session to the next, and where it falls short. It follows on from my [origin story](/Clustered-Thoughts/posts/my-accidental-journey-into-homelabbing/), but you don't need to read that first.

When I started taking the homelab seriously in late 2024, I was already using ChatGPT now and then. I'd ask it things like whether to run one big Docker Compose stack or split services across hosts, or whether Cloudflare Tunnels made more sense than my own reverse proxy. Useful, but it was still me copying things back and forth.

Then I tried **Claude Code**, which can actually see my terminal, read my files, and run commands once I say yes. The first time it fixed a Prometheus query I'd been stuck on for hours, I realized this was a different kind of tool. It felt more like working with a colleague who never gets tired of my questions.

I've used it for almost every homelab project since. These are my notes on what that looks like day to day.

![Code and AI working together](/Clustered-Thoughts/assets/img/posts/code-screen.jpg)

## What It's Good At

### Getting Unstuck Quickly

Before this, troubleshooting meant Reddit, Stack Overflow, and a lot of documentation. Post a question, wait, try something, post again. For tricky infrastructure problems that could take days.

Now I describe the problem in plain English and Claude reads my actual configs and logs before suggesting anything. A real example from my session logs:

> "Glance container can't reach my Media Stats API on localhost:5054"

Claude pointed out that `localhost` inside a Docker container means the container itself, not the host, because containers get their own network namespace. Switching to `172.17.0.1` (the Docker bridge gateway) let the container reach the API on the host.

That took about five minutes. On my own, I'd probably have spent an hour digging through search results for "docker container localhost connection refused."

### Keeping Things Consistent

This one doesn't get talked about much. When I needed a new Discord bot, Claude looked at the ones I already had (Argus for container monitoring, Mnemosyne for media notifications) and wrote the new one the same way: same logging format, same channel restrictions, same error messages, same environment variables and Docker Compose layout.

I could do that by hand. It's just tedious, and I'd get it slightly wrong every time.

### Keeping the Docs Up to Date

Docs going stale is a constant problem. You change something, forget to update the notes, and three months later the instructions don't match reality.

My docs live in three places:

| Location | Purpose | Audience |
|----------|---------|----------|
| `docs/` folder | Technical reference with exact commands | Me, debugging at 2 AM |
| GitHub Wiki | Beginner-friendly explanations | Anyone following along |
| Obsidian vault | Personal notes, including credentials | Just me, synced via OneDrive |

When I deploy something new, Claude updates all three: `docs/SERVICES.md`, the wiki's service list, and my Obsidian notes. That only works because of one file.

## The CLAUDE.md File

Claude doesn't remember anything between sessions. Each new conversation starts from scratch, and so does every session that runs out of context.

If you take one thing from this post, it's this: the AI only knows what you've written down for it.
{:.info}

So I keep a `CLAUDE.md` at the root of my repo. It's basically an operating manual for any AI working on my infrastructure. It has my IPs and network layout, where each service runs, where each kind of doc goes, naming conventions, and commit message format.

There's also a "Protected Configurations" section listing things Claude must not change without asking me. I added that after accidentally breaking a Grafana dashboard.

The file started as a list of IPs and URLs. I add to it whenever something comes up that I don't want to explain twice, and every few weeks I spend half an hour cleaning it up. That half hour saves me a lot of repeating myself.

### Picking Up Where I Left Off

I also keep a few files in a `.claude/` folder:

```
.claude/
├── active-tasks.md     # Work currently in progress
├── session-log.md      # Recent session history
├── conventions.md      # Standards and patterns
└── context.md          # Detailed infrastructure reference
```

Claude reads these at the start of each session. If the last session ran out of tokens halfway through something, `active-tasks.md` says what got done, what's left, and how to continue. I can have a few Claude sessions open in different terminals, or come back the next day, and nothing gets lost.

### Tutorials for Later

After any complicated setup, I ask Claude to write it up as a step-by-step tutorial in my Obsidian vault. When I set up Authentik with Traefik ForwardAuth, for example, I ended up with prerequisites, the exact config files with comments, the gotchas, how to check it worked, and what to do when it doesn't.

Months later, when I need to change it, I have a guide written against my own setup instead of someone else's paths and networks.

## Some Real Debugging Sessions

### DNS Working on One VM but Not the Other

After deploying a few VMs with Terraform, containers on some of them could resolve internal names and others couldn't, even though they were on the same network.

> "docker-utilities can resolve gitlab.hrmsmrflrii.xyz but docker-media gets NXDOMAIN"

We went through it in order. Both VMs had the same `/etc/resolv.conf` pointing at my Pi-hole (`192.168.90.53`), so it wasn't a config difference. Running `dig` on both hosts gave the right answer, so the DNS server was fine.

The problem turned out to be Docker. Containers use Docker's DNS settings from `/etc/docker/daemon.json`, and on docker-media that file didn't exist, so Docker was falling back to Google's `8.8.8.8`. Creating the file and restarting Docker fixed it:

```json
{
  "dns": ["192.168.90.53"]
}
```

About ten minutes in total. I'm fairly sure I would have gone through firewall rules and VLAN ACLs first if I'd been on my own.

### The Empty Jellyfin Library

Jellyfin showed nothing, but Radarr and Sonarr said everything had downloaded and imported fine. The files were on disk, and I was using more storage than I expected.

Download clients were saving to `/downloads/movies`, while Radarr's root folder was `/data/media/movies`. Those were two separate Docker volume mounts pointing at different folders on the host. The ARR apps use hardlinks to "move" finished downloads without copying them, and hardlinks only work inside a single filesystem. So nothing could be linked, and some files ended up duplicated.

Claude helped me move everything under one shared mount:

```
/data/
├── torrents/
│   └── movies/     # Download client saves here
└── media/
    └── movies/     # Radarr root folder, same filesystem
```

With every container sharing `/data`, hardlinks started working, and my storage use dropped by about 40%.

### GitLab Returning 403

My Chronos Discord bot suddenly couldn't close GitLab issues and just got `403 Forbidden` back.

We checked the token first, and it was valid. It had `api` scope, which covers issues. Then we looked at the project members:

```bash
curl -H "PRIVATE-TOKEN: $TOKEN" https://gitlab.example.com/api/v4/projects/2/members
```

The token belonged to a user who wasn't a member of the project. Adding them from the GitLab rails console fixed it:

```ruby
user = User.find_by(username: 'myuser')
project = Project.find(2)
project.add_member(user, :maintainer)
```

Fifteen minutes, mostly because we ruled things out in a sensible order instead of guessing.

## Where It Falls Short

**It can't use web UIs.** Claude can't log into Proxmox or Authentik's admin page or click around in Grafana. For anything that only lives in a browser, I take screenshots, describe what I see, and make the change myself.

**It can't decide my architecture.** It can lay out the trade-offs. Only I know whether this lab is going to grow, how much time I want to spend on it, how much downtime I'm OK with, and whether I'll still want to maintain something in two years.

**It doesn't know what I changed by hand.** If I SSH in and edit a file myself, Claude has no idea until I tell it. This is the other reason the `CLAUDE.md` file matters so much.

**It can't do the understanding for me.** Early on I pasted commands without really knowing what they did. When something broke, I couldn't fix it, and I wasn't learning anything.

That last one changed how I work. Before Claude runs anything non-trivial, I ask it to explain what the command will do. For anything security-related or new to me, I check the official docs, because it does sometimes invent flags or suggest options that were removed years ago. And I try to understand why a fix works so I can handle the next one myself.

## How a Session Usually Goes

```
1. Start a fresh session, or resume from active-tasks.md
2. Describe the problem or goal in plain language
3. Let Claude investigate (read files, check logs, explore)
4. Talk through the proposed fix and ask why
5. Review any commands before they run
6. Implement together, checking each step
7. Update session-log.md with what was done
8. Update the docs (all three places)
9. Mark the task done in active-tasks.md
```

Steps 7 to 9 are the boring part, but they're why the next session goes smoothly.

## What I Got Done in a Month

![Dashboard showing infrastructure achievements](/Clustered-Thoughts/assets/img/posts/dashboard.jpg)

Here's roughly what I built with Claude's help in about a month:

| Category | Items | Notes |
|----------|-------|-------|
| Discord bots | 4 | Argus (monitoring), Mnemosyne (media), Chronos (tasks), Athena (AI queue) |
| Grafana dashboards | 5 | Proxmox cluster, Synology NAS, Omada network, container status, traffic analysis |
| Custom APIs | 4 | Media Stats, Reddit integration, NBA Stats, Life Progress widget |
| Documentation pages | 25+ | Technical references, wiki pages, personal notes |
| Ansible playbooks | 15+ | Service deployments, configuration management, monitoring setup |
| Terraform modules | 3 | VM provisioning, LXC containers, network configuration |

Could I have done this without AI? Probably, over six months or so instead of three weeks. The bigger difference for me was motivation. When problems get solved quickly, I want to start the next project. When something drags on for days, the whole lab stalls.

## Things to Watch Out For

**Leaning on it too much.** If I can't debug something basic without Claude, I haven't learned it yet. Sometimes I ask it to walk me through the debugging instead of just giving me the answer.

**Running out of context.** Long conversations lose their early details. I start new sessions for new problems, point Claude at docs instead of re-explaining things, and use `active-tasks.md` to hand over between sessions.

**Made-up commands.** This happens more with older or niche tools, version-specific features, and Linux vs. macOS differences. I check anything I don't recognize, especially if it could delete data.

**Secrets in generated files.** AI will put credentials inline if it thinks that's helpful. I review every generated file before committing, use environment variables, and keep a strict `.gitignore`.

Never commit an AI-generated file without checking it for hardcoded secrets first.
{:.error}

## If You Want to Try This

The most useful thing you can do is write your own `CLAUDE.md`. Mine started out looking something like this:

```markdown
# Homelab notes for AI assistants

## Infrastructure
- Hosts, IPs, and what runs where (keep this table current)

## Documentation
- docs/ = exact commands; wiki = beginner-friendly; vault = private notes
- When you change infrastructure, update all three

## Conventions
- Naming patterns, folder layout, commit message format

## Protected Configurations
- Never modify these without asking me first: ...

## Session Workflow
- At start: read .claude/active-tasks.md and .claude/session-log.md
- At end: update session-log.md and active-tasks.md
```

It doesn't have to be complete. Mine grew one annoying problem at a time.

## What I Want to Try Next

I'd like to run models locally on my RTX 4080 Super, partly for privacy and partly so routine questions don't cost anything. I'm testing 70B models to see how far consumer hardware gets.

I'm also interested in agents that do more on their own: watching the infrastructure, noticing when something's off, and proposing a fix (or making it). My Athena bot, which queues tasks for AI to process, is a first small step in that direction.

The idea I keep coming back to is an AI that understands how everything connects, so I could ask "what depends on the DNS server?" or "what breaks if I restart Traefik?" That's harder than it sounds, but I think it would be worth it.

## Final Thoughts

Using AI hasn't meant I need to understand my infrastructure less. It's actually the opposite. The better I know my own setup, the more useful Claude is. What it's taken off my plate is the tedious stuff: looking up syntax, keeping files consistent, and chasing down the same kinds of issues over and over. That leaves me more time for the parts I enjoy.

If you're starting a homelab, I'd bring an AI assistant along, just not as a replacement for learning. Write things down early. The better your notes, the better it works.

Next up is [choosing a hypervisor](/Clustered-Thoughts/posts/choosing-your-hypervisor-why-proxmox-won/), and why I went with Proxmox over ESXi and Hyper-V.

## Resources

* [Claude Code](https://claude.ai/code), the AI assistant I use for infrastructure work
* [My GitHub repository](https://github.com/herms14/Proxmox-TerraformDeployments), with real session logs and documentation
