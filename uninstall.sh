#!/usr/bin/env bash
#
# Burst CLI uninstaller
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/burst-hq/install/HEAD/uninstall.sh)"
#
# Or run the local copy:
#   ~/.burst/uninstall.sh
#
# Environment variables:
#   BURST_INSTALL_DIR   Override install prefix (default: $HOME/.burst)
#   NONINTERACTIVE      Skip confirmation prompt (also triggered by CI=1)

set -u

abort() {
    printf "error: %s\n" "$@" >&2
    exit 1
}

if [ -z "${BASH_VERSION:-}" ]; then
    abort "This uninstaller requires bash."
fi

BURST_INSTALL_DIR="${BURST_INSTALL_DIR:-$HOME/.burst}"

if [[ ! -d "$BURST_INSTALL_DIR" ]]; then
    echo "Nothing to uninstall: ${BURST_INSTALL_DIR} does not exist."
    exit 0
fi

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------

is_noninteractive() {
    [[ -n "${NONINTERACTIVE:-}" ]] || [[ -n "${CI:-}" ]] || ! [[ -t 0 ]]
}

if ! is_noninteractive; then
    echo ""
    echo "  Burst CLI uninstaller"
    echo ""
    echo "  This will remove:"
    echo "    ${BURST_INSTALL_DIR}/"
    echo "    PATH entries from shell config files"
    echo ""
    printf "  Press ENTER to continue (or Ctrl-C to abort) "
    read -r
    echo ""
fi

# ---------------------------------------------------------------------------
# Remove install directory
# ---------------------------------------------------------------------------

echo "Removing ${BURST_INSTALL_DIR}..."
rm -rf "$BURST_INSTALL_DIR"

# ---------------------------------------------------------------------------
# Remove PATH entries from shell configs
# ---------------------------------------------------------------------------

clean_rcfile() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    if grep -qF '.burst/bin' "$file"; then
        local tmp
        tmp="$(mktemp)"
        grep -v '# burst-cli' "$file" | grep -v '\.burst/bin' > "$tmp"
        mv "$tmp" "$file"
        echo "Cleaned PATH entry from ${file}"
    fi
}

clean_rcfile "$HOME/.bashrc"
clean_rcfile "$HOME/.bash_profile"
clean_rcfile "$HOME/.zshrc"
clean_rcfile "$HOME/.config/fish/config.fish"

echo ""
echo "Burst CLI has been uninstalled."
