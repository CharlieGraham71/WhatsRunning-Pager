# What's Running? — WiFi Pineapple Pager

A native utility payload for the **WiFi Pineapple Pager** that gives you at-a-glance
system monitoring, RECON visibility, storage usage, and safe capture cleanup —
all from the pager's menu.

## Features

**Monitoring**
- System health summary (battery, CPU, RECON, PCAP usage)
- CPU status — load / idle % with a health rating (GOOD / MODERATE / HIGH LOAD)
- Memory — used / free MB
- Battery level

**Visibility**
- RECON status (reads `logrecon` from `/etc/config/pineapd`)
- Bluetooth status (active / passive, from `/etc/config/blue5`)
- Running services — detects `pineapd`, `hostapd`, `blue5`, and `dnsmasq`

**Control**
- Service Control — turn **PineAP**, **Bluetooth**, and **recon logging** on/off
  from the pager, each behind a YES/NO confirmation and verified afterwards:
  - PineAP: toggles the `pineap_disabled` flag pineapd reads (pineapd is
    respawned by the Pineapple supervisor, so the flag is the supported switch,
    not stopping the process)
  - Bluetooth: real `/etc/init.d/blue5` stop / start
  - Recon logging: toggles `logrecon` (leaves PineAP running)

**Storage & cleanup**
- Storage breakdown (PCAPs, RECON, handshakes, Wigle, total)
- Safe "Clear Data" with per-category **confirmation prompts** for PCAPs,
  handshakes, RECON databases, and Wigle data

## Install

Copy the payload onto the pager and run it like any other pager payload:

```
/root/payloads/whats-running/payload.sh
```

The script is `/bin/sh` (busybox/ash) compatible. It relies on the pager's
`LIST_PICKER` and `PROMPT` helpers being available in the environment.

## Layout

```
payload.sh        # main menu loop + all screens
lib/
  services.sh     # check_service()  — Running Services screen
  kill.sh         # svc_* / pineap_set / recon_logging_set — Service Control screen
  recon.sh        # show_recon_stats() — staged (detailed recon view)
  managed.sh      # managed_service()  — staged (unused; superseded by kill.sh)
```

The `lib/` helpers prefixed "staged" are scaffolding for planned features and
are not yet wired into `payload.sh`.

## Planned

- "Why Is My Pager Hot?" — top CPU-consuming processes
- Payload detection — show which pager payload is currently running
- Richer recon breakdown (`lib/recon.sh`)

## License

MIT — see [LICENSE](./LICENSE).
