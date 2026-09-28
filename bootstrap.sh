#!/usr/bin/env bash
set -euo pipefail

# First steps on a fresh Ubuntu (helpws rebuild, helpws history-nix):
# @nix subvolume at /nix → apt packages (nix/hosts/apt.txt, nix/hosts/<host>/apt.txt)
# → VM storage @vms at /var/lib/libvirt/images, pool and network → groups
# nix-users, libvirt → fish as login shell → first `ws switch`.
#
# Runs as the desktop user from the checkout at ~/<wsconfig of
# nix/hosts/<host>/facts.nix> and calls sudo itself. Every step checks
# the current state first, so a second run changes nothing.
#
#   ./bootstrap.sh [--dry-run]
#
# Afterwards: log out and in, then ws system apply → ws apply → log out and
# in → ws apply → ws check.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
command -v sudo >/dev/null 2>&1 || die "sudo not found"
[[ "$(findmnt -no FSTYPE /)" == btrfs ]] || die "/ is not Btrfs (rebuild.md, section 3)"
findmnt -no OPTIONS / | tr ',' '\n' | grep -qx 'subvol=/@' \
    || die "/ is not the subvolume @ (rebuild.md, section 3)"

host="$("$repo/bin/ws" host)"
host_list="$repo/nix/hosts/$host/apt.txt"
[[ -r "$repo/nix/hosts/$host/facts.nix" ]] || die "no nix/hosts/$host/facts.nix"
# The checkout path is a fact of the host: home-manager links point there.
expected="$HOME/$(sed -nE 's/^[[:space:]]*wsconfig = "([^"]+)";.*/\1/p' "$repo/nix/hosts/$host/facts.nix")"
[[ "$expected" != "$HOME/" ]] || die "no wsconfig in nix/hosts/$host/facts.nix"
[[ "$repo" == "$expected" ]] \
    || die "checkout must be $expected (wsconfig in nix/hosts/$host/facts.nix), not $repo"
echo "Host: $host"

# Package and PPA lines of the apt lists, without comments.
apt_lines() {
    local f
    for f in "$repo/nix/hosts/apt.txt" "$host_list"; do
        [[ -r "$f" ]] && sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$f"
    done
    return 0
}

root_dev="$(findmnt -no SOURCE / | sed 's/\[.*$//')"
root_uuid="$(findmnt -no UUID /)"
[[ -n "$root_uuid" ]] || die "cannot determine the UUID of /"

# Subvolume NAME of the root filesystem mounted at DIR by an fstab line with
# OPTIONS. DIR must not hold data yet: it would be hidden by the mount.
subvolume_mount() {
    local name="$1" dir="$2" options="$3" top=/run/btrfs-top line
    if findmnt -no OPTIONS "$dir" 2>/dev/null | tr ',' '\n' | grep -qx "subvol=/$name"; then
        echo "$dir is mounted from $name"
        return
    fi
    if [[ -e "$dir" ]] && [[ -n "$(sudo find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        die "$dir exists, is not empty and is not $name; move its content away first"
    fi
    run sudo install -d "$top"
    run sudo mount -o subvolid=5 "$root_dev" "$top"
    if [[ "$dry_run" == false ]] && sudo btrfs subvolume show "$top/$name" >/dev/null 2>&1; then
        echo "$name already exists"
    else
        run sudo btrfs subvolume create "$top/$name"
    fi
    run sudo umount "$top"
    run sudo rmdir "$top"
    if grep -Eq "^[^#]*[[:space:]]$dir[[:space:]]" /etc/fstab; then
        echo "$dir already in fstab"
    else
        line="UUID=$root_uuid  $dir  btrfs  subvol=$name,$options  0 0"
        if [[ "$dry_run" == true ]]; then
            echo "would append to /etc/fstab: $line"
        else
            sudo cp -a /etc/fstab "/etc/fstab.before-$name-$(date +%Y%m%d-%H%M%S)"
            printf '%s\n' "$line" | sudo tee -a /etc/fstab >/dev/null
        fi
    fi
    run sudo install -d -m0755 "$dir"
    run sudo systemctl daemon-reload
    run sudo mount "$dir"
}

echo
echo "== 1. /nix on subvolume @nix"
subvolume_mount @nix /nix noatime,compress=zstd:1

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
echo "== 3. VM storage and libvirt (helpws virt)"
# Disk images on their own subvolume: outside the snapshots of @ (a rollback
# of @ leaves the VMs alone), without copy-on-write (qcow2 on CoW Btrfs
# fragments). The directory is libvirt's default pool; the libvirt group
# may add images and ISOs there (~/VMs links to it).
images=/var/lib/libvirt/images
subvolume_mount @vms "$images" noatime
if [[ "$dry_run" == false ]] && lsattr -d "$images" 2>/dev/null | cut -d' ' -f1 | grep -q C; then
    echo "$images: no copy-on-write"
else
    run sudo chattr +C "$images"
fi
if [[ "$(stat -c '%U:%G %a' "$images" 2>/dev/null)" == "root:libvirt 2775" ]]; then
    echo "$images: root:libvirt 2775"
else
    run sudo chown root:libvirt "$images"
    run sudo chmod 2775 "$images"
fi
virsh=(sudo virsh -q -c qemu:///system)
# Output first, then grep: grep -q stops reading, virsh gets SIGPIPE, and
# pipefail would count the match as a failure.
info_of() {
    [[ "$dry_run" == false ]] || return 0
    "${virsh[@]}" "$@" 2>/dev/null || true
}
if [[ -n "$(info_of pool-info default)" ]]; then
    echo "pool default defined"
else
    run "${virsh[@]}" pool-define-as default dir --target "$images"
fi
if grep -Eq '^Autostart:[[:space:]]+yes' <<<"$(info_of pool-info default)"; then
    echo "pool default autostarts"
else
    run "${virsh[@]}" pool-autostart default
fi
if grep -Eq '^State:[[:space:]]+running' <<<"$(info_of pool-info default)"; then
    echo "pool default running"
else
    run "${virsh[@]}" pool-start default
fi
# NAT network of the package (virbr0); Wi-Fi cannot be bridged.
if grep -Eq '^Autostart:[[:space:]]+yes' <<<"$(info_of net-info default)"; then
    echo "network default autostarts"
else
    run "${virsh[@]}" net-autostart default
fi
if grep -Eq '^Active:[[:space:]]+yes' <<<"$(info_of net-info default)"; then
    echo "network default active"
else
    run "${virsh[@]}" net-start default
fi

echo
echo "== 4. Nix daemon and groups"
if systemctl is-enabled --quiet nix-daemon.socket 2>/dev/null \
    && systemctl is-active --quiet nix-daemon.socket; then
    echo "nix-daemon.socket enabled and active"
else
    run sudo systemctl enable --now nix-daemon.socket
fi
user="$(id -un)"
for group in nix-users libvirt; do
    if getent group "$group" | cut -d: -f4 | tr ',' '\n' | grep -qx "$user"; then
        echo "$user is in $group"
    else
        run sudo usermod -aG "$group" "$user"
    fi
done

echo
echo "== 5. Login shell"
if [[ "$(getent passwd "$user" | cut -d: -f7)" == /usr/bin/fish ]]; then
    echo "login shell is fish"
else
    run sudo chsh -s /usr/bin/fish "$user"
fi

echo
echo "== 6. First ws switch"
# Before the first switch there is no ~/.config/nix/nix.conf yet, and the
# nix-users membership applies only to new logins: sg runs the switch with it.
# Files home-manager would replace are kept as *.pre-hm.
if [[ "$dry_run" == true ]]; then
    echo "would run: sg nix-users -c 'NIX_CONFIG=... $repo/bin/ws switch -b pre-hm'"
else
    sg nix-users -c "NIX_CONFIG='experimental-features = nix-command flakes' '$repo/bin/ws' switch -b pre-hm"
fi

echo
echo "Done. Log out and in (nix-users, libvirt, PATH from 00-nix.fish), then:"
echo "  ws system apply     # system files (sudo)"
echo "  ws apply            # user layer; log out and in; ws apply again"
echo "  ws check"
