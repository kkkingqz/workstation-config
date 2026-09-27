# One GNOME Shell extension from extensions.gnome.org, pinned by EGO version
# (the number in the download URL, not version-name) and hash; the zip is
# unpacked as is. Used only for extensions with `pin` in
# modules/home/gnome-extensions.nix; without a pin an EGO extension is
# installed by `ws apply extensions` and updated by Extension Manager.
{ lib, stdenvNoCC, fetchurl, unzip }:
{ uuid, version, hash }:
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
}
