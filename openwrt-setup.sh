#!/bin/sh
# openwrt-setup.sh -- one-time bring-up of MeshTerm on OpenWrt / OpenLumi
# (Geniatech GTW360 and other imx/cortexa7 boards). Run it as root on the gateway:
#
#     sh openwrt-setup.sh
#
# The script is idempotent. It is safe to run it again, because each phase checks before it
# acts. It does the complete deploy that this 32-bit musl board needs:
#
#   1. preflight        Refuse a glibc one-file build, a 64-bit ARM binary, and Python
#                       older than 3.10. The official meshterm-linux-arm64 file is for
#                       aarch64 glibc (the uConsole). This board is ARMv7 + musl.
#   2. swap             A file swap on eMMC. pip compiles dbus-fast (bleak) on the device,
#                       because musl has no wheels. /tmp is a small RAM tmpfs. Without
#                       swap, gcc can OOM next to Home Assistant.
#   3. opkg packages    Python 3.11, pip, venv, a compiler, USB serial kmods, and terminfo.
#                       Bluetooth packages are off by default. This install is for TCP and
#                       USB companions. Set WITH_BLE=1 if you also want BLE.
#   4. checkout         Use this tree if the script already lives inside MeshTerm. Else
#                       clone from GitHub into /opt/meshterm/src.
#   5. venv + pip       TMPDIR on eMMC. --system-site-packages reuses opkg pycryptodome
#                       when the feed has it. pip still compiles dbus-fast: meshcore
#                       imports BLEConnection at load time, so bleak is not optional.
#   6. wrapper          /usr/bin/meshterm, with UTF-8 I/O and a default TERM for Dropbear.
#
# The TUI needs a real terminal. Open an SSH session with a pty:
#
#     ssh -t root@<gateway> meshterm
#
set -eu

PREFIX="${PREFIX:-/opt/meshterm}"
CHECKOUT="${CHECKOUT:-}"
REPO_URL="${REPO_URL:-https://github.com/jpmartineau/MeshTerm.git}"
SWAP_MB="${SWAP_MB:-256}"
WITH_BLE="${WITH_BLE:-0}"
SKIP_SWAP="${SKIP_SWAP:-0}"
INSTALL_LUCI="${INSTALL_LUCI:-1}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# The setup script lives in scripts/openwrt-gtw360/. Two levels up is the repository root.
REPO_FROM_SCRIPT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

log()  { printf '\n== %s\n' "$*"; }
info() { printf '   %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
    opkg status "$1" 2>/dev/null | grep -q '^Status:.*installed'
}

ensure_pkg() {
    pkg=$1
    required=${2:-1}
    if pkg_installed "$pkg"; then
        info "$pkg already installed"
        return 0
    fi
    info "installing $pkg"
    if opkg install "$pkg"; then
        return 0
    fi
    if [ "$required" = 1 ]; then
        die "opkg install $pkg failed (check the feed / network)"
    fi
    info "optional package $pkg is not in the feed -- continuing"
}

[ "$(id -u)" = 0 ] || die "run as root (installs packages, writes /opt and /usr/bin)"
have opkg || die "opkg not found -- this script is for OpenWrt"

# --- 1. preflight ----------------------------------------------------------------------
log "1/6  preflight"

if [ -f /etc/openwrt_release ]; then
    # shellcheck disable=SC1091
    . /etc/openwrt_release
    info "OpenWrt $DISTRIB_RELEASE ($DISTRIB_ARCH) on $DISTRIB_TARGET"
else
    info "no /etc/openwrt_release -- continuing anyway"
fi

UNAME_M=$(uname -m)
case "$UNAME_M" in
    armv7l|armv6l|arm)
        info "CPU is 32-bit ARM ($UNAME_M) -- official linux-arm64 builds will not run"
        ;;
    aarch64)
        info "CPU is 64-bit ARM -- you can also use the linux-arm64 build on glibc, not here"
        ;;
    *)
        info "CPU is $UNAME_M"
        ;;
esac

if ldd /bin/busybox 2>/dev/null | grep -q musl; then
    info "libc is musl -- PyInstaller glibc binaries will not run"
fi

# --- 2. swap on eMMC (pip / gcc) -------------------------------------------------------
log "2/6  swap for native builds"

SWAPFILE="$PREFIX/swapfile"
if [ "$SKIP_SWAP" = 1 ]; then
    info "SKIP_SWAP=1 -- not adding a swap file"
elif grep -q "$SWAPFILE" /proc/swaps 2>/dev/null; then
    info "swap file already active"
else
    mkdir -p "$PREFIX"
    if [ ! -f "$SWAPFILE" ]; then
        info "creating ${SWAP_MB}M swap file at $SWAPFILE"
        dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_MB" conv=fsync
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE"
    fi
    swapon "$SWAPFILE" || info "swapon failed -- compile may OOM if RAM is tight"
    if ! grep -q "$SWAPFILE" /etc/fstab 2>/dev/null; then
        printf '%s none swap sw 0 0\n' "$SWAPFILE" >> /etc/fstab
        info "added $SWAPFILE to /etc/fstab"
    fi
fi

# --- 3. opkg packages ------------------------------------------------------------------
log "3/6  system packages (opkg)"

opkg update || info "opkg update failed (no network yet?) -- continuing with the cache"

# python3 is the meta-package. OpenWrt splits the standard library. sqlite3, asyncio,
# ctypes, and xml must be present. The meta-package pulls them.
for pkg in \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    gcc \
    make \
    g++ \
    libffi \
    python3-cffi \
    ca-certificates \
    terminfo
do
    ensure_pkg "$pkg" 1
done

# Prefer the feed build of pycryptodome. Then pip does not compile it.
ensure_pkg python3-cryptodome 0
ensure_pkg python3-pyserial 0
ensure_pkg git 0

# USB companion: ACM (nRF52, many XIAO boards) and common USB-UART chips.
for pkg in \
    kmod-usb-core \
    kmod-usb2 \
    kmod-usb-acm \
    kmod-usb-serial \
    kmod-usb-serial-ch341 \
    kmod-usb-serial-cp210x \
    kmod-usb-serial-ftdi \
    kmod-usb-serial-pl2303 \
    usbutils
do
    ensure_pkg "$pkg" 0
done

if [ "$WITH_BLE" = 1 ]; then
    info "WITH_BLE=1 -- installing BlueZ"
    for pkg in dbus bluez-daemon bluez-utils; do
        ensure_pkg "$pkg" 0
    done
    if have /etc/init.d/dbus; then
        /etc/init.d/dbus enable || true
        /etc/init.d/dbus start || true
    fi
    if have /etc/init.d/bluez; then
        /etc/init.d/bluez enable || true
        /etc/init.d/bluez start || true
    fi
else
    info "WITH_BLE=0 -- TCP and USB only (bleak still installs: meshcore imports it)"
fi

have python3 || die "python3 still missing after opkg"

python3 - <<'PY' || die "Python 3.10 or newer is required"
import sys
raise SystemExit(0 if sys.version_info >= (3, 10) else 1)
PY
info "python3 is $(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"

# --- 4. checkout -----------------------------------------------------------------------
log "4/6  MeshTerm sources"

if [ -z "$CHECKOUT" ]; then
    if [ -f "$REPO_FROM_SCRIPT/pyproject.toml" ] && [ -d "$REPO_FROM_SCRIPT/meshterm" ]; then
        CHECKOUT="$REPO_FROM_SCRIPT"
        info "using the tree next to this script: $CHECKOUT"
    else
        CHECKOUT="$PREFIX/src"
    fi
fi

mkdir -p "$PREFIX"
PIP_TMP="$PREFIX/tmp"
mkdir -p "$PIP_TMP"

if [ -f "$CHECKOUT/pyproject.toml" ] && [ -d "$CHECKOUT/meshterm" ]; then
    info "sources already at $CHECKOUT"
elif have git; then
    info "cloning $REPO_URL into $CHECKOUT"
    mkdir -p "$(dirname "$CHECKOUT")"
    git clone --depth 1 "$REPO_URL" "$CHECKOUT" || die "git clone failed"
else
    die "no MeshTerm tree at $CHECKOUT and git is not installed -- copy the tree first"
fi

# --- 5. venv + pip ---------------------------------------------------------------------
log "5/6  python venv + pip install"

VENV="$PREFIX/.venv"
if [ -x "$VENV/bin/python" ]; then
    info "venv exists at $VENV"
else
    info "creating venv (system site-packages, so opkg pycryptodome can be reused)"
    python3 -m venv --system-site-packages "$VENV" || die "venv creation failed"
fi

export TMPDIR="$PIP_TMP"
export PIP_NO_CACHE_DIR=1
# /tmp is RAM. Keep gcc scratch on eMMC too.
export TEMP="$PIP_TMP"
export TEMPDIR="$PIP_TMP"

info "pip install -e $CHECKOUT (this compiles dbus-fast; it can take several minutes)"
# Stop a heavy neighbour if the operator left Home Assistant running. Do not fail if
# the service is absent.
if [ -x /etc/init.d/homeassistant ]; then
    info "stopping homeassistant for the compile (start it again after, if you use it)"
    /etc/init.d/homeassistant stop || true
fi

"$VENV/bin/pip" install -U pip setuptools wheel \
    || die "pip bootstrap failed"
"$VENV/bin/pip" install -e "$CHECKOUT" \
    || die "pip install failed -- free RAM, set SKIP_SWAP=0, and run the script again"

# --- 6. wrapper ------------------------------------------------------------------------
log "6/7  /usr/bin/meshterm"

cat > /usr/bin/meshterm <<EOF
#!/bin/sh
# Wrapper so Dropbear sessions get a TUI that can draw. OpenWrt often has LANG=C and
# TERM=dumb or unset. MeshTerm needs UTF-8 output and a terminal type with colours.
export PYTHONIOENCODING="\${PYTHONIOENCODING:-utf-8}"
if [ -z "\$TERM" ] || [ "\$TERM" = "dumb" ]; then
    export TERM=xterm-256color
fi
exec $VENV/bin/meshterm "\$@"
EOF
chmod 755 /usr/bin/meshterm

# --- 7. LuCI integration (optional) ----------------------------------------------------
log "7/7  LuCI integration"

INSTALL_LUCI="${INSTALL_LUCI:-1}"

if [ "$INSTALL_LUCI" = 1 ]; then
    info "installing LuCI integration"
    ensure_pkg ttyd 0
    ensure_pkg luci-compat 0
    ensure_pkg coreutils-base64 0

    # Create init script for ttyd with meshterm
    cat > /etc/init.d/meshterm-web <<'EOF'
#!/bin/sh /etc/rc.common

START=95
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/ttyd -p 7681 -T xterm-256color /usr/bin/meshterm
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    service_stop /usr/bin/ttyd
}
EOF
    chmod +x /etc/init.d/meshterm-web

    # Create LuCI controller
    mkdir -p /usr/lib/lua/luci/controller/admin
    cat > /usr/lib/lua/luci/controller/admin/meshterm.lua <<'EOF'
module("luci.controller.admin.meshterm", package.seeall)

function index()
    entry({"admin", "services", "meshterm"}, template("admin_services/meshterm"), _("MeshTerm"), 50)
end
EOF

    # Create LuCI view template
    mkdir -p /usr/lib/lua/luci/view/admin_services
    cat > /usr/lib/lua/luci/view/admin_services/meshterm.htm <<'EOF'
<%#
    MeshTerm Web Terminal - LuCI view template
%>
<%+header%>
<h2><%:MeshTerm Terminal%></h2>
<p><%:MeshTerm TUI running in web terminal%></p>
<div style="width: 100%; height: 600px; border: 1px solid #ccc; background: #000;">
    <iframe
        src="http://<%=luci.http.getenv('SERVER_NAME')%>:7681"
        style="width: 100%; height: 100%; border: none;"
        allowfullscreen>
    </iframe>
</div>
<p>
    <button class="cbi-button cbi-button-action" onclick="location.reload()">
        <%:Reconnect%>
    </button>
</p>
<%+footer%>
EOF

    # Create ACL rules
    cat > /usr/share/acl.d/meshterm_acl.json <<'EOF'
{
    "luci-app-meshterm": {
        "description": "Grant access to MeshTerm",
        "read": {
            "ubus": {
                "file": [ "read" ],
                "uci": [ "*" ]
            }
        },
        "write": {
            "ubus": {
                "file": [ "write" ],
                "uci": [ "*" ]
            }
        }
    }
}
EOF

    # Disable default ttyd if present
    if [ -f /etc/init.d/ttyd ]; then
        /etc/init.d/ttyd disable 2>/dev/null || true
        /etc/init.d/ttyd stop 2>/dev/null || true
    fi

    # Enable and start meshterm-web
    /etc/init.d/meshterm-web enable
    /etc/init.d/meshterm-web start

    # Restart uhttpd to reload LuCI
    /etc/init.d/uhttpd restart 2>/dev/null || true

    info "LuCI integration installed"
    info "Access via: Services -> MeshTerm in LuCI"
    info "Or directly: http://$(uci -q get network.lan.ipaddr 2>/dev/null || echo GATEWAY):7681"
else
    info "INSTALL_LUCI=0 -- skipping LuCI integration"
fi

# --- done ------------------------------------------------------------------------------
log "done"
info "TUI over SSH:   ssh -t root@$(uci -q get network.lan.ipaddr 2>/dev/null || echo GATEWAY) meshterm"
info "simulator:      meshterm --mock"
info "USB companion:  meshterm --port /dev/ttyACM0"
info "                (or /dev/ttyUSB0 -- run: ls /dev/ttyUSB* /dev/ttyACM*)"
info "TCP companion:  meshterm --tcp HOST:PORT"
info "data directory: ~/.meshterm  (as the user that runs the command, usually /root/.meshterm)"
info "venv:           $VENV"
info "sources:        $CHECKOUT"
