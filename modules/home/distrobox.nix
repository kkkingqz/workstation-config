# Distrobox containers and their exported applications. wsbox stays the owner
# of apply/check and reads what is built here from
# ~/.config/workstation/distrobox (one link to the store):
#
#   containers.ini  manifest for `distrobox assemble` (its own format)
#   exports.ini     [BOX] ALIAS=desktop file inside the container (wsbox)
#
# Change: edit this file, `ws switch`, then `wsbox apply NAME` (new container)
# or `wsbox recreate NAME` (changed image or packages; rootfs is replaced,
# the custom HOME stays).
{ lib, pkgs, ... }:
let
  # The same for every container unless a container sets it.
  defaults = {
    init = false;
    nvidia = false;
    pull = true;
    root = false;
    start_now = false;
    entry = false;
  };

  keyOrder = [ "init" "nvidia" "pull" "root" "start_now" "entry" ];

  # In manifest order. home: own directory under
  # ~/.local/share/distrobox-homes/NAME unless sharedHome.
  containers = [
    {
      name = "ubuntu";
      image = "docker.io/library/ubuntu:26.04";
    }
    {
      name = "arch";
      # Arch is rolling: pinned by digest (archlinux:latest of 2026-09-21).
      # Update: new digest here, ws switch, `wsbox recreate arch`
      # (docs/workstation.md).
      image = "docker.io/library/archlinux@sha256:917e543c9d0f1f495d70907bdf05bf53607e791b351e1b01ccd3aec2442303ed";
      exports.winbox3 = "/usr/share/applications/winbox3.desktop";
    }
    {
      name = "wine";
      image = "docker.io/library/ubuntu:26.04";
    }
    {
      # Build containers share the host HOME: sources live in ~ (e.g.
      # ~/touchbar). t2bce modules themselves are built by ws-suspend in a
      # one-off container.
      name = "t2bce-build";
      image = "docker.io/library/ubuntu:26.04";
      sharedHome = true;
      packages = [ "build-essential" "bison" "flex" "kmod" "libelf-dev" "libssl-dev" ];
    }
    {
      # Touch Bar port (~/touchbar). Rust is installed by hand with rustup
      # into /opt/rust (owned by the user), used with
      # RUSTUP_HOME=/opt/rust/rustup CARGO_HOME=/opt/rust/cargo.
      name = "touchbar-build";
      image = "docker.io/library/ubuntu:26.04";
      sharedHome = true;
      packages = [
        "build-essential" "git" "pkg-config" "libdrm-dev" "libegl-dev" "libgles-dev"
        "libinput-dev" "libsystemd-dev" "libudev-dev" "libwayland-dev" "ripgrep"
        "shellcheck" "systemd"
      ];
    }
  ];

  value = v: if lib.isBool v then lib.boolToString v else toString v;

  containerSection = c:
    let
      home = if c.sharedHome or false
        then "\${HOME}"
        else "\${HOME}/.local/share/distrobox-homes/${c.name}";
    in
    ''
      [${c.name}]
      image=${c.image}
      home="${home}"
    ''
    + lib.concatMapStrings (k: "${k}=${value (defaults // (c.settings or { })).${k}}\n")
      keyOrder
    + lib.optionalString (c ? packages)
      "additional_packages=\"${lib.concatStringsSep " " c.packages}\"\n";

  exportSection = c: ''
    [${c.name}]
  '' + lib.concatStrings (lib.mapAttrsToList (alias: desktop: "${alias}=${desktop}\n")
    c.exports);

  distroboxConfig = pkgs.runCommandLocal "workstation-distrobox-config" { } ''
    mkdir -p $out
    cp ${pkgs.writeText "containers.ini"
      (lib.concatStringsSep "\n" (map containerSection containers))} $out/containers.ini
    cp ${pkgs.writeText "exports.ini"
      (lib.concatMapStrings exportSection (lib.filter (c: c ? exports) containers))} $out/exports.ini
  '';

  names = map (c: c.name) containers;
in
{
  assertions = [{
    assertion = lib.length names == lib.length (lib.unique names);
    message = "distrobox.nix: duplicate container name";
  }];

  xdg.configFile."workstation/distrobox".source = distroboxConfig;
}
