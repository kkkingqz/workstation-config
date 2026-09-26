# User layer of mbp16. Phase 0: an empty home-manager generation; layer owners
# (wsflatpak, wsbox, ws-gnome, ws-keyboard*, ws-suspend) stay as they are.
{ facts, ... }:
{
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
