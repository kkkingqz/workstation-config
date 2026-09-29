# Every machine: uinput access for xremap, ntsync for Proton in distrobox,
# UEFI for VMs with variables in qcow2 (helpws virt).
# watch: system files the workstation depends on but does not install;
# ws-baseline records them with the installed ones.
{ file, ... }:
{
  watch = [
    "/etc/default/keyboard" # edited by ws system apply (GDM/login: EN only)
    "/etc/fstab"
  ];

  files = [
    (file "/etc/udev/rules.d/99-workstation-uinput.rules" "system/files/udev/99-workstation-uinput.rules" "0644")
    (file "/etc/modules-load.d/ntsync.conf" "system/files/modules-load.d/ntsync.conf" "0644")
    (file "/etc/qemu/firmware/30-edk2-x86_64-secure-enrolled-qcow2-vars.json" "system/files/qemu/firmware/30-edk2-x86_64-secure-enrolled-qcow2-vars.json" "0644")
  ];
}
