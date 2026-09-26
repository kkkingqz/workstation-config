# MacBookPro16,1 with T2: Touch Bar native mode, T2 network and firmware,
# the suspend layer (docs/suspend.md).
{ file, ... }:
{
  files = [
    # Touch Bar (ws-keyboard-system-apply)
    (file "/etc/udev/rules.d/90-touchbar-native.rules" "system/udev/90-touchbar-native.rules" "0644")
    (file "/etc/modprobe.d/tb.conf" "system/modprobe/tb.conf" "0644")
    (file "/etc/modprobe.d/touchbar-native.conf" "system/modprobe/touchbar-native.conf" "0644")
    (file "/usr/local/libexec/ws-touchbar-fn" "system/usr/local/libexec/ws-touchbar-fn" "0755")
    (file "/etc/systemd/system/ws-touchbar-fn.service" "system/systemd/system/ws-touchbar-fn.service" "0644")

    # Suspend (ws-suspend apply)
    (file "/etc/systemd/sleep.conf.d/80-deep-only.conf" "system/sleep.conf.d/80-deep-only.conf" "0644")
    (file "/etc/udev/rules.d/70-bcm4364-no-d3cold.rules" "system/udev/70-bcm4364-no-d3cold.rules" "0644")
    (file "/usr/local/sbin/broadcom-aspm-suspend-guard" "system/usr/local/sbin/broadcom-aspm-suspend-guard" "0755")
    (file "/usr/lib/systemd/system-sleep/80-broadcom-aspm" "system/usr/lib/systemd/system-sleep/80-broadcom-aspm" "0755")
    (file "/etc/systemd/system/broadcom-aspm-restore.service" "system/systemd/system/broadcom-aspm-restore.service" "0644")

    # T2 base (t2linux setup, captured in phase -1)
    (file "/etc/udev/rules.d/30-amdgpu-pm.rules" "system/udev/30-amdgpu-pm.rules" "0644")
    (file "/etc/udev/rules.d/99-network-t2-ncm.rules" "system/udev/99-network-t2-ncm.rules" "0644")
    (file "/etc/NetworkManager/conf.d/99-network-t2-ncm.conf" "system/NetworkManager/conf.d/99-network-t2-ncm.conf" "0644")
    (file "/etc/modprobe.d/apple-gmux.conf" "system/modprobe/apple-gmux.conf" "0644")
    (file "/etc/modules-load.d/t2.conf" "system/modules-load.d/t2.conf" "0644")
    (file "/etc/systemd/system/get-apple-firmware.service" "system/systemd/system/get-apple-firmware.service" "0644")
  ];

  units = {
    "ws-touchbar-fn.service" = "enabled";
    "get-apple-firmware.service" = "enabled";
    "broadcom-aspm-restore.service" = "static";
  };

  # Restarted by every `ws system apply`, as ws-keyboard-system-apply did.
  restart = [ "ws-touchbar-fn.service" ];
}
