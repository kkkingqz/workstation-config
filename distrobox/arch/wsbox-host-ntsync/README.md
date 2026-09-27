# wsbox-host-ntsync

`wsbox-host-ntsync` is a deliberately empty Arch package for the `arch`
Distrobox managed by this workstation configuration.

The Distrobox container uses the host kernel. The real NTSync kernel module
is therefore loaded on the Ubuntu host, and `/dev/ntsync` is passed through
to the container.

Arch Linux package `ntsync-autoload` depends on the virtual capability
`NTSYNC-MODULE`. Without this provider, pacman/paru may satisfy that
capability by installing an Arch kernel package inside the container,
together with `mkinitcpio` and initramfs files that are not used by Distrobox.

This package provides only the virtual capability:

    NTSYNC-MODULE

It does not contain a kernel module and must only be installed when the host
kernel actually provides NTSync and `/dev/ntsync` is available to the
container.

Expected recovery order:

1. Load `ntsync` on the host.
2. Build and install this package in the Arch Distrobox.
3. Install Wine / WinBox.
4. Run `wsbox apply arch` to restore managed application exports.
