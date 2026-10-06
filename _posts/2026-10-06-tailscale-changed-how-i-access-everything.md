---
title: Tailscale Changed How I Access Everything
date: 2026-10-06 08:23:00 +0800
categories:
- Homelab
- Advanced Topics
tags:
- homelab
- tailscale
- vpn
- zero-trust
description: 'Traditional VPN: stand up a server, open firewall ports, distribute certificates, hope NAT traversal cooperates. Tailscale: install the agent, sign in, connect. That''s actually it.'
excerpt: 'Traditional VPN: stand up a server, open firewall ports, distribute certificates, hope NAT traversal cooperates. Tailscale: install the agent, sign in, connect. That''s actually it.'
render_with_liquid: false
---

Traditional VPN: stand up a server, open firewall ports, distribute certificates, hope NAT traversal cooperates. Tailscale: install the agent, sign in, connect. That's actually it.

The simplicity felt suspicious at first — I kept waiting for the catch. A year in, the closest thing to a catch is that I still don't fully understand the magic under the hood. It just works, reliably, which is its own kind of unsettling when you're used to VPNs being the thing that breaks.

## What's actually doing the work

WireGuard handles the encrypted tunnels themselves — fast, modern, minimal attack surface, well-audited. Tailscale sits on top handling the genuinely hard parts: key distribution, NAT traversal, and the coordination servers that figure out *how* two devices should talk — directly if a path exists, through a relay if it doesn't. Every device gets a stable `100.x.x.x` Tailscale IP that survives network changes entirely; my laptop's address is identical at home, in a coffee shop, or on hotel wifi.

## The use case that sold me

Before Tailscale, remote access meant either exposing something to the open internet or maintaining a traditional VPN server and hoping my ISP didn't throttle the protocol. With Tailscale, every device on the tailnet is just addressable from every other device:

```bash
# from a coffee shop, no port forwarding, nothing exposed
ssh root@100.89.33.5  # node01
```

That's node01's real Tailscale IP — the same one I'd use sitting on my own couch. No exposed service, no VPN server to patch, works through NAT and restrictive networks without me doing anything extra.

**Subnet routing** extends that reach to devices that don't run the Tailscale agent at all. `node01` advertises the homelab's internal networks — `192.168.20.0/24` (infrastructure) and `192.168.40.0/24` (services) — so from any tailnet device I can reach, say, the Synology NAS at `192.168.20.32` as if I were plugged into the local switch, even though the NAS itself has never heard of Tailscale. One agent, the entire homelab reachable.

> `192.168.20.32`, not `.31` — the NAS has two NICs and the `.31` one has been dead for months. It's an easy IP to mistype from memory since the device itself still answers on `.32` fine; I've caught myself reaching for the wrong one more than once.

**Split DNS** is what makes internal hostnames survive the trip. I pointed Tailscale's DNS config for `hrmsmrflrii.xyz` at my Pi-hole (`192.168.90.53`), so `https://grafana.hrmsmrflrii.xyz` resolves correctly whether I'm home (DNS resolves locally) or remote (the query goes out over Tailscale to Pi-hole, which hands back the internal IP, and traffic routes back through the subnet router). Same URL, everywhere — the routing underneath just adapts.

## ACLs, once "allow everything" stopped being enough

The default tailnet policy lets every device reach every other device, which is fine for a solo setup. The moment other people are on the tailnet, that's too loose:

```json
{
  "acls": [
    { "action": "accept", "src": ["group:admins"], "dst": ["*:*"] },
    { "action": "accept", "src": ["group:family"], "dst": ["synology:*", "jellyfin:*"] }
  ]
}
```

Admins get everything; family members get exactly the NAS and the media server, nothing else. The policy lives in Tailscale's admin console and takes effect immediately — no agent restart, no propagation delay to account for.

**Exit nodes** cover the rare case where I want *all* traffic routed through the homelab (showing up at my home IP for something geo-restricted, mostly). Flip it on in the admin console, select it client-side, done. I use this maybe once a quarter, but it's there.

## A genuinely different trust model, not just a more convenient VPN

A traditional VPN builds a perimeter — once you're in, you're trusted, and compromising one device inside that perimeter gets an attacker network-wide reach. Tailscale doesn't work that way: device A reaching device B says nothing about whether A can reach C, because ACLs mediate every connection individually rather than granting blanket access to "inside." That's the zero-trust principle in practice — assume the network itself is hostile, authenticate and authorize per-connection, and stop treating network location as a proxy for trust.

## What I'd actually flag before you adopt this

- **You're trusting Tailscale's coordination infrastructure.** Hasn't failed me in a year, but it's a dependency I didn't have before, and it's a single point of failure I don't control.
- **Debugging gets a layer more abstract.** When something's unreachable, is it Tailscale, the subnet router, or the destination service itself? Isolating the actual failure means understanding the full path traffic takes, not just pinging the endpoint.
- **Check the free-tier limits against your actual use case** before you build a workflow that assumes they won't matter — fine for a household, worth reading the fine print for anything bigger.

Caveats aside, Tailscale replaced my entire remote-access strategy outright. I spend zero time maintaining VPN infrastructure now, and "can I reach this from outside the house" stopped being a question I have to think about.

---

*This is the twenty-fourth post in a series about building and maintaining a homelab. The next post covers disaster recovery that actually works.*
