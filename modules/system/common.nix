# Every machine: uinput access for xremap, ntsync for Proton in distrobox.
{ file, ... }:
{
  files = [
    (file "/etc/udev/rules.d/99-workstation-uinput.rules" "system/udev/99-workstation-uinput.rules" "0644")
    (file "/etc/modules-load.d/ntsync.conf" "config/distrobox/host/modules-load.d/ntsync.conf" "0644")
  ];
}
