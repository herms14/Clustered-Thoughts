# Clustered Thoughts

> Notes on infrastructure, automation, and supervised AI.

Live at **https://herms14.github.io/Clustered-Thoughts/**

A homelab journal: Proxmox, self-hosting and automation, plus AI agents (OpenAI Codex, Claude Code) doing real work on real infrastructure, with a human in the loop.

## Stack

- [Jekyll](https://jekyllrb.com/) + [TeXt](https://github.com/kitian616/jekyll-TeXt-theme) (gem-based, `jekyll-text-theme`, `text_skin: dark`, `highlight_theme: tomorrow-night-blue`)
- GitHub Actions (`.github/workflows/pages-deploy.yml`) builds, link-checks (`htmlproofer`) and deploys to GitHub Pages
  - Push to `main` → build + deploy. Other branches → build + test only.
  - Daily 09:00 Asia/Manila scheduled build publishes future-dated posts once their date passes.

## Writing and publishing

Posts are written in Obsidian and converted by `scripts/sync_obsidian.py`. See [docs/PUBLISHING.md](docs/PUBLISHING.md).

```powershell
python scripts\sync_obsidian.py --dry-run   # preview
python scripts\sync_obsidian.py --push      # convert, commit, push → live in ~2 min
```

## Layout

| Path | Purpose |
|---|---|
| `_posts/` | Published posts (`YYYY-MM-DD-slug.md` → `/posts/slug/`) |
| `index.html`, `archive.html`, `about.md`, `404.html` | Home, archive, about and 404 pages (each has an explicit `permalink`) |
| `_data/navigation.yml` | Top navigation links (`header:` items) |
| `_data/locale.yml`, `_data/variables.yml` | Copied from the TeXt gem (UI strings, CDN sources) |
| `_config.yml` | Site settings (title, tagline, base URL, social links) |
| `assets/img/posts/` | Post images |
| `scripts/sync_obsidian.py` | Obsidian → Jekyll converter |

## Local preview (optional)

Requires Ruby 3.x + Bundler:

```bash
bundle install
bundle exec jekyll serve   # http://127.0.0.1:4000/Clustered-Thoughts/
```
