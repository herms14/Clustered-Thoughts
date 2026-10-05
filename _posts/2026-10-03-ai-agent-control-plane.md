---
title: Giving AI Agents a Control Plane for My Homelab (And the Cluster-Wide SSH Lockout I Caused Getting There)
date: 2026-10-03 09:00:00 +0800
categories:
- Homelab
- AI
tags:
- ai
- automation
- claude
- helios
- homelab
- proxmox
- security
description: Notes on designing safe access for Codex agents to my Proxmox cluster, rediscovering an API I'd forgotten I built, and the cluster-wide root SSH lockout I caused with one bad shell redirect.
render_with_liquid: false
---

> This post is about the access layer I'm building so AI agents can work on my Proxmox cluster without me handing them my root keys. It covers the design, moving an old API I'd forgotten about into its own container, and an outage I caused in the middle of it. The agents themselves come later, in my post on [automating patch management with Codex](../codex-homelab-patch-management/).

I've been using Claude Code on this homelab for months now (I wrote about how that started in [How AI Became My Infrastructure Co-Pilot](../how-ai-became-my-infrastructure-co-pilot/)). It reads my Obsidian vault, SSHes into whatever needs fixing, and keeps my docs up to date. Lately I've been thinking about the next step: a container running several OpenAI Codex agents, each looking after one part of the lab (monitoring, the media stack, the network) and working on its own more than a single assistant I watch turn by turn.

The first question was whether that's even a good idea. I think it is, but only if I'm careful about what they can access. This cluster has already leaked credentials into a public repo twice. Giving a handful of unattended agents SSH keys and API tokens is not something I want to make up as I go.

This post is my notes from building that access layer. It turned into finding a tool I'd forgotten I built, moving it somewhere sensible, and, thanks to one badly quoted shell command, locking myself out of root SSH on all three Proxmox nodes at once. All in one evening.

## The Plan

Before touching anything, I asked Claude Code to help me sketch out how access should work. The main idea is that agents never talk to hosts directly. Everything goes through one API in the middle, and each side of it uses limited credentials.

```
┌─────────────────────────────────────────────────────────────┐
│  agent-runner VM (own VLAN, default-deny ACL)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Codex agent A │  │ Codex agent B │  │ Codex agent C │     │
│  │ own container, │ │ own container,│  │ own container,│     │
│  │ own scoped key │ │ own scoped key│  │ own scoped key│     │
│  └──────┬────────┘  └──────┬────────┘  └──────┬────────┘     │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          ▼                  ▼                  ▼
   One control-plane API (role-checked, logged)
          ▼
   Proxmox / Synology / Omada (role-scoped tokens, not root)
```

The parts I'd most regret skipping, roughly in order:

1. **Separate credentials per agent, with different levels.** An "observer" that can only read status and an "operator" that can restart things, each issued per agent. Not a copy of my own admin key.
2. **Approval for anything destructive.** I already have a Discord bot that asks me to approve container updates with a reaction, so the plan is to reuse that instead of building a second approval system.
3. **Network rules that actually limit access.** My own workstation has a rule letting it reach every VLAN. That's handy for me, and it's exactly what the agents shouldn't get. They get a short allow-list instead.
4. **No secrets in the git-tracked vault.** After the leaks, this one wasn't up for debate.

None of this is new. It's the same reason you don't give the intern the root password, except this intern runs at 3 AM with nobody watching.

## I Had Already Built Half of It

This part made me laugh. When I went looking for somewhere to put that middle API, I found I already had one. Back in August I'd built a FastAPI and CLI tool that puts Proxmox, Synology, and my Omada controller behind one authenticated REST API, and then completely forgot about it. It wasn't a stub either. It had token auth, retries on 401s, and task polling. I'd called it **Helios**, deployed it in a Docker container on my Ansible box, and never looked at it again.

When I checked, `docker ps` said it was `unhealthy`, so I assumed it had died months ago. It hadn't. The healthcheck was calling `curl`, and `curl` was never installed in the image. The app itself had been answering requests the whole time.

```yaml
# before: healthcheck fails because curl doesn't exist in the image
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]

# after: uses Python, which is already in the python:3.12-slim image
healthcheck:
  test: ["CMD", "python3", "-c",
    "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"]
```

> If `docker ps` and the container logs disagree, believe the logs. A healthcheck is just another command, and it can be wrong too.
{: .prompt-tip }

The thing I took from this: a tool nobody is watching slowly rots, whether it's healthy or not. If Helios is going to be what the agents talk to, it needs to live somewhere I'll notice when it stops responding.

## Moving Helios to Its Own LXC

Having Helios share a general-purpose box with Ansible was fine when I was the only one using it, and only occasionally. For something unattended agents depend on, I wanted it on its own LXC.

The only real decision was whether to keep Docker. There's an open issue in my lab where Docker inside an unprivileged LXC can't create new containers, because the LXC drops a capability Docker needs. Helios is one FastAPI app with a few dependencies and doesn't need Docker at all. So I went with an unprivileged LXC, a Python venv, and a systemd service. No privileged container, no capability workarounds.

```ini
[Unit]
Description=Helios API
After=network.target

[Service]
Type=simple
User=hermes-admin
WorkingDirectory=/home/hermes-admin/helios
EnvironmentFile=/home/hermes-admin/helios/.env
ExecStart=/home/hermes-admin/helios/venv/bin/python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
Restart=on-failure
```

I copied the code over as a tarball, since it had never been pushed to GitHub and had just been sitting on disk for four months. Then I built the venv and enabled the service. It came up on the first try, and I shut down the old Docker container. About fifteen minutes of actual work.

Except it took a lot longer than fifteen minutes, because of what happened in between.

## How I Locked Myself Out of My Own Cluster

To set up the new LXC I needed to put an SSH key in it. I ran something like this, which went through four layers of shell: PowerShell, then SSH, then `pct exec`, then bash.

```
pct exec 210 -- bash -c "echo '$pub' > /root/.ssh/authorized_keys"
```

The quoting got mangled somewhere along the way. The `>` redirect ran on the Proxmox node itself instead of inside the container, and it wiped the node's `/root/.ssh/authorized_keys` to an empty file.

I figured that was annoying but limited to one node. It wasn't. On Proxmox, `/root/.ssh/authorized_keys` on every node is a symlink to `/etc/pve/priv/authorized_keys`, which is one file shared across the whole cluster. So I hadn't broken root SSH on one node. I'd broken it on all three at the same time.

> **It wasn't as bad as it looked**
> The cluster itself was fine the whole time. `pvecm status` showed full quorum, and none of the VMs or LXCs noticed anything. I'd lost my usual way in, but nothing was actually down. It helps to check that before panicking.
{: .prompt-info }

The way back in was the Proxmox web console, since that doesn't need SSH. That had its own problems. Pasting into the console kept mangling multi-line commands. I got stray characters, quote prompts that wouldn't close, and one `echo` that quietly wrote an empty file. What finally worked was opening `nano` and pasting the key straight into the editor, so the shell never had a chance to mess with the quoting.

```bash
# didn't work reliably when pasted into the console:
printf '%s\n' "ssh-ed25519 AAAA..." > /etc/pve/priv/authorized_keys

# did work:
nano /etc/pve/priv/authorized_keys
# (paste the key line, Ctrl+O, Ctrl+X)
```

Once I switched to `nano`, root SSH was back on all three nodes within a few minutes. No data lost and nothing on the cluster affected. It was a good reminder of how much damage one `>` can do when it runs somewhere other than where you think.

I'm changing two things because of it:

1. **No more pushing file contents through nested shell quoting.** I'll write the file locally and copy it in with `scp` or `pct push`. The annoying part is I'd already done exactly that earlier the same evening for a different file, and then didn't bother this time.
2. **An offline backup of that shared key file.** It didn't have one, so getting back in depended entirely on the console working. There's now a copy somewhere outside the git repo.

## Finishing the Move

After that, the rest went smoothly:

* A `hermes-admin` user with the key that actually works. My credentials doc listed a different one, because a key rotation months ago never fully happened and I never updated the doc.
* Passwordless sudo, the same as the rest of my machines.
* The venv, the systemd service, the switchover, and shutting down the old container.

Within the hour I'd tested it against live cluster data.

I also wanted to use the CLI from my desktop without SSHing in first. Then I hit the same problem I'd apparently hit in August and forgotten: pip on this Windows machine fails a TLS handshake with PyPI's CDN. It happens system-wide, and plain `curl.exe` shows it too. It was 11 PM and I didn't want to debug Windows TLS, so I wrapped the remote CLI in a PowerShell function instead:

```powershell
function helios {
    $remoteArgs = $args -join ' '
    ssh -i $heliosKey hermes-admin@192.168.40.14 "cd ~/helios && ./venv/bin/helios $remoteArgs"
}
```

Now `helios compute nodes` works from any terminal on my desktop. It's really just SSH under the hood, but it means I have a usable command today instead of a perfect one someday.

## What's Still Missing

The move is done. Most of the security work isn't:

| Done | Still open |
|---|---|
| Helios on its own unprivileged LXC | The Proxmox token Helios uses still has full privileges |
| Runs under systemd instead of Docker-in-LXC | There's one Helios API key shared by everything, no per-agent keys yet |
| Tested against live cluster data | The network segment for the agent VM isn't built |
| A short CLI command on my desktop | Agents aren't hooked into the Discord approval flow yet |

So I spent an evening building a home for the control plane and confirming it works. I haven't built the parts that make it safe to point an unattended agent at it. Those are two separate jobs, and treating them as one is how people end up giving a bot their root key because the demo worked.

## Final Thoughts

None of the individual tasks were hard. Fixing a healthcheck, moving a service to an LXC, writing a systemd unit: each one is ten minutes. Most of my time went into the gap between "I checked this a while ago" and "I know this is true right now." Helios wasn't down, my credentials doc was wrong, and I misjudged how bad things were twice in one evening. I thought the SSH mistake was smaller than it was, and I thought Helios was more broken than it was.

When I get to actually wiring Codex agents into this, I want to keep the boring habits. Copy files in instead of echoing them through three shells. Check things instead of trusting what I remember. The design held up fine that evening. My shell command didn't.
