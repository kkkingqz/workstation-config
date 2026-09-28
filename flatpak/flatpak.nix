# Flatpak declarations: user remotes, managed apps (apps.txt), per-app
# overrides and desktop overrides. wsflatpak stays the owner of apply/check
# and reads what is built here from ~/.local/share/workstation/flatpak (one link to the store):
#
#   remotes.conf      NAME URL
#   apps.conf         REMOTE APP
#   overrides/APP.conf, desktop/APP.desktop
#
# Change: edit this file or apps.txt, `ws switch`, `wsflatpak apply` (or
# `ws apply`).
# apply resets the overrides of every managed app before setting the declared
# ones, so a key removed here disappears too. Desktop overrides are linked
# into ~/.local/share/applications by home-manager.
{ lib, pkgs, ... }:
let
  remotes = {
    flathub = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    flatpark = "https://dl.flatpark.org/flatpark.flatpakrepo";
  };

  # REMOTE APP lines of apps.txt, in order; wsflatpak edits that file.
  apps = lib.concatMap (raw:
    let
      line = lib.head (lib.splitString "#" raw);
      m = builtins.match "[[:space:]]*([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]*" line;
    in
    if builtins.match "[[:space:]]*" line != null then [ ]
    else if m == null then throw "flatpak/apps.txt: invalid line: ${raw}"
    else [ { remote = lib.elemAt m 0; app = lib.elemAt m 1; } ]
  ) (lib.splitString "\n" (builtins.readFile ./apps.txt));

  # Supported: Context.filesystems (list), Environment, "Session Bus Policy"
  # (talk only) — the keys `wsflatpak apply` sets with `flatpak override`.
  overrides = {
    "com.anthropic.ClaudeDesktop" = {
      # Host files; flatpak-spawn --host for Claude Code.
      Context.filesystems = [ "host" ];
      "Session Bus Policy"."org.freedesktop.Flatpak" = "talk";
    };
    "com.anydesk.Anydesk" = {
      Environment.GDK_SCALE = "2"; # HiDPI scale
      # Tray icon.
      "Session Bus Policy"."org.kde.StatusNotifierWatcher" = "talk";
    };
  };

  # Full files, ours: Claude on Wayland at scale 1.5 with its URL handler;
  # Steam through ws-gpu (the AMD dGPU when the boot has it, Intel otherwise),
  # steam:// included.
  desktop = [
    ./desktop/com.anthropic.ClaudeDesktop.desktop
    ./desktop/com.valvesoftware.Steam.desktop
  ];

  toIni = lib.generators.toINI {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString = v:
        if lib.isList v then lib.concatMapStrings (x: "${x};") v else toString v;
    } "=";
  };

  lines = f: set: lib.concatStrings (lib.mapAttrsToList f set);

  flatpakConfig = pkgs.runCommandLocal "workstation-flatpak-config" { } (''
    mkdir -p $out/overrides $out/desktop
    cp ${pkgs.writeText "remotes.conf" (lines (n: u: "${n} ${u}\n") remotes)} $out/remotes.conf
    cp ${pkgs.writeText "apps.conf" (lib.concatMapStrings (x: "${x.remote} ${x.app}\n") apps)} $out/apps.conf
  '' + lines (app: o: ''
    cp ${pkgs.writeText "${app}.conf" (toIni o)} $out/overrides/${app}.conf
  '') overrides + lib.concatMapStrings (f: ''
    cp ${f} $out/desktop/${baseNameOf f}
  '') desktop);
in
{
  assertions = map (x: {
    assertion = remotes ? ${x.remote};
    message = "flatpak/apps.txt: ${x.app} uses undeclared remote ${x.remote}";
  }) apps;

  xdg.dataFile = {
    "workstation/flatpak".source = flatpakConfig;
  } // lib.listToAttrs (map (f:
    lib.nameValuePair "applications/${baseNameOf f}" {
      source = "${flatpakConfig}/desktop/${baseNameOf f}";
    }) desktop);

  # x-scheme-handler/claude comes from mimeinfo.cache next to the link.
  home.activation.flatpakDesktopDatabase = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -x /usr/bin/update-desktop-database ]; then
      run /usr/bin/update-desktop-database "$HOME/.local/share/applications"
    fi
  '';
}
