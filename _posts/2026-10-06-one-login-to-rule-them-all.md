---
title: One Login to Rule Them All
date: 2026-10-06 08:09:00 +0800
categories:
- Homelab
- Containerization Deep-Dives
tags:
- authentik
- homelab
- security
- sso
description: Every self-hosted service wants its own password. Before long you're either reusing passwords across all of them — a slow-motion security problem — or maintaining a spreadsheet of unique ones, which is cognitive...
excerpt: Every self-hosted service wants its own password. Before long you're either reusing passwords across all of them — a slow-motion security problem — or maintaining a spreadsheet of unique ones, which is cognitive...
render_with_liquid: false
---

Every self-hosted service wants its own password. Before long you're either reusing passwords across all of them — a slow-motion security problem — or maintaining a spreadsheet of unique ones, which is cognitive overhead with no real upside.

Single sign-on fixes this properly: one identity provider, one login, services trust that provider instead of managing their own accounts.

---

I landed on Authentik after looking at the usual alternatives. Authelia is lighter and handles ForwardAuth well, but its OIDC support felt like an afterthought bolted onto a simpler tool. Keycloak is the enterprise default, but it's Java, resource-heavy, and its documentation assumes enterprise concepts I don't have a use for at home. Authentik landed in the middle: a modern UI, flexible flows, solid Traefik integration, and documentation that actually answers the question I have. It's not light — Postgres, Redis, and two server components — but for the thing every other service trusts, that resource cost is the right place to spend it.

Rather than build out local accounts with their own TOTP/WebAuthn setup, I wired Authentik to Google OAuth as the actual upstream identity source, tied to one Google account. MFA, in practice, is whatever Google already enforces on that account — I'm not managing a second MFA system on top of a first one, I'm delegating the whole problem upstream to someone whose job is specifically that problem.

---

The two patterns that matter are ForwardAuth and OIDC, and they solve different problems. ForwardAuth works with literally anything, no service-side changes required — Traefik asks Authentik "is this authenticated," forwards or redirects based on the answer, and the backend service never even needs to know Authentik exists. OIDC is cleaner where it's supported — Grafana, GitLab, Proxmox all have native OIDC config, register as an application, exchange secrets, and the user gets an actual "Login with Authentik" button with group/role information passed through to the app itself. ForwardAuth can pass identity as headers too, but only services that bother to respect those headers get anything useful out of it.

Getting ForwardAuth working cleanly took more trial and error than the docs suggested it should — redirect URLs need to match exactly, cookie domains need to be correct, CORS needs to permit the right origin. When something's wrong the failure modes are confusing (redirect loops, a 403 with no obvious cause, a session that silently doesn't persist), and I've learned to check Authentik's own logs first, every time, because they tend to name the actual problem directly instead of making me guess from the symptom.

---

Groups are what make access control actually scale. Rather than configuring per-user access on every application, users join a group and applications grant access by group membership — add someone to the right group and they're in everywhere that group has access, remove them and they're out everywhere at once. New people and departing access both become one action instead of N.

---

Backup matters more here than almost anywhere else in the stack, because if Authentik is down, everything gated behind ForwardAuth is unreachable too — a single point of failure I introduced deliberately, in exchange for not managing a dozen separate logins. I export the blueprint configuration regularly, and the database backs up with everything else via PBS. I've intentionally torn down and rebuilt Authentik from backup at least once, specifically to confirm the recovery path actually works rather than trusting that it would. Discovering a backup doesn't restore cleanly is much better during a planned test than during an actual outage.

I upgraded Authentik from 2025.10.3 to 2026.8.0 in the same pass as a Traefik version bump — version drift on the thing that gates every other login is not something I want to let run long.

---

What surprised me, honestly, is how much this changes daily use rather than just security posture. Opening any service behind it just works — I'm already authenticated from earlier in the day, switching between a dozen services has zero login friction, and guest access for friends who want Jellyfin is "create an account, add to the right group, done" instead of a per-service conversation.

Not every service plays along. A few don't support OIDC well, or at all, and for those ForwardAuth is the fallback — the service doesn't get identity information, but at least it's not reachable by anyone who hasn't authenticated first. Not elegant, acceptable.

---

*This is the tenth post in a series about building and maintaining a homelab. The next post covers the media stack — Radarr, Sonarr, and the Jellyfin setup that made this whole project worth it to the rest of the household.*
