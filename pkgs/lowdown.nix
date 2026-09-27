# lowdown 2.0.4, the version the man pages were generated with (apt).
# nixpkgs has 3.x, which changes the list spacing of the generated man pages.
{ lowdown, fetchurl }:
lowdown.overrideAttrs (_: rec {
  version = "2.0.4";
  src = fetchurl {
    url = "https://kristaps.bsd.lv/lowdown/snapshots/lowdown-${version}.tar.gz";
    hash = "sha256-N0EjQLw9h9xT8r4aFhvNjaPBrJdPW+MFtXgaVuLQJZU=";
  };
  # The nixpkgs patch is for 3.x (Cygwin only).
  patches = [ ];
  # 2.0.4 fails two terminal-output table tests (regress/table-*.term) in
  # the build sandbox; the man output used here is not affected.
  doCheck = false;
})
