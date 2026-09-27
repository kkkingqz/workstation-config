# The one list of GNOME Shell extensions of the workstation. Everything else
# reads it: enabled-extensions (dconf, written by ws switch), the EGO links,
# and ~/.config/workstation/gnome/extensions ("UUID SOURCE" per line) for
# ws-keyboard-install-extensions, ws-workstation-verify, ws-gnome-test and
# ws-gnome-status.
#
# source:
#   ubuntu  gnome-shell-ubuntu-extensions (apt); enabled by the Ubuntu session
#           mode (/usr/share/gnome-shell/modes/ubuntu.json), not written here
#   ego     extensions.gnome.org, pinned in pkgs/gnome-extensions.nix, linked
#           file by file into ~/.local/share/gnome-shell/extensions/<uuid>
#   local   gnome/extensions/<uuid> in this repository, copied (schemas
#           compiled) by ws-keyboard-install-extensions (ws apply extensions)
#
# enabled-extensions is written on every ws switch: an extension enabled or
# disabled by hand (Extension Manager, gnome-extensions) is reset by the next
# switch; add or remove it here instead. New extensions load after
# logout/login on Wayland.
{ config, lib, pkgs, ... }:
let
  extensions = [
    { uuid = "ubuntu-dock@ubuntu.com"; source = "ubuntu"; }
    { uuid = "ubuntu-appindicators@ubuntu.com"; source = "ubuntu"; }
    { uuid = "ding@rastersoft.com"; source = "ubuntu"; }
    { uuid = "tiling-assistant@ubuntu.com"; source = "ubuntu"; }
    { uuid = "snapd-prompting@canonical.com"; source = "ubuntu"; }
    { uuid = "snapd-search-provider@canonical.com"; source = "ubuntu"; }
    { uuid = "web-search-provider@ubuntu.com"; source = "ubuntu"; }

    # Used; enabled since before the repository.
    { uuid = "window-monitor-pro@muhammed.hussien2030.gmail.com"; source = "ego"; }
    # WM_CLASS bridge for xremap application filters (ws-xremap waits for it).
    { uuid = "xremap@k0kubun.com"; source = "ego"; }
    # D-Bus window control for ws-window (docs/keyboard.md).
    { uuid = "window-control@carlo9890.github.io"; source = "ego"; }

    { uuid = "workstation-smart-popup@local"; source = "local"; }
    { uuid = "workstation-input-source@local"; source = "local"; }
    { uuid = "workstation-dock-spring@local"; source = "local"; }
  ];

  bySource = source: map (e: e.uuid) (lib.filter (e: e.source == source) extensions);

  # callPackage adds override attributes; keep the packages only.
  ego = lib.filter lib.isDerivation (lib.attrValues
    (pkgs.callPackage ../../pkgs/gnome-extensions.nix { }));
  egoPinned = map (p: p.uuid) ego;

  sorted = l: lib.sort lib.lessThan l;
in
{
  assertions = [
    {
      assertion = sorted (bySource "ego") == sorted egoPinned;
      message = "gnome-extensions.nix: ego extensions (${toString (bySource "ego")}) "
        + "differ from pkgs/gnome-extensions.nix (${toString egoPinned})";
    }
    {
      assertion = lib.all (e: lib.elem e.source [ "ubuntu" "ego" "local" ]) extensions;
      message = "gnome-extensions.nix: unknown source";
    }
    {
      assertion = lib.all (u: builtins.pathExists (../../gnome/extensions + "/${u}/metadata.json"))
        (bySource "local");
      message = "gnome-extensions.nix: a local extension has no gnome/extensions/<uuid>/metadata.json";
    }
  ];

  home.file = lib.listToAttrs (map (ext:
    lib.nameValuePair ".local/share/gnome-shell/extensions/${ext.uuid}" {
      source = "${ext}/share/gnome-shell/extensions/${ext.uuid}";
      recursive = true;
    }) ego);

  dconf.settings."org/gnome/shell" = {
    enabled-extensions = bySource "ego" ++ bySource "local";
    disabled-extensions = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
  };

  xdg.configFile."workstation/gnome/extensions".text = ''
    # Built from modules/home/gnome-extensions.nix: UUID SOURCE
  '' + lib.concatMapStrings (e: "${e.uuid} ${e.source}\n") extensions;
}
