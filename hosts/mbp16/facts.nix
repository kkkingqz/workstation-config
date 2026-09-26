# What this machine differs in from the others. New facts are added only
# when a second machine actually needs another value.
{
  user = "king";
  hardware = "t2-mbp16";
  boot = "refind-grub-recovery";
  kernelParams = [ "quiet" "splash" "intel_iommu=on" "iommu=pt" "pm_async=off" ];
}
