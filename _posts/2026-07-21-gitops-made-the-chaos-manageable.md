---
title: GitOps Made the Chaos Manageable
date: 2026-07-21 08:00:00 +0800
categories:
- Homelab
- Automation & Bots
tags:
- automation
- cicd
- gitlab
- gitops
- homelab
description: 'Deploying a new service used to be roughly twenty manual steps: SSH to the Docker host, make directories, write the compose file, start it. SSH to the Traefik host, edit the routing config, restart. SSH to Pi-hole, add...'
excerpt: 'Deploying a new service used to be roughly twenty manual steps: SSH to the Docker host, make directories, write the compose file, start it. SSH to the Traefik host, edit the routing config, restart. SSH to Pi-hole, add...'
render_with_liquid: false
---

Deploying a new service used to be roughly twenty manual steps: SSH to the Docker host, make directories, write the compose file, start it. SSH to the Traefik host, edit the routing config, restart. SSH to Pi-hole, add a DNS record. Open Authentik's web UI, create a provider and an application by hand. SSH to wherever Glance's config lives, add a dashboard entry, restart that too. Test. Realize something's missing. Spend thirty minutes figuring out which of the five systems has the stale piece.

Four SSH sessions, two web UIs, and none of it in version control. When something broke, I reconstructed the configuration from memory, which is a bad place to be reconstructing anything from.

## The target: one YAML file, one `git push`

```yaml
service:
  name: "metube"
  description: "YouTube downloader"

deployment:
  target_host: "docker-media"
  port: 8082
  image: "ghcr.io/alexta69/metube:latest"

traefik:
  enabled: true
  subdomain: "metube"

dns:
  enabled: true

authentik:
  enabled: true

glance:
  enabled: true
  group: "Downloads"
```

Write that, push it, and a pipeline does the other nineteen steps.

## How it's actually built

Self-hosted GitLab (`gitlab.hrmsmrflrii.xyz`), with a shell executor runner rather than the Docker executor. Specifically because the runner already has network-level SSH access to everything it needs to touch, and a shell executor can just use that directly instead of needing credentials passed into a throwaway build container.

The pipeline runs ten stages: detect changed files, validate the YAML against a schema, show the deployment plan, deploy the containers over SSH, configure Traefik, create the DNS record, configure Authentik, update the Glance dashboard entry, verify with a health check, and post a Discord notification. Each stage only proceeds if the previous one succeeded; the Discord notification is allowed to fail without blocking anything, since a missed notification is an inconvenience and a blocked deploy over it would be worse.

## Only deploying what actually changed

```python
changed_files = subprocess.run(
    ['git', 'diff', '--name-only', 'HEAD~1', 'HEAD'],
    capture_output=True, text=True
)
services_to_deploy = [f for f in changed_files if f.startswith('services/')]
```

Changing one service's YAML redeploys that one service. Everything else stays untouched, which is both the speed win and the safety win: a typo in one file can't accidentally redeploy forty other stable services it has nothing to do with.

## Schema validation catches the error before it becomes an incident

```json
{
  "required": ["service", "deployment"],
  "properties": {
    "service": {
      "required": ["name", "description"],
      "properties": {
        "name": {"pattern": "^[a-z][a-z0-9-]*$"}
      }
    }
  }
}
```

That name pattern isn't pedantic for its own sake. A service name flows downstream into a DNS record, a file path, and a container name, and an invalid character in any of those shows up later as a confusing failure in a completely different stage. Catching it in validation means the error message says "bad service name," not "mysterious DNS failure forty seconds into deploy."

## The bugs that actually happened while building this

The pipeline ran zero jobs for a confusing while because the trigger rules matched `main` and the repo's default branch was `master`. YAML parsing broke because inline Python embedded in a YAML block had colons that looked like YAML key-value syntax to the parser. Deploys failed with permission denied because writing under `/opt` needs sudo even for a user who can otherwise do most things. A port conflict showed up because nothing checked what was already listening before handing out a port number.

Every one of these had an easy fix once I knew what it was. The annoying part was always the gap between "something's wrong" and "I know what."

## Bash gave way to Python, and the pipeline got much easier to debug

Early versions had inline bash with embedded Python strings, and YAML's colon-as-syntax collided with Python's colon-as-syntax constantly. Quote escaping across three layers of string became genuinely impossible to reason about.

```python
def deploy(service_yaml):
    with open(service_yaml) as f:
        cfg = yaml.safe_load(f)

    compose = build_compose_file(cfg)
    ssh_deploy(cfg['deployment']['target_host'], compose)
```

Pulling the logic into standalone Python files that the CI config just calls fixed all of it at once: testable independently, no escaping, real error handling instead of a bash script failing silently three layers deep.

## What deploying a service looks like now

```bash
vim services/downloads/metube.yml
git add services/downloads/metube.yml
git commit -m "Add MeTube YouTube downloader"
git push
```

Two minutes later it's live at `metube.hrmsmrflrii.xyz`: DNS resolved, Traefik routing, Authentik in front of it, a Glance entry already there. One push, every downstream system updated consistently.

## It paid for itself fast

Roughly eight hours to build the pipeline, two more fixing the bugs above, four writing it up so I wouldn't have to re-derive any of this later. Against that: every deployment since has taken two minutes instead of thirty, lives in version control, and is reproducible from Git history if anything ever needs reconstructing.

The bar for "should this go through GitOps" keeps dropping. It started as new services only. Then Grafana dashboards. Then Traefik routes directly. More of the homelab routes through Git over time, because the pattern keeps paying for itself and the marginal cost of adding one more thing to it is small.

---

*This is the nineteenth post in a series about building and maintaining a homelab. Next: giving Claude a task queue, so a session that runs out of context doesn't also lose the thread of what we were doing.*
