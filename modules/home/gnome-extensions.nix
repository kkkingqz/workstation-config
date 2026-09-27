# EGO extensions (pkgs/gnome-extensions.nix) in ~/.local/share/gnome-shell/
# extensions/<uuid>, one link per file. Enabling stays with GNOME
# (org.gnome.shell enabled-extensions); workstation-*@local extensions stay
# with ws-keyboard-install-extensions.
{ lib, pkgs, ... }:
let
  # callPackage adds override attributes; keep the packages only.
  exts = lib.filterAttrs (_: lib.isDerivation)
    (pkgs.callPackage ../../pkgs/gnome-extensions.nix { });
in
{
  home.file = lib.mapAttrs' (_: ext:
    lib.nameValuePair ".local/share/gnome-shell/extensions/${ext.uuid}" {
      source = "${ext}/share/gnome-shell/extensions/${ext.uuid}";
      recursive = true;
    }) exts;
}
