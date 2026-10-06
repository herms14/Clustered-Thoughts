---
title: Discord Bots That Actually Help
date: 2026-07-07 08:00:00 +0800
categories:
- Homelab
- Automation & Bots
tags:
- automation
- bots
- discord
- homelab
- python
description: 'Discord is open on some device of mine basically all the time, work chat, gaming, project discussion, all in the same app. Which made the decision obvious once I''d framed it that way: if I want visibility into the...'
excerpt: 'Discord is open on some device of mine basically all the time, work chat, gaming, project discussion, all in the same app. Which made the decision obvious once I''d framed it that way: if I want visibility into the...'
render_with_liquid: false
---

Discord is open on some device of mine basically all the time, work chat, gaming, project discussion, all in the same app. Which made the decision obvious once I'd framed it that way: if I want visibility into the homelab, bring the information to where I'm already looking, instead of opening a browser tab or SSHing in just to check.

The first bot I wrote was a toy. It took three more rewrites before one was actually useful, and the rewrites taught me more than the first version did.

## What each failed version taught me

**Version one** answered static commands with information I could've looked up myself just as fast: technically working, practically pointless. **Version two** tailed logs and posted excerpts to Discord, which turned into noise fast, because most log lines don't matter and a bot that can't tell the difference just relays the noise faster. **Version three** wired up real API integrations with no approval step in between, which meant an automated action could fire with nothing standing between "detected" and "executed." That one scared me enough to rethink the whole approach before shipping a fourth.

What exists now is four purpose-built bots, each doing exactly one job:

- **Argus** watches for container updates and asks before applying anything
- **Mnemosyne** tracks media downloads and posts progress
- **Chronos** talks to GitLab for task tracking
- **Athena** runs a task queue for whichever AI assistant I'm pairing with that session

Each gets its own channel, and commands are rejected outside it, which does double duty: it stops command chaos, and it makes the channel itself a readable log. Opening `#container-updates` *is* the update history; I don't need a separate dashboard for it.

## The shape every bot shares

Python, `discord.py`, slash commands (not message-prefix commands, slash gets autocomplete and real parameter typing for free), and a channel guard on every command:

```python
def allowed_channel():
    async def predicate(interaction: discord.Interaction) -> bool:
        channel_name = interaction.channel.name.lower()
        for allowed in ALLOWED_CHANNELS:
            if allowed.lower() in channel_name:
                return True
        return False
    return app_commands.check(predicate)
```

`/downloads` in `#general` does nothing. The same command in `#media-downloads` returns the queue. One decorator, applied everywhere.

## Argus got genuinely valuable the moment it got a Watchtower webhook

Watchtower's default behavior is to pull and apply updates automatically, which is fine for a toy project and makes me nervous for anything load-bearing. So it runs in monitor-only mode instead, and when it finds an update, it posts a webhook to Argus rather than touching the container.

Argus turns that webhook into an embed (container name, current tag, available tag) with two buttons: Approve, Skip. Approve runs the actual update over SSH; Skip just dismisses it. Either way, a human decision happened before anything changed.

```python
class UpdateApprovalView(discord.ui.View):
    @discord.ui.button(label="Approve", style=discord.ButtonStyle.green)
    async def approve(self, interaction, button):
        result = await run_ssh_command(
            f"docker pull {self.image} && docker compose up -d"
        )
        await interaction.followup.send(f"Updated {self.container}")
```

This is the right amount of automation for my comfort level: updates stay visible, I control *when*, and the tedious part, checking for updates in the first place, is handled for me.

## Mnemosyne exists because four UIs for one question is too many

Radarr, Sonarr, and the download client each have their own interface, and "what's actually downloading right now" means checking all of them separately if you don't automate it away. Mnemosyne queries both *arr APIs, merges the results, and `/downloads` shows movies and episodes in progress with percentage and ETA in one place.

A background loop checks progress every two minutes and posts milestone notifications (50%, 80%, done) so `#media-downloads` tells me what finished without me ever opening an app to ask.

## The deployment pattern is not elegant, and I'm okay with that

```yaml
argus-bot:
  image: python:3.12-slim
  command: >
    bash -c "pip install discord.py aiohttp paramiko && python -u argus-bot.py"
  environment:
    - DISCORD_TOKEN=${ARGUS_DISCORD_TOKEN}
    - ALLOWED_CHANNELS=container-updates
```

Installing dependencies at container start instead of baking a real image is a shortcut I know is a shortcut. A proper Dockerfile would be cleaner and faster to start. But iteration speed won on this one, and each bot runs in total isolation from the others: its own token, its own channel list, its own container. If one crashes, the other three don't notice.

## The mistakes that cost real time

- **Slash commands don't appear until synced.** Forgetting `bot.tree.sync()` means the code is correct and Discord has simply never heard about it. No error, just commands that don't exist from the user's side.
- **Discord expects a response within three seconds.** Anything slower needs `interaction.response.defer()` first, or the interaction just times out with a generic failure that gives you no hint it was a timing issue.
- **Rate limits are real and strict.** Posting in a tight loop gets the bot throttled; batch updates instead of one message per event.
- **SSH from inside a container needs the key actually mounted in,** which means a volume or a secrets setup, not complicated, but not something you get by accident either.

## Why this is worth the overhead

The homelab used to require active checking: open a terminal, navigate, run a command, interpret the output. Now it mostly means noticing something in a channel I already have open for unrelated reasons. The information density is lower than a real dashboard, and the interaction is shallower than direct CLI access to anything. But the cost of checking dropped to roughly zero, and that turned out to matter more than density or sophistication ever did.

---

*This is the seventeenth post in a series about building and maintaining a homelab. Next: Watchtower, and why the version I actually run is the one that asks permission first.*
