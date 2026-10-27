# BerryCore v0.90.2 (chnak fork)

Fork release of BerryCore: upstream v0.90.1 userland plus the LCARS commit,
the fork's `qpkg`, and the new **node24** / **clash-proxy** ports. The full
core is rebuilt from the `berrycore/` source tree of `chnak/BerryCore`.

## Assets

| Asset | Purpose |
|-------|---------|
| `berrycore.zip` | full core userland (upgrade / fresh install) |
| `install.sh` | installer used by `qpkg update` and manual setup |
| `qpkg` | patched package manager (also inside `berrycore.zip`) |
| `lang-node24-24.22.1.zip` | optional: direct download of the node24 port |
| `net-clash-proxy-0.2.0.zip` | optional: direct download of the clash-proxy port |

## What's new

- **node24** — Node.js **v24.22.1** cross-built for armle-v7/QNX with
  `--with-intl=small-icu` (ICU 78.3), bundled npm **11.19.1**:
  ```sh
  qpkg install node24
  node -v    # v24.22.1
  npm -v     # 11.19.1
  ```
  It supersedes `node-term49` (Node 22) and overwrites `bin/node`,
  `bin/npm`, `bin/node.bin`. Do not `qpkg remove node-term49` afterwards —
  the two ports share those file names.
- **clash-proxy** — Clash-compatible local proxy (Shadowsocks + VMess,
  mixed HTTP/SOCKS5 on `127.0.0.1:7890`), now installable as a port:
  ```sh
  qpkg install node24        # required runtime
  qpkg install clash-proxy
  clash-proxy import '<subscription URL>'
  clash-proxy start
  ```
  `import` saves the URL to `subscription.url`, downloads and validates the
  Clash YAML, backs up the old config to `config.yaml.bak`, and restarts a
  running proxy. `--no-restart` skips the restart. The URL is never echoed.
- **qpkg** now defaults to this fork for both core releases and the port
  catalog. Set `BERRYCORE_REPO=sw7ft/BerryCore` (and/or
  `BERRYCORE_PORTS_REPO=sw7ft/BerryCore`) to follow upstream instead.

## Upgrade

```sh
qpkg update
```

or, non-interactively:

```sh
QPKG_YES=1 qpkg update -y
```

## Fresh install

1. Download `berrycore.zip` and `install.sh`.
2. Copy both to `/accounts/1000/shared/misc/`.
3. On the device:
   ```sh
   cd /accounts/1000/shared/misc
   sh install.sh --fresh -y
   . berrycore/env.sh
   ```

If `raw.githubusercontent.com` is slow or blocked, set a proxy before
running `qpkg`:

```sh
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
qpkg install node24
```
