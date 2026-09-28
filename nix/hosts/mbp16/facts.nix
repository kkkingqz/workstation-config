# What this machine differs in from the others. New facts are added only
# when a second machine actually needs another value.
{
  user = "king";
  # The checkout of this repository, relative to $HOME. home-manager links
  # into it, bootstrap.sh insists on it; scripts find it from their own path.
  wsconfig = "wsconfig";
  hardware = "t2-mbp16";
  boot = "refind-grub-recovery";
  kernelParams = [ "quiet" "splash" "intel_iommu=on" "iommu=pt" "pm_async=off" ];
  # Only the default rEFInd entry "Ubuntu": ws-dgpu-off.service powers the
  # AMD dGPU off. "Ubuntu (AMD)" (refind.conf) and GRUB boot without it.
  refindDefaultParams = [ "ws.dgpu=off" ];
  # Btrfs with @, @home, @nix; root= in refind_linux.conf.
  rootUuid = "0cfd2add-849f-47b9-865d-2ac821ca529c";
  # rEFInd ESP (nvme0n1p3), not mounted in normal operation.
  refindEspPartuuid = "b3575417-21a5-43db-9c6e-dc2dd5510c76";
}
