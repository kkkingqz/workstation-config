# rEFInd boots the kernel with refind_linux.conf; GRUB is the recovery and
# fallback path. Kernel parameters come from facts.kernelParams.
{ lib, facts, file, text, ... }:
let
  cmdline = lib.concatStringsSep " " facts.kernelParams;
in
{
  files = [
    (text "/boot/refind_linux.conf" ''
      "Ubuntu" "root=UUID=${facts.rootUuid} rootflags=subvol=@ rw ${cmdline}"

    '' "0644")
    (text "/etc/default/grub.d/10-workstation-cmdline.cfg" ''
      # Workstation kernel parameters for GRUB (recovery and fallback kernels).
      # Keep in sync with /boot/refind_linux.conf, which rEFInd uses for normal boot.
      # /etc/default/grub itself stays the package template.
      GRUB_CMDLINE_LINUX_DEFAULT="${cmdline}"
    '' "0644")
    (file "/etc/default/grub.d/99-recovery-menu.cfg" "system/default/grub.d/99-recovery-menu.cfg" "0644")
    (file "/usr/local/sbin/system-backup-snapshot" "system/usr/local/sbin/system-backup-snapshot" "0755")
  ];

  esp = [
    (file "EFI/BOOT/refind.conf" "system/esp/refind.conf" "0644")
  ];
}
