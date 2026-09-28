# Virtual machines (helpws virt). The host layer is apt (nix/hosts/apt.txt)
# and bootstrap.sh: subvolume @vms at /var/lib/libvirt/images (libvirt pool
# `default`, no copy-on-write), NAT network `default`, group libvirt. VM
# definitions are libvirt state, not declared here; ws collect keeps their
# XML. Here: the user side.
{ config, ... }:
{
  # Disk images and ISOs, reachable from $HOME.
  home.file."VMs".source = config.lib.file.mkOutOfStoreSymlink "/var/lib/libvirt/images";
}
