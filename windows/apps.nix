# Windows programs with a GNOME launcher. The boxes and their profiles are in
# distrobox/distrobox.nix; wswin installs and runs (helpws windows).
#
# Built into ~/.local/share/workstation/windows/apps.ini for wswin and one
# launcher ~/.local/share/applications/ws-win-NAME.desktop per program
# (Exec: wswin run NAME).
#
#   box      Windows box; default: defaultBox
#   prefix   "default" ($HOME/.wine of the box) or the name of an own prefix
#            ($HOME/prefixes/NAME); default: "default"
#   exe      path inside the prefix (drive_c/...)
#   args     arguments, split at spaces
#   env      KEY=VALUE ..., split at spaces
#   icon     theme icon name, or a file inside the prefix (has a dot: "winbox.png")
#   title, categories, wmClass (default: the exe file name)
#
# Add a program: wswin install [--box BOX] [--prefix NAME] SETUP.exe, then
# an entry here, ws switch.
{ config, lib, ... }:
let
  defaultBox = "wine-wayland";

  apps = {
    winbox = {
      title = "WinBox 3";
      box = "wine";
      prefix = "winbox";
      exe = "drive_c/Program Files/WinBox/winbox.exe";
      # No Mono prompt: WinBox does not use .NET.
      env = "WINEDLLOVERRIDES=mscoree=";
      # From the AUR winbox3 package, copied into the prefix.
      icon = "winbox.png";
      categories = "Network;RemoteAccess;";
    };
  };

  withDefaults = name: a: {
    box = defaultBox;
    prefix = "default";
    args = "";
    env = "";
    title = name;
    icon = "application-x-executable";
    categories = "";
    wmClass = baseNameOf a.exe;
  } // a;

  # The prefix on the host (the container HOME is ~/distrobox/BOX).
  prefixDir = a: "${config.home.homeDirectory}/distrobox/${a.box}/"
    + (if a.prefix == "default" then ".wine" else "prefixes/${a.prefix}");

  iconOf = a: if lib.hasInfix "." a.icon then "${prefixDir a}/${a.icon}" else a.icon;

  full = lib.mapAttrs withDefaults apps;

  appsIni = "[wswin]\ndefault_box=${defaultBox}\n"
    + lib.concatStrings (lib.mapAttrsToList (name: a: ''

      [${name}]
      box=${a.box}
      prefix=${a.prefix}
      exe=${a.exe}
      args=${a.args}
      env=${a.env}
    '') full);

  desktop = name: a: ''
    [Desktop Entry]
    Type=Application
    Name=${a.title}
    Exec=wswin run ${name}
    Icon=${iconOf a}
    Terminal=false
    Categories=${a.categories}
    StartupWMClass=${a.wmClass}
    X-Workstation-Box=${a.box}
  '';
in
{
  assertions = lib.mapAttrsToList (name: a: {
    assertion = builtins.match "[A-Za-z0-9._-]+" name != null
      && builtins.match "[A-Za-z0-9._-]+" a.prefix != null
      && !(lib.hasPrefix "/" a.exe);
    message = "windows/apps.nix: ${name}: name/prefix [A-Za-z0-9._-], exe relative to the prefix";
  }) full;

  xdg.dataFile = {
    "workstation/windows/apps.ini".text = appsIni;
  } // lib.mapAttrs' (name: a:
    lib.nameValuePair "applications/ws-win-${name}.desktop" { text = desktop name a; }) full;
}
