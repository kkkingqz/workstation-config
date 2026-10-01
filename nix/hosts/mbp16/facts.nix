# What this machine differs in from the others. New facts are added only
# when a second machine actually needs another value.
{
  # `ws host` finds the host by it.
  hostname = "MacBookPro-k";
  user = "king";
  # The checkout of this repository, relative to $HOME. home-manager links
  # into it, bootstrap.sh insists on it; scripts find it from their own path.
  wsconfig = "wsconfig";
  hardware = "t2-mbp16";
  boot = "refind-grub-recovery";
  kernelParams = [ "quiet" "splash" "intel_iommu=on" "iommu=pt" "pm_async=off" ];
  # Only the default rEFInd entry "Ubuntu": ws-dgpu-off.service powers the
  # AMD dGPU off and parks its CPU port, and the kernel owns ASPM with the
  # powersave policy (L1 on Thunderbolt, Clock PM; helpws suspend, ASPM).
  # amdgpu gets the panel's EDID for its eDP connector (the panel is muxed
  # to i915, eDP-2 never answers: 25 DDC retries, ~6 s before ws-dgpu-off
  # can switch the card off and GDM may start; helpws workstation, GRAPHICS).
  # "Ubuntu (AMD)" (refind.conf) and GRUB (recovery) boot without them.
  refindDefaultParams = [
    "ws.dgpu=off" "pcie_aspm=force" "pcie_aspm.policy=powersave"
    "drm.edid_firmware=eDP-2:edid/mbp16-edp.bin"
  ];
  # Btrfs with @, @home, @nix; root= in refind_linux.conf.
  rootUuid = "0cfd2add-849f-47b9-865d-2ac821ca529c";
  # rEFInd ESP (nvme0n1p3), not mounted in normal operation.
  refindEspPartuuid = "b3575417-21a5-43db-9c6e-dc2dd5510c76";
}
