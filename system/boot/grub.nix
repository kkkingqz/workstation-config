# GRUB boots the kernel (a machine without rEFInd). Kernel parameters come
# from facts.kernelParams; GRUB finds the root itself. The menu shows for
# five seconds, so older kernels and snapshots (system-backup-snapshot) stay
# reachable.
{ lib, facts, file, text, ... }:
let
  cmdline = lib.concatStringsSep " " facts.kernelParams;
in
{
  files = [
    (text "/etc/default/grub.d/10-workstation-cmdline.cfg" ''
      # Workstation kernel parameters for GRUB.
      # /etc/default/grub itself stays the package template.
      GRUB_CMDLINE_LINUX_DEFAULT="${cmdline}"
    '' "0644")
    (file "/etc/default/grub.d/99-recovery-menu.cfg" "system/files/default/grub.d/99-recovery-menu.cfg" "0644")
    (file "/usr/local/sbin/system-backup-snapshot" "system/files/usr/local/sbin/system-backup-snapshot" "0755")
  ];

  # Not installed, edited or checked by content here, but part of the boot
  # state: /etc/default/grub stays the package template (settings are in
  # grub.d).
  watch = [ "/etc/default/grub" ];
}
