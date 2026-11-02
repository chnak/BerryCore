# BerryCore v0.90.3 (chnak fork)

Maintenance release: the setup hub's embedded fallback catalog now includes
**node24** and **clash-proxy**, so a fresh install lists both ports before the
first `qpkg` catalog fetch.

Core code is unchanged from v0.90.2; `berrycore.zip` differs only in
`share/setup/PACKAGES` and the version strings (`VERSION`, `env.sh`).
`install.sh` was refreshed on 2026-11-02 with installer fixes (see below).

## install.sh hotfix (2026-11-02)

Re-uploaded `install.sh` (17,917 B, sha256 `ee0eac2692af9134…`). It now:

- runs from its own directory and verifies `berrycore.zip` before touching anything
- falls back to `unzip` when `pbpkgadd` (a `python3.2` script) is unavailable —
  on a fresh device this previously installed **zero** packages, leaving no
  `ls`/`printf` (coreutils), which showed up as `ls: illegal option -- -` and
  `term49_splash` errors
- never rewrites `~/.profile` unless the install completed (`env.sh` and
  `sample_profile` present)
- only enables `alias ls='ls --color=auto'` when `bin/ls` exists
- guards the `term49_splash` call in the generated profile
- keeps an existing `bcllm` / `berrybridge-agent` as a timestamped `.bak`
  instead of `rm -rf`
- adds `--no-profile` and `--no-termcfg`; `.term48rc` backups are timestamped

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
