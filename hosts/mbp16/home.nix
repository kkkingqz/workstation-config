# User layer of mbp16: links into the checkout and terminal CLI; layer owners
# (wsflatpak reads modules/home/flatpak.nix; wsbox, ws-gnome, ws-keyboard*, ws-suspend) stay as they are.
{ facts, ... }:
{
  imports = [
    ../../modules/home/links.nix
    ../../modules/home/cli.nix
    ../../modules/home/xremap.nix
    ../../modules/home/man.nix
    ../../modules/home/gnome-extensions.nix
    ../../modules/home/flatpak.nix
    ../../modules/home/gnome.nix
    ../../modules/home/keyboard.nix
    ../../modules/home/distrobox.nix
  ];

  home.username = facts.user;
  home.homeDirectory = "/home/${facts.user}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Nothing may change the GNOME session or shadow apt tools yet:
  # - targets.genericLinux writes ~/.config/environment.d/10-home-manager.conf
  #   (XDG_DATA_DIRS, NIX_PATH, TERMINFO_DIRS for the whole session) and GPU
  #   drivers; GUI apps come from apt and Flatpak, so it stays off;
  # - programs.man would put Nix man before /usr/bin/man;
  # - xdg.mime would run Nix update-mime-database on ~/.local/share/mime.
  targets.genericLinux.enable = false;
  programs.man.enable = false;
  xdg.mime.enable = false;
}
