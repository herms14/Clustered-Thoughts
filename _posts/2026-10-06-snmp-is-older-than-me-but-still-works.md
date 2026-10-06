---
title: SNMP Is Older Than Me But Still Works
date: 2026-10-06 08:14:00 +0800
categories:
- Homelab
- Observability & Monitoring
tags:
- homelab
- network
- prometheus
- snmp
- synology
description: SNMP — Simple Network Management Protocol — dates to 1988. It predates the web, predates TLS, predates nearly every security assumption we now take for granted. And it's still, in 2026, how I get metrics out of a...
excerpt: SNMP — Simple Network Management Protocol — dates to 1988. It predates the web, predates TLS, predates nearly every security assumption we now take for granted. And it's still, in 2026, how I get metrics out of a...
render_with_liquid: false
---

SNMP — Simple Network Management Protocol — dates to 1988. It predates the web, predates TLS, predates nearly every security assumption we now take for granted. And it's still, in 2026, how I get metrics out of a Synology NAS and a rack of TP-Link switches.

Neither of those devices speaks Prometheus natively. Both speak SNMP, because SNMP is the one thing almost every piece of network hardware ever made agrees on. If you want visibility into that hardware, you learn SNMP, or you don't get visibility.


## The translation layer

Prometheus expects an HTTP endpoint returning metrics in its own text format. SNMP devices answer UDP queries with data encoded in ASN.1. Nothing about those two things talks to each other directly.

```
Prometheus → SNMP Exporter → SNMP Device
   HTTP          UDP            SNMP
```

SNMP Exporter sits in the middle: it takes an HTTP scrape request from Prometheus, turns it into an SNMP query against the actual device, and hands the answer back in a format Prometheus understands. One exporter container can front any number of devices, each described by its own module in the exporter's config.

## Turning SNMP on, the easy half

In DSM: Control Panel → Terminal & SNMP → SNMP tab → enable SNMPv2c, set a community string (`public` is the default everyone uses for internal-only access — there's no real authentication here, which is a fair criticism of the protocol and not one worth fighting in a homelab). Save, and the NAS answers on UDP 161.

```bash
snmpwalk -v2c -c public 192.168.20.32 system
```

Data back means it's working. A timeout means check the firewall or the community string before anything more exotic.

## The actual complexity lives in MIB files

SNMP data is addressed by OID — a hierarchical number, like `1.3.6.1.4.1.6574.1.2`, which to a human is meaningless and to a Synology device means "system temperature." MIB files are the translation table from OID to name; Synology ships MIBs for their own hardware, and you feed them into the SNMP Exporter's generator to produce a module that maps OIDs onto Prometheus metric names.

```yaml
modules:
  synology:
    walk:
      - 1.3.6.1.4.1.6574.1      # System
      - 1.3.6.1.4.1.6574.2      # Disk
      - 1.3.6.1.4.1.6574.3      # RAID
    metrics:
      - name: synology_system_temperature
        oid: 1.3.6.1.4.1.6574.1.2
        type: gauge
```

Tedious exactly once, per device vendor. After the first module, it's mostly copy, adjust OIDs, repeat.

## The Prometheus config reads backwards until you understand why

Normally a scrape target *is* the thing you're measuring. With SNMP, the exporter is the actual scrape target, and the device you care about gets passed through as a parameter via relabeling:

```yaml
- job_name: 'snmp-synology'
  static_configs:
    - targets:
        - 192.168.20.32  # the NAS
  metrics_path: /snmp
  params:
    module: [synology]
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - target_label: __address__
      replacement: 192.168.40.13:9116  # the exporter
```

The NAS's IP gets rewritten into a query parameter, and the actual HTTP request goes to the exporter instead. It makes sense once you've drawn the diagram once. Reading it cold, with no diagram, it looks like someone swapped the target and the parameter by mistake.

## What I actually watch on the Synology

- **RAID status** — anything other than "Normal" is a critical alert, no debate, since degraded RAID plus one more disk failure is data loss.
- **Disk temperatures** — climbing trend suggests a cooling problem; one disk running hotter than its siblings suggests that specific disk.
- **Volume usage** — feeds capacity planning directly: at 90% I need to either delete something or add storage, not wait for 100%.
- **System temperature** — sustained high readings point at the environment, not the disks.

## Network interfaces use a MIB everything agrees on

IF-MIB is close to universal — any managed switch, router, or NAS that implements SNMP at all implements this one, which covers bytes/packets in and out, errors, and interface up/down state.

```yaml
modules:
  if_mib:
    walk:
      - 1.3.6.1.2.1.2.2    # ifTable
      - 1.3.6.1.2.1.31.1   # ifXTable
    metrics:
      - name: ifHCInOctets
        oid: 1.3.6.1.2.1.31.1.1.1.6
        type: counter
```

With that in place, I can check per-port bandwidth on a managed switch directly, instead of guessing whether "the network feels slow" is a real saturated port or just a feeling.

## Alerts, same shape as everything else

```yaml
- alert: SynologyRAIDDegraded
  expr: synology_raid_status != 1
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Synology RAID is not healthy"
```

RAID degraded: immediate critical, no `for` delay worth the risk. Disk temperature over 50°C for ten minutes: warning. Volume usage over 90%: warning. These three cover the scenarios that are actually urgent on a NAS — the RAID one most of all, since that's the one where waiting has a real cost.

## Troubleshooting SNMP is annoyingly opaque

A timeout could mean wrong IP, wrong community string, a firewall dropping UDP, the device not actually supporting SNMP, or the exporter's module being misconfigured — and the error message doesn't tell you which. One command splits the problem in half:

```bash
docker exec snmp-exporter snmpwalk -v2c -c public 192.168.20.32 system
```

If that returns data, the issue is in Prometheus or the exporter config. If it doesn't, the issue is on the device or the network path — and now you're debugging one problem instead of five.

## The actual point

SNMP is not elegant. The OID hierarchy is awkward, MIB files are their own bespoke format, a shared community string is laughable as "authentication" by any modern standard, and ASN.1 encoding belongs to a different era of computing entirely. None of that stops it from working, on hardware from a dozen different manufacturers spanning decades of production, with documentation that exists for almost every device that implements it — precisely *because* it's been around since 1988. Sometimes the boring, universally-supported protocol beats the elegant one nobody actually shipped.

---

*This is the fifteenth post in a series about building and maintaining a homelab. Next: Uptime Kuma, and the difference between "Prometheus says this is fine" and "is this actually reachable right now."*
