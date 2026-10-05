#!/usr/bin/env python3
"""Publish blog posts from the Obsidian vault to the Clustered Thoughts Jekyll (Minimal Mistakes) site.

A vault post is published only when its front matter has `publish: true`.
Set `slug:` to control the URL (/posts/<slug>/). Future-dated posts are committed but only appear once their
date has passed (Jekyll `future: false` + the daily scheduled build).

Usage:
  python scripts/sync_obsidian.py                 # sync
  python scripts/sync_obsidian.py --dry-run       # preview
  python scripts/sync_obsidian.py --push          # sync, commit and push
  python scripts/sync_obsidian.py --file <path>   # convert one file regardless of status
"""
import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
POSTS = REPO / "_posts"
VAULT = Path(r"C:\Users\herms\OneDrive\Obsidian Vault\Hermes's Life Knowledge Base\07 HomeLab Things\Homelab Blog Posts")
BASEURL = "/Clustered-Thoughts"
CALLOUTS = {"note": "info", "info": "info", "abstract": "info", "tip": "success", "success": "success",
            "warning": "warning", "caution": "warning", "danger": "danger", "bug": "danger", "error": "danger"}

FM_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n(.*)\Z", re.S)


def slugify(text):
    s = re.sub(r"[^a-z0-9\s-]", "", text.lower())
    return re.sub(r"-+", "-", re.sub(r"\s+", "-", s)).strip("-")


def fix_image(path):
    if not path:
        return path
    m = re.search(r"/images/([^/]+)$", path)
    return f"/assets/img/posts/{m.group(1)}" if m else path


def as_list(v):
    if v is None:
        return []
    if isinstance(v, str):
        return [x.strip() for x in v.strip("[]").split(",") if x.strip()]
    return [str(x) for x in v]


def convert_callouts(body):
    """Obsidian `> [!NOTE] Title` blocks -> Minimal Mistakes notices (`<div class="notice--info">`)."""
    lines, out, i = body.split("\n"), [], 0
    while i < len(lines):
        m = re.match(r"^>\s*\[!(\w+)\][+-]?\s*(.*)$", lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        kind = CALLOUTS.get(m.group(1).lower(), "info")
        block = [f"**{m.group(2).strip()}**", ""] if m.group(2).strip() else []
        i += 1
        while i < len(lines) and lines[i].startswith(">"):
            block.append(re.sub(r"^>\s?", "", lines[i]))
            i += 1
        out += [f'<div class="notice--{kind}" markdown="1">', ""] + block + ["", "</div>"]
    return "\n".join(out)


def transform(text, source_name=""):
    m = FM_RE.match(text.lstrip("\ufeff").replace("\r\n", "\n"))
    if not m:
        raise ValueError(f"{source_name}: no front matter")
    fm = yaml.safe_load(m.group(1)) or {}
    body = m.group(2)
    title = str(fm.get("title") or Path(source_name).stem)
    date = fm.get("date") or fm.get("publish_date") or fm.get("created") or dt.date.today()
    date = date if isinstance(date, (dt.date, dt.datetime)) else dt.date.fromisoformat(str(date)[:10])
    slug = fm.get("slug") or slugify(title)
    desc = fm.get("description") or fm.get("summary") or ""
    cats = [(c.upper() if len(c) <= 3 else c.title()) if c.islower() else c
            for c in as_list(fm.get("categories"))][:2] or ["Homelab"]
    tags = sorted({t.lower() for t in as_list(fm.get("tags")) if not t.startswith(("type/", "status/"))})
    cover = fm.get("cover") or {}
    image = fix_image(cover.get("image") if isinstance(cover, dict) else None) or fix_image(fm.get("image"))
    alt = (cover.get("alt") if isinstance(cover, dict) else "") or title

    body = re.sub(rf"^\s*#\s+{re.escape(title)}\s*\n", "", body, count=1)
    body = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", body)
    body = re.sub(r"\[\[([^\]]+)\]\]", r"\1", body)
    body = re.sub(r"\]\(/Clustered-Thoughts/images/", "](/assets/img/posts/", body)
    # Minimal Mistakes doesn't prefix baseurl in post bodies, so make internal links absolute
    body = re.sub(r"\]\(/assets/", f"]({BASEURL}/assets/", body)
    body = re.sub(r"\]\(\.\./([a-z0-9-]+)/(#[\w-]+)?\)", rf"]({BASEURL}/posts/\1/\2)", body)
    body = convert_callouts(body)

    out = {"title": title, "date": f"{date:%Y-%m-%d} 09:00:00 +0800", "categories": cats, "tags": tags}
    if desc:
        out["description"] = out["excerpt"] = " ".join(str(desc).split())
    if image:
        out["header"] = {"overlay_image": image, "overlay_filter": 0.6, "teaser": image, "image_description": alt}
    out["render_with_liquid"] = False  # code samples contain {{ }} (docker/go templates)
    front = yaml.safe_dump(out, sort_keys=False, allow_unicode=True, width=1000)
    return f"{date:%Y-%m-%d}-{slug}.md", f"---\n{front}---\n\n{body.lstrip()}"


def should_publish(text):
    m = FM_RE.match(text.lstrip("\ufeff").replace("\r\n", "\n"))
    if not m:
        return False
    fm = yaml.safe_load(m.group(1)) or {}
    return fm.get("publish") is True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--push", action="store_true")
    ap.add_argument("--file", action="append", help="convert this file regardless of status")
    a = ap.parse_args()

    sources = [Path(f) for f in a.file] if a.file else [
        p for p in sorted(VAULT.glob("*.md")) if should_publish(p.read_text(encoding="utf-8"))]
    if not sources:
        print("Nothing to publish (set `publish: true` in a vault post's front matter).")
        return 0
    POSTS.mkdir(exist_ok=True)
    changed = []
    for src in sources:
        name, content = transform(src.read_text(encoding="utf-8"), src.name)
        dest = POSTS / name
        same = dest.exists() and dest.read_text(encoding="utf-8") == content
        print(f"{'unchanged' if same else ('would write' if a.dry_run else 'wrote')}: {src.name} -> _posts/{name}")
        if not same and not a.dry_run:
            dest.write_text(content, encoding="utf-8", newline="\n")
            changed.append(dest)
    if a.push and changed:
        subprocess.run(["git", "-C", str(REPO), "add", *map(str, changed)], check=True)
        subprocess.run(["git", "-C", str(REPO), "commit", "-m", f"Publish {len(changed)} post(s) from Obsidian"], check=True)
        subprocess.run(["git", "-C", str(REPO), "push"], check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
