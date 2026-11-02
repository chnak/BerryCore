#!/bin/sh

# Always run from the directory that holds this script and berrycore.zip.
# (Fixes: running "sh /path/install.sh" from elsewhere silently installed nothing.)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || SCRIPT_DIR="."
cd "$SCRIPT_DIR" || { echo "ERROR: cannot cd to $SCRIPT_DIR"; exit 1; }

# Parse options (used by qpkg update: install.sh --upgrade -y --dir "$NATIVE_TOOLS")
UPGRADE_MODE=0
YES_MODE=0
FORCE_CLITOOLS=0
NO_PROFILE=0
NO_TERMCFG=0
INSTALL_DIR=""
custom_name=""

while [ $# -gt 0 ]; do
    case "$1" in
        --upgrade|-u)
            UPGRADE_MODE=1
            shift
            ;;
        --fresh)
            UPGRADE_MODE=0
            shift
            ;;
        -y|--yes)
            YES_MODE=1
            shift
            ;;
        -f)
            FORCE_CLITOOLS=1
            shift
            ;;
        --no-profile)
            NO_PROFILE=1
            shift
            ;;
        --no-termcfg)
            NO_TERMCFG=1
            shift
            ;;
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "usage: sh install.sh [--fresh|--upgrade] [-y] [-f] [--dir DIR] [--no-profile] [--no-termcfg]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Preflight: berrycore.zip must be here and must be intact.
# Without this, a wrong cwd made every step fail silently and still rewrote
# ~/.profile, leaving Term49 unusable on the next launch.
# ---------------------------------------------------------------------------
if [ ! -f berrycore.zip ]; then
    echo ""
    echo "ERROR: berrycore.zip not found in: $PWD"
    echo ""
    echo "Put install.sh and berrycore.zip in the same directory, then run:"
    echo "  cd <that directory> && sh install.sh"
    echo ""
    exit 1
fi
if [ -z "$(unzip -p berrycore.zip VERSION 2>/dev/null)" ]; then
    echo ""
    echo "ERROR: berrycore.zip is not readable (unzip -p VERSION failed)."
    echo "Re-download it; do not continue with a truncated archive."
    echo ""
    exit 1
fi

if [ -z "$INSTALL_DIR" ] && [ -n "$BERRYCORE_INSTALL_DIR" ]; then
    INSTALL_DIR="$BERRYCORE_INSTALL_DIR"
fi
if [ -z "$INSTALL_DIR" ] && [ -n "$NATIVE_TOOLS" ] && [ "$UPGRADE_MODE" -eq 1 ]; then
    INSTALL_DIR="$NATIVE_TOOLS"
fi

BC_VERSION=$(unzip -p berrycore.zip VERSION 2>/dev/null || echo "unknown")

echo ""
echo "==========================================================="
echo "     BerryCore v${BC_VERSION} Installation"
echo "==========================================================="
echo ""

if [ -z "$INSTALL_DIR" ]; then
    echo "Installation directory: /accounts/1000/shared/misc/berrycore"
    echo ""
    if [ "$YES_MODE" -eq 1 ]; then
        custom_name="berrycore"
        INSTALL_DIR="/accounts/1000/shared/misc/berrycore"
        echo "Using default: $INSTALL_DIR"
    else
        echo "Press Enter to use default, or type a custom name:"
        echo -n "Directory name [berrycore]: "
        read custom_name

        if [ -z "$custom_name" ]; then
            custom_name="berrycore"
            INSTALL_DIR="/accounts/1000/shared/misc/berrycore"
            echo "Using default: $INSTALL_DIR"
        else
            INSTALL_DIR="/accounts/1000/shared/misc/$custom_name"
            echo "Installing to: $INSTALL_DIR"
        fi
    fi
else
    echo "Installation directory: $INSTALL_DIR"
fi

echo ""

# Check for existing BerryCore installation
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/env.sh" ]; then
    if [ "$UPGRADE_MODE" -eq 0 ] && [ "$YES_MODE" -eq 0 ]; then
        echo "==========================================================="
        echo "  Existing BerryCore installation detected!"
        echo "==========================================================="
        echo ""
        echo "Installation found at: $INSTALL_DIR"
        echo ""
        echo "Choose installation mode:"
        echo "  [1] Upgrade (fast - only install new/changed packages)"
        echo "  [2] Fresh install (slower - reinstall all packages)"
        echo ""
        echo -n "Enter choice [1]: "
        read install_choice

        if [ -z "$install_choice" ] || [ "$install_choice" = "1" ]; then
            UPGRADE_MODE=1
            echo ""
            echo "Using upgrade mode - will preserve existing packages"
        else
            UPGRADE_MODE=0
            echo ""
            echo "Using fresh install mode - will reinstall everything"
        fi
    elif [ "$UPGRADE_MODE" -eq 1 ]; then
        echo "Upgrade mode — updating $INSTALL_DIR"
    fi
else
    if [ "$YES_MODE" -eq 0 ]; then
        echo "Press Enter to continue or Ctrl+C to cancel..."
        read confirm
    fi
fi

# versions up to 0.4 were slowing down the device (see #54)
D=/accounts/1000/shared/documents/clitools
if [ -d $D ]; then
 if [ "$FORCE_CLITOOLS" -eq 1 ]; then
    echo
    echo "skipping check of previous BerryCore/Berrymuch version (<0.6)"
    echo
 else
    echo
    echo "previous version of Berrymuch (<0.6) has been detected"
    echo "please remove the previous installation by typing"
    echo
    echo "  rm -rf /accounts/1000/shared/documents/clitools"
    echo "  $0"
    echo
    echo "if you want to bypass this check, use install.sh -f"
    echo
    echo
    exit 0
 fi
fi

D=$INSTALL_DIR
mkdir -p $D;
cp berrycore.zip $D || { echo "ERROR: cannot copy berrycore.zip to $D"; exit 1; }
cd $D || { echo "ERROR: cannot cd to $D"; exit 1; }

# Save old env.sh timestamp for upgrade detection (fallback)
OLD_ENV_TIME=0
if [ -f "env.sh" ]; then
    OLD_ENV_TIME=$(stat -f %m env.sh 2>/dev/null || stat -c %Y env.sh 2>/dev/null || echo 0)
fi

STAMP_DIR=".berrycore_pkg_stamps"
mkdir -p "$STAMP_DIR" 2>/dev/null

package_mtime() {
    _pkg="$1"
    _mtime=$(stat -f %m "$_pkg" 2>/dev/null || stat -c %Y "$_pkg" 2>/dev/null || echo 0)
    if [ "$_mtime" = "0" ] && command -v python3 >/dev/null 2>&1; then
        _mtime=$(python3 -c "import os; print(int(os.path.getmtime('$_pkg')))" 2>/dev/null || echo 0)
    fi
    echo "$_mtime"
}

should_skip_package() {
    _pkg="$1"
    _base="$2"
    _stamp="$STAMP_DIR/$_base"

    if [ ! -f "$_stamp" ]; then
        return 1
    fi

    _installed=$(cat "$_stamp" 2>/dev/null)
    _pkgtime=$(package_mtime "$_pkg")

    if [ -n "$_installed" ] && [ -n "$_pkgtime" ] && [ "$_pkgtime" -le "$_installed" ]; then
        return 0
    fi

    if [ -n "$_installed" ] && [ "$_pkgtime" = "0" ] && [ $OLD_ENV_TIME -gt 0 ]; then
        if [ $OLD_ENV_TIME -gt "$_installed" ]; then
            return 1
        fi
        return 0
    fi

    return 1
}

touch .nomedia .noindex
unzip -o berrycore.zip || { echo "ERROR: unzip berrycore.zip failed"; exit 1; }
# Update env.sh with actual installation path BEFORE sourcing it
# so pbpkgadd installs packages to the correct directory
sed -i.bak "s|NATIVE_TOOLS=\"/accounts/1000/shared/misc/berrycore\"|NATIVE_TOOLS=\"$PWD\"|g" env.sh
# Only enable the GNU-style `ls --color=auto` alias when coreutils is really
# installed. On a device without bin/ls this alias makes every `ls` fail with
# "illegal option -- -" (QNX ls does not understand --color).
sed -i.bak "s|^alias ls='ls --color=auto'\$|[ -x \"\$NATIVE_TOOLS/bin/ls\" ] \&\& alias ls='ls --color=auto'|" env.sh
rm -f env.sh.bak
# Note: berrycore.zip is kept in both locations (original and installation directory)
if [ ! -f env.sh ]; then
    echo "ERROR: env.sh missing after unzip — refusing to continue (archive incomplete)."
    exit 1
fi
. ./env.sh

# zsh and other tools have hardcoded /accounts/1000/shared/misc/clitools paths
# Create symlink so they find the actual install directory
if [ -d /accounts/1000/shared/misc ] && { [ ! -e /accounts/1000/shared/misc/clitools ] || [ -L /accounts/1000/shared/misc/clitools ]; }; then
    ln -sf "$PWD" /accounts/1000/shared/misc/clitools
    echo "Created clitools -> $PWD symlink (for zsh and legacy tools)"
fi

# Install packages
NEW_PKGS=0
SKIPPED_PKGS=0
UPDATED_PKGS=0
FAILED_PKGS=0

# pbpkgadd is a python3.2 script; a fresh BB10 has no python3.2, so fall back
# to plain unzip (same behaviour as the PlayBook installer). Without this the
# whole package set (coreutils: ls/printf/cat/cp ...) silently failed to
# install and the shell was left broken.
install_pkg() {
    _pkg="$1"
    if [ -x ./pbpkgadd ] || [ -f ./pbpkgadd ]; then
        if (./pbpkgadd "$_pkg" 2>/dev/null); then
            return 0
        fi
    fi
    if unzip -o "$_pkg" >/dev/null 2>&1; then
        echo "     (pbpkgadd unavailable — extracted with unzip)"
        return 0
    fi
    return 1
}

echo ""
echo "Installing packages..."
echo ""

if [ ! -d packages ]; then
    echo "ERROR: packages/ directory missing — archive incomplete."
    exit 1
fi

for pkg in packages/*.zip
do
    [ -f "$pkg" ] || continue
    pkg_name=$(basename "$pkg")

    if [ $UPGRADE_MODE -eq 1 ]; then
        pkg_base=$(basename "$pkg" .zip)
        if should_skip_package "$pkg" "$pkg_base"; then
            echo "  SKIP $pkg_name (already installed)"
            SKIPPED_PKGS=$((SKIPPED_PKGS + 1))
            continue
        fi
        echo "  ADD  $pkg_name (new or updated)"
        if install_pkg "$pkg"; then
            NEW_PKGS=$((NEW_PKGS + 1))
        else
            echo "  FAIL $pkg_name"
            FAILED_PKGS=$((FAILED_PKGS + 1))
        fi
    else
        echo "  ADD  $pkg_name"
        if install_pkg "$pkg"; then
            UPDATED_PKGS=$((UPDATED_PKGS + 1))
        else
            echo "  FAIL $pkg_name"
            FAILED_PKGS=$((FAILED_PKGS + 1))
        fi
    fi
done

echo ""
if [ $UPGRADE_MODE -eq 1 ]; then
    echo "Package installation summary:"
    echo "  New packages installed: $NEW_PKGS"
    echo "  Existing packages preserved: $SKIPPED_PKGS"
else
    echo "Package installation complete:"
    echo "  Total packages installed: $UPDATED_PKGS"
fi
[ "$FAILED_PKGS" -gt 0 ] && echo "  FAILED packages: $FAILED_PKGS"
echo ""

# Sanity check: coreutils provides ls/printf/cat/cp. If it is missing the
# login profile breaks (alias ls='ls --color=auto' on QNX ls) and the splash
# cannot run (no printf) — so retry it once explicitly.
if [ ! -x bin/ls ] && [ -f packages/coreutils-8.29.zip ]; then
    echo "WARNING: bin/ls missing — retrying coreutils install"
    unzip -o packages/coreutils-8.29.zip >/dev/null 2>&1
    [ -x bin/ls ] && echo "  coreutils installed" || echo "  coreutils FAILED"
fi

# Move bundled bcllm from berrycore tree to misc/bcllm (same layout as qpkg install)
relocate_bcllm() {
    MISC_ROOT="/accounts/1000/shared/misc"
    MISC_BCLLM="$MISC_ROOT/bcllm"
    NT="$PWD"

    if [ -d "$NT/bcllm" ] && [ "$NT/bcllm" != "$MISC_BCLLM" ]; then
        mkdir -p "$MISC_ROOT"
        if [ -d "$MISC_BCLLM" ]; then
            _bak="$MISC_BCLLM.bak.$(date +%Y%m%d_%H%M%S)"
            mv "$MISC_BCLLM" "$_bak" 2>/dev/null && echo "Existing bcllm moved to $_bak" || rm -rf "$MISC_BCLLM"
        fi
        mv "$NT/bcllm" "$MISC_BCLLM"
        echo "BerryCore AI moved to $MISC_BCLLM"
    fi

    if [ ! -d "$MISC_BCLLM/bin" ]; then
        return 0
    fi

    chmod +x "$MISC_BCLLM/bin/"* 2>/dev/null
    mkdir -p "$MISC_BCLLM/models" "$MISC_BCLLM/var" 2>/dev/null

    if [ -x "$MISC_BCLLM/setup-ai.sh" ]; then
        export NATIVE_TOOLS="$NT"
        sh "$MISC_BCLLM/setup-ai.sh"
    else
        mkdir -p "$NT/bin"
        if [ -f "$MISC_BCLLM/bin/berrycore-ai" ]; then
            cp "$MISC_BCLLM/bin/berrycore-ai" "$NT/bin/ai"
            chmod +x "$NT/bin/ai"
            ln -sf ai "$NT/bin/AI" 2>/dev/null
            ln -sf "$MISC_BCLLM/bin/bcllm" "$NT/bin/bcllm" 2>/dev/null
        fi
        echo "Linked ai into $NT/bin (run setup-ai.sh for .profile PATH)"
    fi
}

relocate_bcllm

# Move bundled berrybridge-agent to misc/berrybridge-agent and run post-install
relocate_berrybridge_agent() {
    MISC_ROOT="/accounts/1000/shared/misc"
    MISC_AGENT="$MISC_ROOT/berrybridge-agent"
    NT="$PWD"

    if [ -d "$NT/berrybridge-agent" ] && [ "$NT/berrybridge-agent" != "$MISC_AGENT" ]; then
        mkdir -p "$MISC_ROOT"
        if [ -d "$MISC_AGENT" ]; then
            _bak="$MISC_AGENT.bak.$(date +%Y%m%d_%H%M%S)"
            mv "$MISC_AGENT" "$_bak" 2>/dev/null && echo "Existing berrybridge-agent moved to $_bak" || rm -rf "$MISC_AGENT"
        fi
        mv "$NT/berrybridge-agent" "$MISC_AGENT"
        echo "Berry Bridge agent moved to $MISC_AGENT"
    fi

    if [ ! -x "$MISC_AGENT/bin/berrybridge-run-job" ]; then
        return 0
    fi

    if [ -x "$MISC_AGENT/berrybridge-postinstall.sh" ]; then
        export NATIVE_TOOLS="$NT"
        sh "$MISC_AGENT/berrybridge-postinstall.sh" "$NT"
    elif [ -x "$MISC_AGENT/setup-berrybridge.sh" ]; then
        export NATIVE_TOOLS="$NT"
        sh "$MISC_AGENT/setup-berrybridge.sh"
    fi
}

relocate_berrybridge_agent

# Install catalog HTML to Documents (open in BB10 browser or transfer to PC)
install_catalog_html() {
    DOCS="/accounts/1000/shared/documents"
    CATALOG_NAME="berrycore.html"
    mkdir -p "$DOCS" 2>/dev/null || return 0

    if [ -f "$PWD/doc/berrycore.html" ]; then
        cp "$PWD/doc/berrycore.html" "$DOCS/$CATALOG_NAME" 2>/dev/null && \
            echo "Catalog guide installed: $DOCS/$CATALOG_NAME"
        return 0
    fi

    if [ -f "../berrycore.html" ]; then
        cp "../berrycore.html" "$DOCS/$CATALOG_NAME" 2>/dev/null && \
            echo "Catalog guide installed: $DOCS/$CATALOG_NAME"
        return 0
    fi

    echo "Note: berrycore.html not found — optional catalog guide skipped"
    return 0
}

install_catalog_html

# ---------------------------------------------------------------------------
# Write ~/.profile ONLY after a complete install. A failed/partial install
# must never replace the login profile (that is what broke Term49 before).
# ---------------------------------------------------------------------------
if [ "$NO_PROFILE" -eq 1 ]; then
    echo "Skipping ~/.profile (--no-profile)"
elif [ -f env.sh ] && [ -f sample_profile ]; then
    if [ -e "$HOME/.profile" ]; then
        BACKUP_NAME="$HOME/.profile.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.profile" "$BACKUP_NAME"
        echo "Backed up existing .profile to: $(basename $BACKUP_NAME)"
    fi

    # Always create fresh .profile to prevent errors from old configs
    sed "s|/accounts/1000/shared/misc/berrycore|$PWD|g" sample_profile > "$HOME/.profile.new"

    # Guard the splash call: if share/term49-splash.sh is missing (partial
    # install, or splash removed later) the login must not error out.
    sed 's|^\([[:space:]]*\)term49_splash[[:space:]]*$|\1command -v term49_splash >/dev/null 2>\&1 \&\& term49_splash|' \
        "$HOME/.profile.new" > "$HOME/.profile"
    rm -f "$HOME/.profile.new"

    echo "Created fresh $HOME/.profile (Term49 splash + BERRYCORE_QUIET)"
else
    echo "WARNING: install incomplete — leaving $HOME/.profile untouched"
fi

# Offer the Term49 aubergine theme without clobbering an existing .term48rc
if [ -f "$PWD/share/term48rc" ] && [ ! -e "$HOME/.term48rc" ]; then
    cp "$PWD/share/term48rc" "$HOME/.term48rc"
    echo "Installed Term49 aubergine theme: $HOME/.term48rc"
fi

echo ""
echo "==========================================================="
echo "     Installation Complete!"
echo "==========================================================="
echo ""
echo "Installation directory: $PWD"
echo ""
echo "To use BerryCore, either:"
echo "  1. Start a new shell (if .profile was created/updated)"
echo "  2. Run: source $PWD/env.sh"
echo ""
echo "Catalog & install guide: /accounts/1000/shared/documents/berrycore.html"
echo "  (or run: docs — then open berrycore.html in the browser)"
echo ""

mkdir -p etc/qnxconf/qconfig
CONFFILE="etc/qnxconf/qconfig/qnx_blackberry_native_development_kit_2.1.0.xml"

echo "<?xml version="1.0" ?>"                                     >  $CONFFILE
echo "<qnxSystemDefinition>"                                      >> $CONFFILE
echo "  <installation>"                                           >> $CONFFILE
echo "    <base>$PWD</base>"                                      >> $CONFFILE
echo "    <name>BlackBerry Native SDK for Tablet OS 2.1.0</name>" >> $CONFFILE
echo "    <host>$PWD</host>"                                      >> $CONFFILE
echo "    <target>$PWD/target/qnx6</target>"                      >> $CONFFILE
echo "  </installation>"                                          >> $CONFFILE
echo "</qnxSystemDefinition>"                                     >> $CONFFILE

mkdir -p bin
[ -f pbpkgadd ] && mv -f pbpkgadd ./bin

# Ensure all binaries have executable permissions
chmod +x bin/* 2>/dev/null

# Configure Terminal settings for better visibility
if [ "$NO_TERMCFG" -eq 1 ]; then
    echo "Skipping terminal config (--no-termcfg)"
else
    TERM_CONFIG="$HOME/.term48rc"
    if [ -f "$TERM_CONFIG" ]; then
        echo ""
        echo "Configuring Terminal settings..."

        # Backup original config (timestamped; never clobber an older backup)
        cp "$TERM_CONFIG" "$TERM_CONFIG.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null

        # Update font size to 40
        sed -i "s/font_size = [0-9]*;/font_size = 40;/" "$TERM_CONFIG" 2>/dev/null

        # Update background color to dark purple [30, 0, 30]
        sed -i "s/background_color = \[.*\];/background_color = [ 30, 0, 30 ];/" "$TERM_CONFIG" 2>/dev/null

        echo "Terminal configured: font_size=40, dark background"
        echo "Original backed up as: .term48rc.bak.<timestamp>"
    else
        echo ""
        echo "Note: Terminal config (.term48rc) not found, skipping terminal customization"
    fi
fi

echo ""
echo "==========================================================="
echo "     Welcome to BerryCore!"
echo "==========================================================="
echo ""
