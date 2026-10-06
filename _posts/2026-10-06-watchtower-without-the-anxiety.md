---
title: Watchtower Without the Anxiety
date: 2026-10-06 08:17:00 +0800
categories:
- Homelab
- Automation & Bots
tags:
- discord
- homelab
- updates
- watchtower
description: Watchtower's default mode makes me nervous, and I think it should make most people running it on anything they'd miss nervous too.
excerpt: Watchtower's default mode makes me nervous, and I think it should make most people running it on anything they'd miss nervous too.
render_with_liquid: false
---

Watchtower's default mode makes me nervous, and I think it should make most people running it on anything they'd miss nervous too.

The pitch is appealing on its face: watch containers for new images, pull them, recreate the container, done — infrastructure that stays current without you touching it. The part that pitch leaves out is *when*. "Without intervention" means a breaking change can deploy at 3 AM, and you wake up to something broken with no record of what changed or how to get back to what worked.

## Monitor-only, plus a webhook, instead

```yaml
watchtower:
  image: containrrr/watchtower
  environment:
    - WATCHTOWER_MONITOR_ONLY=true
    - WATCHTOWER_NOTIFICATION_URL=http://argus-bot:5050/webhook
```

Watchtower still checks on its usual schedule. When it finds an update, instead of applying it, it fires a webhook — to Argus, the Discord bot from the last post — which turns that webhook into something I can act on instead of something that already happened.

## The approval flow, end to end

The webhook lands, Argus posts an embed — container name, current tag, available tag — with Approve and Skip buttons. Approve pulls the image and recreates the container over SSH. Skip just dismisses it.

```python
class UpdateApprovalView(discord.ui.View):
    @discord.ui.button(label="Approve", style=discord.ButtonStyle.green)
    async def approve(self, interaction, button):
        ...
```

Buttons expire after 24 hours. An unanswered update isn't lost — Watchtower will surface it again on the next scan — but it also doesn't apply itself just because I didn't respond fast enough.

## Scheduling the check, not just the update

```yaml
environment:
  - WATCHTOWER_SCHEDULE=0 0 8 * * *  # 8 AM daily
```

Checking at 8 AM means update notifications land when I'm actually around to look at them, not at 3 AM when the only outcome of a webhook firing is a notification nobody sees until it's already been hours. Staggering across container groups — infra in the morning, media in the afternoon — spreads the review load instead of dumping everything into one Discord channel at once.

## Rollback is manual, and I've made peace with that

When an update turns out bad, I need the previous tag. Watchtower's notification includes it, so I note it down before approving anything. If something breaks, the fix is editing the compose file back to the old tag, pulling, restarting — entirely by hand.

That's not sophisticated. A real rollback strategy would pin versions, keep manifests, run regression tests automatically. For a homelab where most updates are fine and real breakage is rare, manual rollback clears the bar. What wouldn't clear the bar is automatic updates where I never even captured what the previous version *was* — monitor-only guarantees I always have that one piece of information when I need it.

## Some containers don't go through this at all

Traefik, Authentik, and the database backends get updated by hand, after I've actually read the changelog — a breaking change in auth middleware can lock me out of everything downstream of it, and that's worth the friction of doing it deliberately.

```yaml
services:
  traefik:
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

The label removes it from Watchtower's awareness entirely. It gets updated through my normal maintenance process, not the automated one.

## What the week actually looks like

1. Check Discord
2. See a handful of update notifications in `#container-updates`
3. Open each, skim what changed — sometimes that means the GitHub release notes, not just the tag number
4. Approve what's obviously safe
5. Skip or defer anything that needs more thought
6. Deferred updates get a reminder, so they don't just quietly disappear

Most weeks, most updates get approved on sight — minor bumps, security patches, nothing that reads as risky. Maybe once a month something gets deferred because it needs an actual look before I'm comfortable.

## Why the extra step is worth it

I always know what's running and exactly when it last changed. When something breaks, "what changed recently" is a short, specific list, not a guess across however many containers are running unattended. This is more overhead than plenty of homelabs want, and that's a fair trade for someone else to make differently. For me, knowing the current state of my own systems was worth giving up the convenience of fully automatic updates.

---

*This is the eighteenth post in a series about building and maintaining a homelab. Next: GitOps, and turning a twenty-step manual deployment into one YAML file and a git push.*
