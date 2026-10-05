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
description: Notes on designing secure access for Codex agents to manage my Proxmox cluster, discovering I'd already half-built the control plane months ago, and the cluster-wide root SSH lockout a bad shell command caused along the way.
render_with_liquid: false
---

I've been running Claude Code against this homelab for months now — it reads my Obsidian vault, SSHes into whatever needs fixing, and keeps the docs honest. Lately I've been thinking about the next step: a container running multiple OpenAI Codex agents, each handling a slice of the homelab (monitoring, media stack, network), working more autonomously than a single assistant I babysit turn by turn.

The obvious question came first: is that even a good idea? And the honest answer was "yes, but only if the access model is deliberate." Handing several autonomous agents SSH keys and API tokens to a cluster that's already had two credential-leak cycles into a public repo is not something to wing.

This post is my notes from actually building the access layer — which turned into rediscovering a tool I'd forgotten I'd built, relocating it, and, through a shell-quoting mistake, briefly locking myself out of root SSH on all three Proxmox nodes at once. All in one evening.

---

## The design, before any of this started

Before touching anything, I asked Claude Code to sketch the access model. The core idea: agents never talk to hosts directly. Everything goes through one mediation layer, with scoped credentials on either side of it.

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
   Proxmox / Synology / Omada — role-scoped tokens, not root
```

Four things made the actual difference, in order of how much I'd regret skipping them:

1. **Credential tiers, not one shared key.** An "observer" role that can only read status, and an "operator" role that can restart things — issued per agent, not copy-pasted from my own admin key.
2. **Route anything destructive through an approval gate.** Not new machinery — I already had a Discord bot (more on that below) with a reaction-approval flow for container updates. Reuse that instead of building a second approval system.
3. **Network segmentation that's actually least-privilege.** My admin workstation has a standing ACL rule granting it unrestricted access to every VLAN — convenient for me, and exactly the model agents should *not* get. A narrow, explicit allow-list instead.
4. **Secrets that never touch the git-tracked vault.** Given the repo's history, this one wasn't optional.

None of this is novel. It's the same shape as "don't give the intern the root password," just applied to something that runs unattended.

## I'd already built half of this, four months ago

Here's the part that actually made me laugh: when I went looking for where to put the mediation layer, I found out I already had one. Back in August I'd built — and apparently completely forgotten about — a FastAPI + CLI tool that wraps Proxmox, Synology, and my Omada controller behind one authenticated REST API. Real implementations, not stubs: proper token auth, retry-on-401, task polling. I'd named it Helios, deployed it in a Docker container on my Ansible box, and then just... never touched it again.

When I checked on it this session, `docker ps` reported it as `unhealthy`. My first assumption was that it had quietly died months ago. It hadn't — the healthcheck itself was broken (it shelled out to `curl` inside a container image that never installed `curl`), while the actual app had been serving requests the entire time. A few months of "is this thing even alive" anxiety, over a Dockerfile missing one package.

```yaml
# before — healthcheck fails because curl doesn't exist in the image
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]

# after — uses what's already in the python:3.12-slim base image
healthcheck:
  test: ["CMD", "python3", "-c",
    "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"]
```

> If a container's `docker ps` status and its actual logs disagree, trust the logs. A healthcheck is just another command that can be wrong, and it's usually the simpler thing to be wrong about.

Lesson filed away: a tool nobody's watching is a tool that's silently rotting, healthy or not. If Helios is going to be the thing Codex agents talk to, it needs a home I'll actually notice if it goes quiet.

## Giving it an actual home

Helios living alongside Ansible on a general-purpose box was fine when I was the only thing calling it occasionally. It's not fine as the control plane for unattended agents — that deserves its own dedicated LXC, not a roommate.

The one real decision here was Docker versus running it straight: this homelab has an open, unresolved bug where Docker-in-LXC fails to create new containers because unprivileged LXCs drop a capability Docker nesting needs. Helios is a single FastAPI app with modest dependencies — it doesn't need Docker at all. So: unprivileged LXC, plain Python venv, systemd unit. No capability dance, no privileged container, smaller blast radius if anything ever does go wrong with it.

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

Copied the code over (tarball, not `git clone` — it was never actually pushed to GitHub, just living on disk for four months), built the venv, enabled the service. Came up clean on the first try. Decommissioned the old Docker container. Fifteen minutes of real work.

Except it wasn't fifteen minutes, because of what happened in the middle.

## The part where I locked myself out of my own cluster

Bootstrapping the new LXC meant pushing an SSH key into it. I ran something shaped like this — a command through four layers of shell (PowerShell, over SSH, into `pct exec`, into bash):

```
pct exec 210 -- bash -c "echo '$pub' > /root/.ssh/authorized_keys"
```

The quoting broke across those layers. The redirect executed in the *hypervisor node's own shell*, not inside the container — and truncated the node's `/root/.ssh/authorized_keys` to zero bytes.

My first assumption was that this was annoying but contained: one node, one file, I'd fix it and move on. It was not contained. On Proxmox, `/root/.ssh/authorized_keys` on every cluster node is a symlink to `/etc/pve/priv/authorized_keys` — a single file synced cluster-wide by the Proxmox filesystem. I hadn't broken SSH to one node. I'd broken root SSH to all three, simultaneously, with one bad redirect.

> The cluster itself was never at risk — `pvecm status` showed full quorum the entire time. Corosync, the VMs, the LXCs, none of it even noticed. This was purely "the door I usually walk through is gone," not "the building is on fire." Worth knowing the difference before you panic.

Recovery needed the one channel that doesn't depend on SSH: Proxmox's browser-based console. And even that had its own small comedy of errors — the console's clipboard paste kept mangling multi-line commands (stray characters, hung quote-continuation prompts, one `echo` that silently wrote zero bytes instead of the key). What actually worked was dropping into `nano` and pasting the key directly into the editor, sidestepping shell quoting altogether.

```bash
# what didn't work reliably through the console paste:
printf '%s\n' "ssh-ed25519 AAAA..." > /etc/pve/priv/authorized_keys

# what did:
nano /etc/pve/priv/authorized_keys
# (paste the key line directly, Ctrl+O, Ctrl+X)
```

Root SSH came back on all three nodes within a few minutes of switching approaches. No data loss, no cluster impact — just an object lesson in exactly how much blast radius a single `>` can have when it's three shell layers away from where you think it's running.

The actual fix going forward is boring and correct: never pipe untrusted interpolation through more than one layer of shell quoting. Write the target content to a local file and copy it in — `scp`, or Proxmox's own `pct push` — instead of trying to get `bash -c "..."` to survive a round trip through PowerShell, SSH, and `pct exec`. I'd already used that safer pattern successfully earlier in the same session, for a completely unrelated file, and went around it anyway for this one. Consistency would have cost nothing.

There's a second, quieter finding in here too: that cluster-wide key file had no backup. One bad write and recovery depends entirely on console access being available. It's on the list now — an offline copy somewhere that isn't the git repo.

## Where it actually landed

Once the LXC itself was sorted, the rest was straightforward: `hermes-admin` with the real working key (not the one my own credentials doc claimed was current — turned out that doc had been wrong since a rotation months ago that apparently never actually completed), passwordless sudo matching the rest of the fleet, Python venv, systemd unit, cutover, decommission the old container. End to end verified against live cluster data within the hour.

I also wanted the CLI itself usable from my own desktop, not just over SSH — and hit the same wall I'd apparently hit back in August and forgotten about: pip installs on this Windows machine fail a TLS handshake against PyPI's CDN, system-wide, reproducible with plain `curl.exe`. Rather than debug Windows' TLS stack at 11pm, I wrapped the remote CLI in a one-line PowerShell function instead:

```powershell
function helios {
    $remoteArgs = $args -join ' '
    ssh -i $heliosKey hermes-admin@192.168.40.14 "cd ~/helios && ./venv/bin/helios $remoteArgs"
}
```

`helios compute nodes` now works from any terminal on my desktop, same as if it were installed locally. It's a proxy, not a real local install, and I know that — but it's the difference between a problem I solve tonight and a problem I solve never, and I'd rather have the short command today than a perfect one eventually.

## What's actually left before any Codex agent touches this

The relocation is done, but the *secure* part of "secure control plane" is still mostly unwritten:

| Done | Still open |
|---|---|
| Helios on its own dedicated, unprivileged LXC | Proxmox token behind Helios is still full-privilege, not role-scoped |
| Runs via systemd, not a Docker container with known capability issues | No per-agent credentials exist yet — there's one Helios API key, for everyone |
| Verified end-to-end against live cluster data | Network segmentation for an eventual agent-runner VM not built |
| Short CLI access from my desktop | Approval-gate wiring from agents into the existing Discord bot not done |

The honest summary: I spent an evening building the *host* for the control plane, and confirmed it works. I have not yet built the part that makes it safe to point an autonomous agent at. Those are different projects, and conflating them is exactly how you end up handing a bot your root key because the demo worked.

## Closing thoughts

None of the individual pieces here were hard. Fixing a healthcheck, moving a service to its own LXC, writing a systemd unit — any of these on their own is a ten-minute task. What actually cost time was the gap between "I checked this months ago" and "I know this is true right now" — Helios wasn't down, my credentials doc wasn't current, and my own assumption about blast radius was wrong twice in one session, in both directions (I underestimated the SSH incident's scope, and overestimated how broken Helios actually was).

If I take one thing into the next phase of this — actually wiring up Codex agents against it — it's that the boring safety habits (write to a file and copy it in, don't trust a cached assumption, verify instead of assume) matter more than the clever architecture around them. The architecture diagram survived the evening unchanged. My shell command did not.
