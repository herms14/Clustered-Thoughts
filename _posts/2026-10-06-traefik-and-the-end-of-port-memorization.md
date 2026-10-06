---
title: Traefik and the End of Port Memorization
date: 2026-10-06 08:08:00 +0800
categories:
- Homelab
- Containerization Deep-Dives
tags:
- homelab
- reverse-proxy
- ssl
- traefik
description: For a while I accessed everything by IP and port, from a text file of mappings I kept updating. Grafana at one IP and port, the dashboard at another, Proxmox at a third. This scales exactly as poorly as it sounds — you...
excerpt: For a while I accessed everything by IP and port, from a text file of mappings I kept updating. Grafana at one IP and port, the dashboard at another, Proxmox at a third. This scales exactly as poorly as it sounds — you...
render_with_liquid: false
---

For a while I accessed everything by IP and port, from a text file of mappings I kept updating. Grafana at one IP and port, the dashboard at another, Proxmox at a third. This scales exactly as poorly as it sounds — you mistype a port, or you share a link and remember the recipient can't reach an internal IP anyway.

A reverse proxy gets you real hostnames instead: `grafana.hrmsmrflrii.xyz`. Clean, shareable, and SSL comes along for free.

---

Traefik wasn't the first thing I tried. Nginx Proxy Manager has a friendlier UI but felt limiting the moment I wanted anything non-standard. Caddy's config is elegant but its Docker integration felt less mature at the time. Traefik ended up the right balance of power and complexity, and it's been through two major version bumps since (v3.2 up to v3.7.12 as of the last upgrade pass) without needing to rethink the setup underneath it.

Configuration splits into static (entry points, providers — rarely touched) and dynamic (routes, services — changed constantly, picked up live with no restart). I use file providers rather than Docker labels specifically so routing configuration lives in one place I can grep, instead of scattered across every service's compose file. The tradeoff is remembering to add the route by hand when something new gets deployed; worth it for me.

---

Let's Encrypt integration is the actual killer feature. Before this, SSL meant running certbot, cron jobs for renewal, copying certs to the right place by hand. Now a certificate resolver handles it automatically for every new route, renewal included — I genuinely haven't thought about certificate expiry as a manual task in over a year, and I've got Prometheus scraping Traefik's own metrics endpoint specifically so a *failed* renewal shows up as an alert instead of a browser error someone notices first.

---

Middleware handles the cross-cutting stuff — auth, headers, IP rules — defined once and attached to whatever routes need it. The one I use constantly is ForwardAuth into Authentik: any route with that middleware gets checked against Authentik before the request reaches the backend at all. Not logged in, you get redirected to login. Logged in, the request proceeds with your identity attached as a header. Chaining middleware (IP allowlist, then auth, then security headers) means order matters — whitelist-before-auth means a trusted IP can bypass login entirely, which is sometimes exactly what you want and sometimes a mistake you don't notice until later.

Backend services with self-signed certs — Proxmox and PBS both ship with one by default — need `insecureSkipVerify: true` on a server transport, or Traefik just refuses the connection. Less secure in the abstract; acceptable in practice when both ends are mine and the alternative is standing up real certs for internal-only services for no real security gain.

---

DNS is the other half. Internally, Pi-hole resolves every `*.hrmsmrflrii.xyz` subdomain straight to Traefik's IP. Externally, Cloudflare handles the public records, proxied for DDoS protection and IP masking, with port forwarding on the edge router sending inbound traffic to Traefik. Anything that shouldn't be reachable from outside just never gets the external record — no extra mechanism needed, the absence of a DNS entry is the access control.

Traefik also feeds its traces into an OTEL collector and Jaeger, at 100% sample rate via OTLP HTTP. That's more observability than a homelab strictly needs, and I keep it anyway because when a route *is* misbehaving, having the actual request trace instead of a guess is the difference between a five-minute fix and an hour of poking at logs.

---

Adding a service is five steps and about five minutes once you've done it a dozen times: deploy it somewhere, point a DNS entry at Traefik, add the router/service block to the dynamic config, wait for the certificate to issue (a minute or two, no intervention), done.

The dashboard — sitting behind Authentik itself, not publicly reachable — is worth keeping around for exactly this kind of troubleshooting. If a route doesn't show up there at all, the problem is config. If it shows up and errors, the problem is the backend. That distinction alone has saved real debugging time.

---

What I'd still change: separating internal-only and external routes more explicitly from the start, rather than managing the distinction purely through "did I add a DNS record or not." It works, but it's implicit in a way that's one mistake away from exposing something that shouldn't be exposed.

---

*This is the ninth post in a series about building and maintaining a homelab. The next post covers Authentik, and why I eventually stopped managing a password for every single service I run.*
