---
title: Kubernetes at Home (And Whether You Need It)
date: 2026-08-11 08:00:00 +0800
categories:
- Homelab
- Advanced Topics
tags:
- homelab
- k8s
- kubernetes
- orchestration
description: The honest answer to "should I run Kubernetes at home?" is probably no. Docker Compose handles the overwhelming majority of homelab workloads with a fraction of the complexity. If your services don't need auto-scaling...
excerpt: The honest answer to "should I run Kubernetes at home?" is probably no. Docker Compose handles the overwhelming majority of homelab workloads with a fraction of the complexity. If your services don't need auto-scaling...
render_with_liquid: false
---

The honest answer to "should I run Kubernetes at home?" is probably no. Docker Compose handles the overwhelming majority of homelab workloads with a fraction of the complexity. If your services don't need auto-scaling, rolling deployments, or multi-replica coordination, Kubernetes is overhead with no corresponding benefit.

I run it anyway. Not because any of my services need it, but because the CKA certification requires hands-on cluster experience, and building that experience against a homelab is a lot cheaper than practicing on something at work. That distinction matters: running K8s to learn it is a fine reason. Running K8s because you've convinced yourself you need it, when Compose would do the job, usually isn't.

## The shape of the cluster

After some back-and-forth I landed on three control-plane nodes and six workers, all Proxmox VMs. Control-plane nodes run etcd, the API server, scheduler, and controller-manager. They coordinate, they don't run workloads, and three gives real redundancy (lose one, the cluster doesn't blink). Workers run the actual pods; six gives enough headroom to spread load and survive a node failure without losing anything.

> This is more cluster than a homelab strictly needs. Two control-plane nodes and three workers would be plenty for casual experimentation. I went bigger specifically because CKA exam scenarios assume multi-node realism, and practicing on a toy-sized cluster would have taught me the wrong intuitions about scheduling and failover.

Bootstrapped with `kubeadm`:

```bash
kubeadm init --control-plane-endpoint="k8s-api.hrmsmrflrii.xyz:6443" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16
```

The control-plane endpoint is a DNS name that load-balances across all three control-plane nodes. If one's down, the others still answer on the same name, and nothing downstream needs to know which one actually handled the request. Pod networking runs on Flannel; it's not the most feature-rich CNI option but it's simple and well-documented, which is what I wanted while I was still learning the rest of the stack.

## The mental model that actually stuck

- **Pods** are the atomic unit: one or more containers sharing network and storage. "A thing that runs."
- **Deployments** manage pods declaratively: say "three replicas" and Kubernetes keeps three running, rescheduling automatically if one dies.
- **Services** give pods a stable address. Pods churn through dynamic IPs constantly; a Service is the fixed point that routes to whichever pods are currently healthy.
- **Ingress** routes external traffic in, by hostname and path.

Everything else (ConfigMaps, Secrets, PersistentVolumeClaims, DaemonSets, Jobs) is a variation built on top of those four ideas.

## Where the line actually is

I deliberately split workloads by purpose, not by preference:

| | Kubernetes | Docker Compose |
|---|---|---|
| Runs | Things I'm actively learning on: deploy, scale, break, fix, repeat | Production: Glance, Grafana, the media stack, monitoring |
| Can I destroy it? | Yes, regularly, on purpose | No, changes happen carefully, on purpose |
| Why | The cluster *is* the learning environment | These need to work without me thinking about them |

Migrating a service between the two is possible but not free. The concepts map cleanly enough: a Compose service becomes a Deployment, port mappings become a Service, volumes become a PersistentVolumeClaim, env vars become a ConfigMap or Secret. But the translation isn't automatic, and Kubernetes manifests are verbose in a way Compose files aren't. A 20-line `docker-compose.yml` turns into 200 lines of YAML spread across several files. For something that benefits from scaling and self-healing, that complexity earns its keep. For a dashboard running one container, it's pure tax.

## The learning path, in the order it actually made sense

1. **Pods**: deploy something simple, exec into it, read its logs, delete it and watch it come back.
2. **Deployments**: scale up and down, do a rolling update, roll one back.
3. **Services**: expose something internally and externally, then debug the inevitable networking confusion.
4. **Storage**: PersistentVolumes, claims, and understanding that a volume's lifecycle is not the same as a pod's.
5. **Security**: ServiceAccounts, RBAC, network policies.

This roughly tracks the CKA exam domains, and each step genuinely does build on the last. Skipping ahead just means re-learning the skipped step later while debugging something unrelated.

## Mistakes worth naming specifically

- **Treating pods as if they persist.** Anything written to the container filesystem is gone the moment the pod restarts. Everything that needs to survive gets a volume, no exceptions, no "it'll probably be fine."
- **Ignoring resource requests and limits.** Without them, one greedy pod can starve a node into evicting its neighbors. Setting sane requests isn't bureaucracy, it's what gives the scheduler enough information to make good placement decisions.
- **Assuming DNS is instant.** There's real propagation time when a Service first comes up, and a health check that fires before DNS has caught up looks exactly like a broken deployment until you know to wait a few extra seconds.

## Where I actually land on this

Kubernetes at home is for learning, not for running things you depend on. The operational overhead is real: upgrades need care, troubleshooting spans more layers than Compose ever asks you to think about, and the cluster itself is one more thing that needs monitoring. For a homelab whose actual goal is "run my services with minimal fuss," Compose wins outright. For building real orchestration muscle memory for work, nothing else I've tried comes close.

Know which goal you're actually optimizing for before you spin this up. That's the whole decision.

---

*This is the twenty-second post in a series about building and maintaining a homelab. The next post covers hybrid cloud with Azure Arc.*
