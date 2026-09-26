#!/usr/bin/env bash
set -euo pipefail

# First steps on a fresh Ubuntu (docs/rebuild.md, docs/plans/nix-migration.md):
# @nix subvolume at /nix → apt packages (hosts/apt.txt, hosts/<host>/apt.txt)
# → nix-users → fish as login shell → first `ws switch`.
#
# Runs as the desktop user from the checkout in
# ~/.local/share/workstation-config and calls sudo itself. Every step checks
# the current state first, so a second run changes nothing.
#
#   ./bootstrap.sh [--dry-run]
#
# Afterwards: log out and in, then ws system apply → ws apply → log out and
# in → ws apply → ws check.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expected="$HOME/.local/share/workstation-config"
dry_run=false

die() {
    echo "bootstrap: $*" >&2
    exit 1
}

case "${1:-}" in
    --dry-run) dry_run=true ;;
    "") ;;
    *) die "usage: bootstrap.sh [--dry-run]" ;;
esac

# Commands that change the system; --dry-run only prints them.
run() {
    if [[ "$dry_run" == true ]]; then
        printf 'would run: %s\n' "$*"
    else
        "$@"
    fi
}

[[ $EUID -ne 0 ]] || die "run as the desktop user, not root"
[[ "$repo" == "$expected" ]] \
    || die "checkout must be $expected (scripts and links point there), not $repo"
command -v sudo >/dev/null 2>&1 || die "sudo not found"
[[ "$(findmnt -no FSTYPE /)" == btrfs ]] || die "/ is not Btrfs (rebuild.md, section 3)"
findmnt -no OPTIONS / | tr ',' '\n' | grep -qx 'subvol=/@' \
    || die "/ is not the subvolume @ (rebuild.md, section 3)"

host="$("$repo/bin/ws" host)"
host_list="$repo/hosts/$host/apt.txt"
[[ -r "$repo/hosts/$host/facts.nix" ]] || die "no hosts/$host/facts.nix"
echo "Host: $host"

# Package and PPA lines of the apt lists, without comments.
apt_lines() {
    local f
    for f in "$repo/hosts/apt.txt" "$host_list"; do
        [[ -r "$f" ]] && sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$f"
    done
    return 0
}

echo
echo "== 1. /nix on subvolume @nix"
root_dev="$(findmnt -no SOURCE / | sed 's/\[.*$//')"
root_uuid="$(findmnt -no UUID /)"
[[ -n "$root_uuid" ]] || die "cannot determine the UUID of /"
if findmnt -no OPTIONS /nix 2>/dev/null | tr ',' '\n' | grep -qx 'subvol=/@nix'; then
    echo "/nix is mounted from @nix"
else
    if [[ -e /nix ]] && [[ -n "$(find /nix -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        die "/nix exists, is not empty and is not @nix; move it away first"
    fi
    top=/run/btrfs-top
    run sudo install -d "$top"
    run sudo mount -o subvolid=5 "$root_dev" "$top"
    if [[ "$dry_run" == false ]] && sudo btrfs subvolume show "$top/@nix" >/dev/null 2>&1; then
        echo "@nix already exists"
    else
        run sudo btrfs subvolume create "$top/@nix"
    fi
    run sudo umount "$top"
    run sudo rmdir "$top"
    if grep -Eq '^[^#]*[[:space:]]/nix[[:space:]]' /etc/fstab; then
        echo "/nix already in fstab"
    else
        line="UUID=$root_uuid  /nix  btrfs  subvol=@nix,noatime,compress=zstd:1  0 0"
        if [[ "$dry_run" == true ]]; then
            echo "would append to /etc/fstab: $line"
        else
            sudo cp -a /etc/fstab "/etc/fstab.before-nix-$(date +%Y%m%d-%H%M%S)"
            printf '%s\n' "$line" | sudo tee -a /etc/fstab >/dev/null
        fi
    fi
    run sudo install -d -m0755 /nix
    run sudo systemctl daemon-reload
    run sudo mount /nix
fi

echo
echo "== 2. apt"
mapfile -t ppas < <(apt_lines | sed -n 's/^ppa://p')
mapfile -t packages < <(apt_lines | grep -v '^ppa:')
added=false
for ppa in "${ppas[@]}"; do
    if grep -rqsF "ppa.launchpadcontent.net/$ppa/" /etc/apt/sources.list.d/; then
        echo "PPA present: $ppa"
    else
        run sudo add-apt-repository -y --no-update "ppa:$ppa"
        added=true
    fi
done
missing=()
for pkg in "${packages[@]}"; do
    # "hold ok installed" counts too (linux-t2 is held).
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q ' ok installed$' \
        || missing+=("$pkg")
done
if ((${#missing[@]})); then
    run sudo apt-get update
    run sudo apt-get install -y --no-install-recommends "${missing[@]}"
else
    [[ "$added" == false ]] || run sudo apt-get update
    echo "all ${#packages[@]} packages installed"
fi

echo
echo "== 3. Nix daemon and nix-users"
if systemctl is-enabled --quiet nix-daemon.socket 2>/dev/null \
    && systemctl is-active --quiet nix-daemon.socket; then
    echo "nix-daemon.socket enabled and active"
else
    run sudo systemctl enable --now nix-daemon.socket
fi
user="$(id -un)"
if getent group nix-users | cut -d: -f4 | tr ',' '\n' | grep -qx "$user"; then
    echo "$user is in nix-users"
else
    run sudo usermod -aG nix-users "$user"
fi

echo
echo "== 4. Login shell"
if [[ "$(getent passwd "$user" | cut -d: -f7)" == /usr/bin/fish ]]; then
    echo "login shell is fish"
else
    run sudo chsh -s /usr/bin/fish "$user"
fi

echo
echo "== 5. First ws switch"
# Before the first switch there is no ~/.config/nix/nix.conf yet, and the
# nix-users membership applies only to new logins: sg runs the switch with it.
# Files home-manager would replace are kept as *.pre-hm.
if [[ "$dry_run" == true ]]; then
    echo "would run: sg nix-users -c 'NIX_CONFIG=... $repo/bin/ws switch -b pre-hm'"
else
    sg nix-users -c "NIX_CONFIG='experimental-features = nix-command flakes' '$repo/bin/ws' switch -b pre-hm"
fi

echo
echo "Done. Log out and in (nix-users, PATH from 00-nix.fish), then:"
echo "  ws system apply     # system files (sudo)"
echo "  ws apply            # user layer; log out and in; ws apply again"
echo "  ws check"
