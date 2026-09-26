# Links from $HOME into the checkout, one file each, as before the migration.
# home-manager owns the links; the files stay in the checkout and are edited
# there (mkOutOfStoreSymlink: no copy in the store, no switch after edits).
# New files in the listed directories are linked on the next `ws switch`.
{ config, lib, ... }:
let
  repo = "${config.home.homeDirectory}/.local/share/workstation-config";
  src = ../..;

  link = path: config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";

  # Regular files of a checkout directory (the flake sees tracked files only).
  filesIn = dir:
    builtins.attrNames (lib.filterAttrs (_: type: type == "regular")
      (builtins.readDir (src + "/${dir}")));

  linkDir = { from, to, filter ? (_: true) }:
    lib.listToAttrs (map (name: {
      name = "${to}/${name}";
      value.source = link "${from}/${name}";
    }) (builtins.filter filter (filesIn from)));

  # Not in PATH: called by the GNOME extension by absolute path.
  binExcluded = [ "ws-caps-led" ];
in
{
  home.file = lib.mkMerge [
    (linkDir { from = "config/fish"; to = ".config/fish"; })
    (linkDir { from = "config/fish/conf.d"; to = ".config/fish/conf.d"; })
    (linkDir { from = "config/fish/functions"; to = ".config/fish/functions"; })
    (linkDir { from = "config/fish/completions"; to = ".config/fish/completions"; })
    (linkDir {
      from = "config/ghostty";
      to = ".config/ghostty";
      filter = lib.hasSuffix ".ghostty";
    })
    (linkDir { from = "config/nix"; to = ".config/nix"; })
    (linkDir {
      from = "bin";
      to = ".local/bin";
      filter = name: !(builtins.elem name binExcluded);
    })
    (linkDir { from = "man/man1"; to = ".local/share/man/man1"; })
    {
      ".config/xdg-terminals.list".source = link "config/xdg-terminals/xdg-terminals.list";
      ".config/ubuntu-xdg-terminals.list".source =
        link "config/xdg-terminals/ubuntu-xdg-terminals.list";
      ".local/share/applications/ghostty-open-here.desktop".source =
        link "config/xdg-terminals/ghostty-open-here.desktop";
    }
  ];
}
