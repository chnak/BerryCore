# BerryCore v0.90.3 (chnak fork)

Maintenance release: the setup hub's embedded fallback catalog now includes
**node24** and **clash-proxy**, so a fresh install lists both ports before the
first `qpkg` catalog fetch.

Core code is unchanged from v0.90.2; `berrycore.zip` differs only in
`share/setup/PACKAGES` and the version strings (`VERSION`, `env.sh`).
`install.sh` is unchanged.

## Assets

| Asset | Purpose |
|-------|---------|
| `berrycore.zip` | full core userland (upgrade / fresh install) |
| `install.sh` | installer used by `qpkg update` and manual setup |
| `qpkg` | patched package manager (also inside `berrycore.zip`) |
| `lang-node24-24.22.1.zip` | optional: direct download of the node24 port |
| `net-clash-proxy-0.2.0.zip` | optional: direct download of the clash-proxy port |

## What's new

- `berrycore/share/setup/PACKAGES` (served by the setup hub as the fallback
  when `.cache/qpkg/PACKAGES` is absent) now contains:
  - `node24` — Node.js v24.22.1 with ICU (replaces `node-term49`)
  - `clash-proxy` — Clash-compatible local proxy with `clash-proxy import <url>`
- `VERSION` / `env.sh` → **0.90.3**.

The ports themselves are installed from the catalog as before:

```sh
qpkg install node24
qpkg install clash-proxy
clash-proxy import '<subscription URL>'
clash-proxy start
```

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

## Notes

- On devices where `/accounts/1000/shared/misc/chnak` is the install root,
  `qpkg update` installs into that directory and keeps existing ports/config.
- If `raw.githubusercontent.com` is slow or blocked, set a proxy before
  running `qpkg`:
  ```sh
  export https_proxy=http://127.0.0.1:7890
  export http_proxy=http://127.0.0.1:7890
  ```
