# Man pages built from docs/ (pkgs/man.nix) at their old place,
# ~/.local/share/man/man1, one link per page. After a docs edit `ws switch`
# rebuilds them; man/ is no longer kept in git.
{ man, ... }:
{
  home.file.".local/share/man/man1" = {
    source = "${man}/share/man/man1";
    recursive = true;
  };
}
