# Burst CLI Installer

The quickest way to install the [Burst](https://burst.cx) CLI.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/burst-hq/install/HEAD/install.sh)"
```

## Uninstall

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/burst-hq/install/HEAD/uninstall.sh)"
```

Or run the local copy placed during install:

```bash
~/.burst/uninstall.sh
```

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `BURST_INSTALL_DIR` | `$HOME/.burst` | Override install prefix |
| `BURST_VERSION` | latest stable | Pin a specific version (e.g. `0.1.0`) |
| `NONINTERACTIVE` | unset | Skip confirmation prompt |
| `BURST_NO_MODIFY_PATH` | unset | Don't modify shell config files |

## What it does

1. Detects your OS and architecture (macOS/Linux, arm64/amd64)
2. Downloads the matching binary from [burst-cli-releases](https://github.com/burst-hq/burst-cli-releases)
3. Verifies the SHA-256 checksum
4. Installs to `~/.burst/bin/burst` (no sudo required)
5. Adds `~/.burst/bin` to your `PATH` via shell config
6. Places an uninstaller at `~/.burst/uninstall.sh`

## CI / scripted installs

```bash
NONINTERACTIVE=1 BURST_VERSION=0.1.0 \
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/burst-hq/install/HEAD/install.sh)"
```
