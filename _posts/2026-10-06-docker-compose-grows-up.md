---
title: Docker Compose Grows Up
date: 2026-10-06 08:07:00 +0800
categories:
- Homelab
- Containerization Deep-Dives
tags:
- compose
- containers
- docker
- homelab
description: My first Docker Compose file was one giant YAML document with everything in it — monitoring, reverse proxy, media stack, all sharing one network, all starting and stopping as a unit. That was fine until I wanted to...
excerpt: My first Docker Compose file was one giant YAML document with everything in it — monitoring, reverse proxy, media stack, all sharing one network, all starting and stopping as a unit. That was fine until I wanted to...
render_with_liquid: false
---

My first Docker Compose file was one giant YAML document with everything in it — monitoring, reverse proxy, media stack, all sharing one network, all starting and stopping as a unit. That was fine until I wanted to restart one container without taking down everything else with it.

---

The fix was splitting by service: each application gets its own directory, its own `docker-compose.yml`, under `/opt/<service>/`. That raises the obvious question of how containers in separate compose files reach each other — the answer is an external network, created once (`docker network create proxy`) and referenced by name from every compose file that needs it. Containers on it reach each other by container name regardless of which file started them.

Environment variables deserved more respect than I gave them early on. Hardcoding values into `docker-compose.yml` is expedient and then becomes a problem the first time you need to change something without editing a file that might end up committed somewhere. The pattern that actually works: a per-service `.env`, never committed, templated in by Ansible at deploy time, referenced from the compose file as `${VARIABLE_NAME}`. The secret lives in the environment, never in a file that could end up in git — which, given this repo's actual history with exactly that mistake in a different file, is not a theoretical concern for me.

---

Health checks changed how I think about startup ordering. `depends_on` alone only waits for a container to *start*, not for whatever's inside it to actually be ready — Postgres can be running and still mid-initialization while the app that needs it fails anyway. Defining a real health check (`pg_isready` for Postgres, an HTTP endpoint for most everything else) and pairing it with `depends_on: condition: service_healthy` fixes that properly. Writing a good check takes more thought than writing a bad one — it has to verify the service is actually functional, not just that a process exists — but the reliability gain is worth it. Services come up in the right order, consistently, without a race.

Resource limits stop one container from starving the rest of a host. I started generous and tightened based on what cAdvisor actually showed me using — Grafana runs fine on far less than I'd initially given it. Setting tight limits before you've watched real usage just produces confusing failures; watch first, tighten second.

Logging limits prevent a quieter failure mode: a verbose service filling the disk over months because Docker's default is to keep logs forever. I've lost a VM's root disk to exactly this. `max-size` and `max-file` on the `json-file` driver fixes it, and for a homelab, `json-file` plus SSH-and-grep is genuinely enough — centralized log aggregation is nice to have, not necessary at this scale.

---

The directory shape that stuck:

```
/opt/<service>/
├── docker-compose.yml
├── .env
├── config/      # mounted read-only
└── data/        # persistent, mounted read-write
```

It repeats with minor variation across every service I run, and the consistency is the point — when something's wrong, I already know config is in `config/` and data is in `data/`, which removes one more thing I have to figure out mid-incident.

---

Updates used to be my biggest unresolved rough edge here, and the honest update is that it's mostly resolved now, just not the way I originally expected. I tried Watchtower with Discord-approval gating for a while. It's now explicitly retired — not because it broke, but because I'd already built a Discord bot (Sentinel, covered a few posts from now) whose update-check cog does the same gated reaction-approval flow via direct SSH, across every host, with one less moving part than running Watchtower *and* a bot on top of it. And separately, GitOps actually happened: a GitLab CI/CD pipeline with a shell-executor runner, where a `git push` to the services repo's main branch triggers a deploy via SSH. I didn't fully commit to that when I wrote the first draft of this post. I have now, for the pieces that benefit from it — not everything does, and Compose by hand is still how most day-to-day changes happen.

---

Compose has a real ceiling — rolling updates across replicas, autoscaling, health-based traffic shifting are Kubernetes territory, not Compose territory. I know, because I ran a nine-VM Kubernetes cluster on this exact hardware for a few months specifically to learn where that line is, and decommissioned it once I had. For a single-host, non-scaling, "just needs to reliably run" workload — which is most of what a homelab actually needs — Compose is enough. I'm running it across roughly thirty containers today, and the overhead of that scale is manageable precisely because the patterns above are consistent everywhere.

---

*This is the eighth post in a series about building and maintaining a homelab. The next post covers Traefik, and the specific afternoon I stopped memorizing ports.*
