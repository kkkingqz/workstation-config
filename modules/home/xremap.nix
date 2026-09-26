# xremap binary from Nix (pkgs/xremap.nix). ws-xremap finds it through the
# PATH of xremap.service (~/.local/bin first), as before; the unit, xremap.yml
# and ws-xremap stay with ws-keyboard-apply.
{ xremap, ... }:
{
  home.file.".local/bin/xremap".source = "${xremap}/bin/xremap";
}
