# MacBookPro16,1 with T2: Touch Bar native mode, T2 network and firmware,
# the suspend layer (helpws suspend), dGPU power-off at boot.
{ file, ... }:
{
  files = [
    # Touch Bar (ws-keyboard-system-apply)
    (file "/etc/udev/rules.d/90-touchbar-native.rules" "system/files/udev/90-touchbar-native.rules" "0644")
    (file "/etc/modprobe.d/tb.conf" "system/files/modprobe/tb.conf" "0644")
    (file "/etc/modprobe.d/touchbar-native.conf" "system/files/modprobe/touchbar-native.conf" "0644")
    (file "/usr/local/libexec/ws-touchbar-fn" "system/files/usr/local/libexec/ws-touchbar-fn" "0755")
    (file "/etc/systemd/system/ws-touchbar-fn.service" "system/files/systemd/system/ws-touchbar-fn.service" "0644")

    # Suspend (ws-suspend apply)
    (file "/etc/systemd/sleep.conf.d/80-deep-only.conf" "system/files/sleep.conf.d/80-deep-only.conf" "0644")
    (file "/etc/udev/rules.d/70-bcm4364-no-d3cold.rules" "system/files/udev/70-bcm4364-no-d3cold.rules" "0644")
    (file "/etc/udev/rules.d/71-tb-xhci-awake.rules" "system/files/udev/71-tb-xhci-awake.rules" "0644")
    (file "/usr/local/sbin/broadcom-aspm-suspend-guard" "system/files/usr/local/sbin/broadcom-aspm-suspend-guard" "0755")
    (file "/usr/lib/systemd/system-sleep/80-broadcom-aspm" "system/files/usr/lib/systemd/system-sleep/80-broadcom-aspm" "0755")
    (file "/etc/systemd/system/broadcom-aspm-restore.service" "system/files/systemd/system/broadcom-aspm-restore.service" "0644")

    # AMD dGPU off and off the PCI bus when booted with ws.dgpu=off (rEFInd "Ubuntu")
    (file "/usr/local/sbin/ws-dgpu-off" "system/files/usr/local/sbin/ws-dgpu-off" "0755")
    (file "/etc/systemd/system/ws-dgpu-off.service" "system/files/systemd/system/ws-dgpu-off.service" "0644")
    # t2gmux instead of apple-gmux (helpws plan-dgpu): not loaded by alias
    # until the switch; a test boot uses ws.gmux=t2.
    (file "/etc/modprobe.d/t2gmux.conf" "system/files/modprobe/t2gmux.conf" "0644")

    # T2 base (t2linux setup, captured in phase -1)
    (file "/etc/udev/rules.d/30-amdgpu-pm.rules" "system/files/udev/30-amdgpu-pm.rules" "0644")
    (file "/etc/udev/rules.d/99-network-t2-ncm.rules" "system/files/udev/99-network-t2-ncm.rules" "0644")
    (file "/etc/NetworkManager/conf.d/99-network-t2-ncm.conf" "system/files/NetworkManager/conf.d/99-network-t2-ncm.conf" "0644")
    (file "/etc/modprobe.d/apple-gmux.conf" "system/files/modprobe/apple-gmux.conf" "0644")
    (file "/etc/modules-load.d/t2.conf" "system/files/modules-load.d/t2.conf" "0644")
    (file "/etc/systemd/system/get-apple-firmware.service" "system/files/systemd/system/get-apple-firmware.service" "0644")
  ];

  units = {
    "ws-touchbar-fn.service" = "enabled";
    "get-apple-firmware.service" = "enabled";
    "ws-dgpu-off.service" = "enabled";
    "broadcom-aspm-restore.service" = "static";
  };

  # Restarted by every `ws system apply`, as ws-keyboard-system-apply did.
  restart = [ "ws-touchbar-fn.service" ];
}
