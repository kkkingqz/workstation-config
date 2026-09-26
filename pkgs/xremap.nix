# xremap as used before the migration: the upstream GNOME build
# xremap-linux-x86_64-gnome.zip, pinned by hash. The binary is static-pie,
# so it is installed as is (no patchelf). Replacement criterion: the binary
# equals runtime/xremap/v0.15.13/xremap (sha256 3da5ec8a…227e).
{ stdenvNoCC, fetchurl, unzip }:

stdenvNoCC.mkDerivation rec {
  pname = "xremap-gnome";
  version = "0.15.13";

  src = fetchurl {
    url = "https://github.com/xremap/xremap/releases/download/v${version}/xremap-linux-x86_64-gnome.zip";
    hash = "sha256-or5fmJQstkz/TazF2lVeYaWXWEFjcLkXB6W9XxBuVlE=";
  };

  nativeBuildInputs = [ unzip ];
  unpackPhase = "unzip $src";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    install -Dm755 xremap $out/bin/xremap
  '';

  meta.mainProgram = "xremap";
}
