# Every machine: uinput access for xremap, ntsync for Proton in distrobox.
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
  ];
}
