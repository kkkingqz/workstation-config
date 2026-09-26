# Terminal CLI from Nix; they come before the apt versions in PATH
# (~/.nix-profile/bin, 00-nix.fish). lowdown stays from apt: 3.x changes the
# man output of ws-doc-build (list spacing) and man/ is generated with 2.x.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    fzf
    zoxide
    eza
    micro
    nvd
  ];
}
