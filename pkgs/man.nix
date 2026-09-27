# Man pages from docs/*.md, one per `title:`, built by bin/ws-doc-build
# (lowdown -s -t man) with the pinned lowdown.
{ runCommand, lowdown }:
runCommand "workstation-man" { nativeBuildInputs = [ lowdown ]; } ''
  mkdir -p work/man/man1
  cp -r ${../docs} work/docs
  WORKSTATION_CONFIG="$PWD/work" sh ${../bin/ws-doc-build} > /dev/null
  mkdir -p $out/share/man
  cp -r work/man/man1 $out/share/man/man1
''
