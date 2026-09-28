# rEFInd boots the kernel with refind_linux.conf; GRUB is the recovery and
# fallback path. Kernel parameters come from facts.kernelParams; the
# auto-detected entry "Ubuntu" adds facts.refindDefaultParams. The manual
# entry "Ubuntu (AMD)" in refind.conf boots /boot/ws, kept on the newest
# kernel by ws-boot-links, with the same parameters minus
# refindDefaultParams (@AMD_OPTIONS@ in esp/refind.conf).
{ lib, facts, file, text, ... }:
let
  cmdline = lib.concatStringsSep " " facts.kernelParams;
  refindCmdline = lib.concatStringsSep " " (facts.kernelParams ++ facts.refindDefaultParams);
  rootArgs = "root=UUID=${facts.rootUuid} rootflags=subvol=@ rw";
in
{
  files = [
    (text "/boot/refind_linux.conf" ''
      "Ubuntu" "${rootArgs} ${refindCmdline}"

    '' "0644")
    (text "/etc/default/grub.d/10-workstation-cmdline.cfg" ''
      # Workstation kernel parameters for GRUB (recovery and fallback kernels).
      # Keep in sync with /boot/refind_linux.conf, which rEFInd uses for normal boot.
      # /etc/default/grub itself stays the package template.
      GRUB_CMDLINE_LINUX_DEFAULT="${cmdline}"
    '' "0644")
    (file "/etc/default/grub.d/99-recovery-menu.cfg" "system/files/default/grub.d/99-recovery-menu.cfg" "0644")
    (file "/usr/local/sbin/system-backup-snapshot" "system/files/usr/local/sbin/system-backup-snapshot" "0755")

    # /boot/ws for "Ubuntu (AMD)": relinked after every kernel and initramfs change.
    (file "/usr/local/sbin/ws-boot-links" "system/files/usr/local/sbin/ws-boot-links" "0755")
    (file "/etc/kernel/postinst.d/zz-ws-boot-links" "system/files/kernel/zz-ws-boot-links" "0755")
    (file "/etc/kernel/postrm.d/zz-ws-boot-links" "system/files/kernel/zz-ws-boot-links" "0755")
    (file "/etc/initramfs/post-update.d/zz-ws-boot-links" "system/files/kernel/zz-ws-boot-links" "0755")
  ];

  esp = [
    (text "EFI/BOOT/refind.conf"
      (builtins.replaceStrings [ "@AMD_OPTIONS@" ] [ "${rootArgs} ${cmdline}" ]
        (builtins.readFile ../files/esp/refind.conf)) "0644")
  ];

  # Not installed, edited or checked by content here, but part of the boot
  # state: /etc/default/grub stays the package template (settings are in
  # grub.d).
  watch = [ "/etc/default/grub" ];
}
