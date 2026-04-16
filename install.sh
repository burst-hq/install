#!/usr/bin/env bash
#
# Burst CLI installer
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/burst-hq/install/HEAD/install.sh)"
#
# Environment variables:
#   BURST_INSTALL_DIR      Override install prefix (default: $HOME/.burst)
#   BURST_VERSION          Pin a specific version (default: latest stable)
#   NONINTERACTIVE         Skip confirmation prompt (also triggered by CI=1)
#   BURST_NO_MODIFY_PATH   Don't modify shell config files

set -u

abort() {
    printf "error: %s\n" "$@" >&2
    exit 1
}

if [ -z "${BASH_VERSION:-}" ]; then
    abort "This installer requires bash. Run with: /bin/bash -c \"\$(curl -fsSL ...)\""
fi

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

detect_os() {
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin) echo "darwin" ;;
        Linux)  echo "linux" ;;
        *)      abort "Unsupported operating system: $os" ;;
    esac
}

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)        echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)             abort "Unsupported architecture: $arch" ;;
    esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BURST_INSTALL_DIR="${BURST_INSTALL_DIR:-$HOME/.burst}"
BURST_BIN_DIR="${BURST_INSTALL_DIR}/bin"
RELEASES_REPO="burst-hq/burst-cli-releases"
INSTALL_REPO_RAW="https://raw.githubusercontent.com/burst-hq/install/HEAD"

# ---------------------------------------------------------------------------
# Required tools
# ---------------------------------------------------------------------------

for cmd in curl tar; do
    command -v "$cmd" >/dev/null || abort "Required command not found: $cmd"
done

sha256_check() {
    local file="$1" expected="$2" actual
    if command -v sha256sum >/dev/null; then
        actual="$(sha256sum "$file" | awk '{print $1}')"
    elif command -v shasum >/dev/null; then
        actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    else
        abort "No SHA-256 tool found (need sha256sum or shasum)"
    fi
    if [[ "$actual" != "$expected" ]]; then
        abort "Checksum mismatch for $(basename "$file")" \
              "  expected: $expected" \
              "  got:      $actual"
    fi
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

if [[ -n "${BURST_VERSION:-}" ]]; then
    VERSION="$BURST_VERSION"
else
    VERSION="$(curl -fsSL "https://api.github.com/repos/${RELEASES_REPO}/releases/latest" \
        | grep '"tag_name"' \
        | sed -E 's/.*"v([^"]+)".*/\1/')" \
        || true
    if [[ -z "${VERSION:-}" ]]; then
        abort "Failed to determine latest version." \
              "Set BURST_VERSION to install a specific version."
    fi
fi

TARBALL="burst-${OS}-${ARCH}.tar.gz"
DOWNLOAD_BASE="https://github.com/${RELEASES_REPO}/releases/download/v${VERSION}"

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------

is_noninteractive() {
    [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]] || ! [[ -t 0 ]]
}

if ! is_noninteractive; then
    echo ""
    echo "  Burst CLI installer"
    echo ""
    echo "  This will install:"
    echo "    burst v${VERSION} (${OS}/${ARCH})"
    echo ""
    echo "  Into:"
    echo "    ${BURST_BIN_DIR}/burst"
    echo ""
    printf "  Press ENTER to continue (or Ctrl-C to abort) "
    read -r
    echo ""
fi

# ---------------------------------------------------------------------------
# Download and verify
# ---------------------------------------------------------------------------

WORK_DIR="$(mktemp -d)" || abort "Failed to create temp directory"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading burst v${VERSION} for ${OS}/${ARCH}..."
curl -fsSL --retry 3 -o "${WORK_DIR}/${TARBALL}" "${DOWNLOAD_BASE}/${TARBALL}" \
    || abort "Download failed." \
             "Check that v${VERSION} exists and has a ${OS}/${ARCH} binary:" \
             "  https://github.com/${RELEASES_REPO}/releases"

curl -fsSL --retry 3 -o "${WORK_DIR}/SHA256SUMS" "${DOWNLOAD_BASE}/SHA256SUMS" \
    || abort "Failed to download checksums."

EXPECTED="$(grep "${TARBALL}" "${WORK_DIR}/SHA256SUMS" | awk '{print $1}')"
[[ -n "$EXPECTED" ]] || abort "No checksum found for ${TARBALL} in SHA256SUMS"

echo "Verifying checksum..."
sha256_check "${WORK_DIR}/${TARBALL}" "$EXPECTED"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

echo "Installing to ${BURST_BIN_DIR}..."
mkdir -p "$BURST_BIN_DIR"
tar -xzf "${WORK_DIR}/${TARBALL}" -C "$BURST_BIN_DIR"
chmod +x "${BURST_BIN_DIR}/burst"

# Place uninstaller alongside the binary
if curl -fsSL --retry 3 -o "${BURST_INSTALL_DIR}/uninstall.sh" \
    "${INSTALL_REPO_RAW}/uninstall.sh" 2>/dev/null; then
    chmod +x "${BURST_INSTALL_DIR}/uninstall.sh"
fi

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------

add_to_path() {
    local rcfile="$1" line="$2"
    [[ -f "$rcfile" ]] || touch "$rcfile"
    if ! grep -qF '.burst/bin' "$rcfile"; then
        printf '\n# burst-cli\n%s\n' "$line" >> "$rcfile"
    fi
}

SHELL_NAME="$(basename "${SHELL:-/bin/sh}")"

if [[ -z "${BURST_NO_MODIFY_PATH:-}" ]]; then
    case "$SHELL_NAME" in
        bash)
            add_to_path "$HOME/.bashrc" 'export PATH="$HOME/.burst/bin:$PATH"'
            if [[ "$OS" == "darwin" ]]; then
                add_to_path "$HOME/.bash_profile" 'export PATH="$HOME/.burst/bin:$PATH"'
            fi
            ;;
        zsh)
            add_to_path "$HOME/.zshrc" 'export PATH="$HOME/.burst/bin:$PATH"'
            ;;
        fish)
            fishrc="$HOME/.config/fish/config.fish"
            mkdir -p "$(dirname "$fishrc")"
            add_to_path "$fishrc" 'set -gx PATH $HOME/.burst/bin $PATH'
            ;;
        *)
            echo "Note: could not detect shell. Add ${BURST_BIN_DIR} to your PATH manually."
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# Verify and print next steps
# ---------------------------------------------------------------------------

echo ""
if "${BURST_BIN_DIR}/burst" version >/dev/null 2>&1; then
    echo "$("${BURST_BIN_DIR}/burst" version) installed successfully."
else
    echo "Installed burst to ${BURST_BIN_DIR}/burst"
fi

if [[ ":${PATH}:" != *":${BURST_BIN_DIR}:"* ]]; then
    echo ""
    case "$SHELL_NAME" in
        zsh)  echo "Run 'source ~/.zshrc' or open a new terminal to use burst." ;;
        bash) echo "Run 'source ~/.bashrc' or open a new terminal to use burst." ;;
        fish) echo "Run 'source ~/.config/fish/config.fish' or open a new terminal to use burst." ;;
        *)    echo "Open a new terminal or add ${BURST_BIN_DIR} to your PATH." ;;
    esac
fi

echo ""
echo "Get started:"
echo "  burst signup      Create an account"
echo "  burst run ./code  Run your first job"
echo ""
echo "Docs: https://burst.cx/docs"
