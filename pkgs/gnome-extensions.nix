# GNOME Shell extensions from extensions.gnome.org, pinned by EGO version
# (the number in the download URL, not version-name) and hash. The zips are
# unpacked as is; when they were pinned the files equalled the installed
# copies. Update: version and hash here, `ws switch`, logout/login.
{ lib, stdenvNoCC, fetchurl, unzip }:
let
  ego = { uuid, version, hash }:
    stdenvNoCC.mkDerivation {
      pname = "gnome-shell-extension-${lib.head (lib.splitString "@" uuid)}";
      version = toString version;
      src = fetchurl {
        url = "https://extensions.gnome.org/extension-data/"
          + "${lib.replaceStrings [ "@" ] [ "" ] uuid}.v${toString version}.shell-extension.zip";
        inherit hash;
      };
      nativeBuildInputs = [ unzip ];
      dontUnpack = true;
      installPhase = ''
        dir=$out/share/gnome-shell/extensions/${uuid}
        mkdir -p $dir
        unzip -q $src -d $dir
        grep -q '"uuid": "${uuid}"' $dir/metadata.json
      '';
      passthru = { inherit uuid; };
    };
in
{
  # D-Bus window control for ws-window (docs/keyboard.md); version-name 11.
  window-control = ego {
    uuid = "window-control@carlo9890.github.io";
    version = 1;
    hash = "sha256-CzggB2Ei0IkE2a/76lyyYmnmQBe5mVcpFI4W6aXMKEo=";
  };
  window-monitor-pro = ego {
    uuid = "window-monitor-pro@muhammed.hussien2030.gmail.com";
    version = 3;
    hash = "sha256-aMEMTzT7qahGr2XF4gD/1HHgkZgFEcNONkx3j7Nq1Fs=";
  };
  # WM_CLASS bridge for xremap application filters (ws-xremap waits for it).
  xremap = ego {
    uuid = "xremap@k0kubun.com";
    version = 15;
    hash = "sha256-n4HUDswjgQxwTw5ubZzGnCXnxVKMJFdqSXIFa1t9bVo=";
  };
}
