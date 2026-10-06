---
title: A Task Queue for Claude
date: 2026-07-28 08:00:00 +0800
categories:
- Homelab
- Automation & Bots
tags:
- ai
- automation
- homelab
- queue
description: 'Working with Claude Code surfaced a limitation fast: nothing persists between sessions. I''d be deep into something, run out of context, start fresh, and have to re-explain what we were doing and what was left, a...'
excerpt: 'Working with Claude Code surfaced a limitation fast: nothing persists between sessions. I''d be deep into something, run out of context, start fresh, and have to re-explain what we were doing and what was left, a...'
render_with_liquid: false
---

Working with Claude Code surfaced a limitation fast: nothing persists between sessions. I'd be deep into something, run out of context, start fresh, and have to re-explain what we were doing and what was left, a handoff that depended entirely on my own memory of the previous session, which is exactly the kind of thing I'm bad at recalling precisely.

A task queue fixed this. Tasks live in a database, not in my head. Claude reads the queue at the start of a session. Completed tasks get marked done; new ones get added. The context transfer happens through storage instead of through me trying to remember.

## Deliberately minimal architecture

SQLite for storage, a small Flask API for CRUD, a Discord bot (Athena) as the interface. No more structure than the job needs.

```python
class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    description = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='pending')
    priority = db.Column(db.String(20), default='medium')
    submitted_by = db.Column(db.String(50))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    completed_at = db.Column(db.DateTime, nullable=True)
```

Status moves `pending → in_progress → completed`. Priority is low/medium/high/urgent. That's the entire data model, and it's been enough. Every time I've been tempted to add structure, it's turned out the flat model was fine and the extra structure wouldn't have been used.

## The Discord side is the actual interface

`/task add "Update Grafana dashboards for new metrics"` creates one. `/task list` shows what's pending. `/task complete 42` marks it done. Low friction on purpose. If adding a task requires thinking about syntax, tasks stop getting added, and the whole system quietly stops being used.

Athena also posts to `#claude-tasks` whenever something's created or completed, so the channel itself becomes a readable history without me ever running a query.

## Claude reads the queue through a context file, not the database directly

At session start, Claude reads an `active-tasks.md` file in my Obsidian vault that reflects the queue's current state, updated automatically whenever a task's status changes. Claude sees what's in progress, what's pending, what finished recently, before we've exchanged a single message about it.

This isn't sophisticated integration. It's a file that gets rewritten and a model that reads files at the start of a session. But "not sophisticated" and "doesn't work" are different things, and this one works.

## What a session actually starts like now

Before: *"What were we doing? I think it was something with the monitoring stack? What's left?"*

After: *"Active tasks show monitoring-stack work in progress, three subtasks remain: deploy the new dashboard, update alert rules, verify metrics are actually flowing."*

The state lives outside both of us. It doesn't matter whether I remember correctly, because the queue isn't relying on my memory in the first place.

## Edges I had to think through

**A session ends mid-task.** The task just stays `in_progress`. The next session sees that and decides whether to pick it back up or flag it for a second look. Nothing special happens automatically, which is fine; it's one more thing for the next session to notice, not a crash.

**Concurrent sessions.** I don't actually run more than one Claude session against this project at a time, so I haven't built locking for it. If that stopped being true, this would need real locking, and right now it doesn't have any.

**Subtasks and dependencies.** Not implemented, on purpose. Tasks are flat; anything genuinely complex gets split into independent tasks instead of one task with children. Simpler system, at the cost of not being able to express "B can't start until A finishes." Acceptable so far.

## Multiple entry points, one source of truth

I can add a task by editing `active-tasks.md` directly, through a Discord slash command, or by just telling Claude to add one mid-session. All three write to the same queue. Different interfaces for different moments, but the queue itself is the only place the data actually lives.

## What I'd build differently with hindsight

Task templates: a lot of what gets added follows the same three or four shapes ("deploy X," "update Y dashboard," "investigate Z"), and a template would pre-fill the boilerplate and keep naming consistent instead of ad hoc.

Real search: finding an old completed task today means scrolling, not querying, and full-text search would turn "how did I solve this last time" from a chore into a lookup.

Timestamps on status transitions, not just creation and completion. Right now I genuinely don't know how long tasks actually take, because the data was never captured.

None of those gaps have been painful enough to fix yet. The current system clears the bar it needs to clear, and that's been enough reason to leave it alone.

---

*This is the twentieth post in a series about building and maintaining a homelab. Next: backups, and the specific test that proved most of mine weren't actually backups until I ran it.*
