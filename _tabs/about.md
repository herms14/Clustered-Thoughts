---
# the default layout is 'page'
icon: fas fa-info-circle
order: 4
---

## Hey, I'm Hermes 👋

I'm a cloud and solution architect based in the Philippines. In 2023 I fell into homelabbing by accident: I wanted somewhere to keep my Japan trip photos without paying for another cloud subscription. That turned into a Proxmox cluster, a few dozen self-hosted services, and lately a small team of AI agents that help me run it all.

## What this blog is about

**Clustered Thoughts** is a set of notes on **infrastructure, automation, and supervised AI**:

- **Homelab architecture**: virtualisation, networking, storage and self-hosting patterns that actually hold up.
- **Automation**: Ansible, Terraform, GitLab CI and the scripts that hold everything together.
- **AI agents on real infrastructure**: Codex and Claude Code doing real work like patching, triage and documentation, with guardrails and a human approving every change.
- **Lessons learned**: including the times I locked myself out of my own cluster.

The common thread is *supervised autonomy*. Let AI do the work, and keep a human in the loop for the decisions.

## The stack

```text
├── Compute:     Proxmox VE cluster (3 nodes), VMs + LXC containers
├── Backup:      Proxmox Backup Server
├── Networking:  TP-Link Omada SDN, VLAN segmentation, Traefik + Authentik SSO
├── Storage:     Synology NAS
├── Automation:  Ansible, Terraform, GitLab CE
├── Monitoring:  Prometheus, Grafana, Uptime Kuma, Glance
├── ChatOps:     Discord bots (approvals, alerts, reports)
└── AI:          OpenAI Codex CLI + Claude Code agents
```

## Connect

- **GitHub**: [herms14](https://github.com/herms14)
- **LinkedIn**: [hrmsmrflr](https://www.linkedin.com/in/hrmsmrflr/)

> Views are my own. Everything here runs at home, on my own hardware.
{: .prompt-info }
