---
title: Terraform Changed How I Think About VMs
date: 2026-10-06 08:04:00 +0800
categories:
- Homelab
- Foundation Layer
tags:
- homelab
- iac
- proxmox
- terraform
description: Before Terraform, creating a VM meant logging into Proxmox and clicking through a wizard — twenty-odd options, half of which I'd forget by the next time I needed another one. I'd jot the settings in a text file, lose...
excerpt: Before Terraform, creating a VM meant logging into Proxmox and clicking through a wizard — twenty-odd options, half of which I'd forget by the next time I needed another one. I'd jot the settings in a text file, lose...
render_with_liquid: false
---

Before Terraform, creating a VM meant logging into Proxmox and clicking through a wizard — twenty-odd options, half of which I'd forget by the next time I needed another one. I'd jot the settings in a text file, lose the file, and rebuild from memory.

That works until you're managing more than a handful of machines. Then it doesn't.

---

The pitch for Infrastructure as Code is reproducibility, but what actually sold me was the diff. `terraform plan` shows exactly what's about to change before anything happens — a new VM shows the resources it'll create, a memory bump shows old value next to new, a removal shows what's getting destroyed. Before this, I'd make a change and hope I remembered the previous state correctly. The first time I accidentally deleted a VM through the Proxmox UI directly, I understood exactly what that safety net was for.

I use the `telmate/proxmox` provider, pinned to `v3.0.2-rc06` specifically for compatibility with Proxmox VE 9.x — it's community-maintained, not official, and it shows in small ways (edge cases that need workarounds between versions), but it covers VMs, LXC containers, storage, and cloud-init cleanly enough that I haven't needed to drop to the raw API.

---

State management is the part that still has a rough edge I haven't fixed.

Terraform tracks what it owns through a state file — my `terraform.tfstate` lives locally, on disk, no remote backend. That's fine for a single operator running from one machine, which is genuinely all I am right now. It's also a single point of failure I've simply accepted rather than solved: if that file is lost or corrupted, Terraform has no memory of what it's managing, and recovery means importing every resource back into a fresh state by hand. I know the honest fix is a remote backend with locking. I haven't done it, because the failure mode hasn't happened yet, which is exactly the kind of reasoning that eventually bites you.

---

The repo structure that emerged:

```
tf-proxmox/
├── main.tf              # VM group definitions
├── lxc.tf               # LXC container definitions
├── variables.tf
├── outputs.tf
├── terraform.tfvars     # gitignored
└── modules/
    ├── linux-vm/
    └── lxc/
```

Adding a group of VMs means editing a `vm_groups` local in `main.tf` — node, starting IP, count — and letting `for_each` handle the rest, with auto-incrementing hostnames for anything that needs multiples (the Kubernetes workers I later decommissioned were a good example: `k8s-worker01`, `02`, `03`, declared once, applied as a set).

The workflow is boring in the way good infrastructure process should be: edit the `.tf` files, `plan`, review, `apply`, commit. Step two — reviewing the plan — has caught more typo'd IPs and wrong-node targets than I'd like to admit. The git history doubles as a changelog: when something breaks, I can trace back to the commit that changed it, which matters a lot more at 11 PM than it does during the day.

---

Templates made the single biggest practical difference. One Ubuntu template, built once with the QEMU guest agent, SSH keys, and cloud-init baked in — cloning it gives a working VM in under a minute, with cloud-init handling the per-instance hostname and IP on first boot. The first time I deployed three VMs in parallel from a single `apply`, each with a different IP, I understood why people actually build infrastructure this way instead of just saying they should.

LXC containers don't template quite the same way — you point at a template tarball directly rather than cloning a golden image, and cloud-init doesn't apply the same way. I use Terraform to create the container and set the basics, then hand off to Ansible for everything else. That handoff isn't seamless; Ansible's inventory needs to know about resources Terraform just created, and the two tools don't share a state model. It works, but it's a seam I'm aware of every time I add something new.

---

What I'd do differently: start with Terraform from the first VM, not months in. I built things by hand first and migrated later, which meant importing already-existing resources into state — tedious and error-prone in a way that writing it fresh from day one wouldn't have been. I'd also build the module structure earlier; my first attempts were one-off resource blocks with real copy-paste repetition before I consolidated into `modules/linux-vm` and `modules/lxc`.

---

Terraform isn't the only tool that solves this — Pulumi and direct API scripting get you the same properties. I picked Terraform for the ecosystem and the volume of existing troubleshooting material when something inevitably breaks. The tool matters less than the principle: infrastructure as code, reviewed before applied, tracked in version control. Anything that gives you that is a real improvement over clicking through a web UI from memory.

---

*This is the fifth post in a series about building and maintaining a homelab. The next post covers Ansible, and why creating infrastructure and configuring it turned out to be two different problems.*
