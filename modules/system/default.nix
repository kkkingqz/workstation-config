# Host system file tree (phase 4 of docs/plans/nix-migration.md): the files
# ws-keyboard-system-apply, ws-suspend apply and the manual steps install,
# byte for byte. Nix only builds it; `ws system diff|check` compares it with
# the live system.
#
#   $out/files/<absolute path>   files for /
#   $out/esp/<path>              files on the rEFInd ESP (compared only)
#   $out/manifest                file MODE PATH | esp PARTUUID PATH | unit STATE NAME
{ lib, runCommand, writeText, facts }:
let
  repo = ../..;

  # A file from the repository, or one generated from facts.
  file = path: from: mode: { inherit path mode; source = repo + "/${from}"; };
  text = path: content: mode: {
    inherit path mode;
    source = writeText (baseNameOf path) content;
  };

  args = { inherit lib facts file text; };
  parts = [
    (import ./common.nix args)
    (import ./boot/${facts.boot}.nix args)
    (import ./hardware/${facts.hardware}.nix args)
  ];
  collect = name: lib.concatMap (p: p.${name} or [ ]) parts;
  units = lib.foldl' (acc: p: acc // (p.units or { })) { } parts;
in
runCommand "system-${facts.hardware}" { } ''
  mkdir -p $out/files $out/esp
  : > $out/manifest
  ${lib.concatMapStrings (e: ''
    install -Dm${e.mode} ${e.source} "$out/files${e.path}"
    printf 'file\t%s\t%s\n' ${e.mode} ${lib.escapeShellArg e.path} >> $out/manifest
  '') (collect "files")}
  ${lib.concatMapStrings (e: ''
    install -Dm0644 ${e.source} "$out/esp/${e.path}"
    printf 'esp\t%s\t%s\n' ${facts.refindEspPartuuid} ${lib.escapeShellArg e.path} >> $out/manifest
  '') (collect "esp")}
  ${lib.concatStrings (lib.mapAttrsToList (name: state: ''
    printf 'unit\t%s\t%s\n' ${state} ${name} >> $out/manifest
  '') units)}
''
