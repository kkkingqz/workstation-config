# Terminal CLI from Nix, in PATH through ~/.nix-profile/bin (00-nix.fish).
# lowdown is not needed here: man pages are built in Nix (nix/pkgs/man.nix).
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
