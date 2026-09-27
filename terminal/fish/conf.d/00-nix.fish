# Nix (apt: nix-bin, nix-setup-systemd) for login shells. GNOME builds the
# session environment through `fish -l`, so this file must be fast, offline
# and harmless without Nix. /usr/lib/environment.d/nix-daemon.conf sets the
# same for the systemd user manager.
if test -d /nix/var/nix
    set -q NIX_REMOTE; or set -gx NIX_REMOTE daemon
    fish_add_path --global --path $HOME/.nix-profile/bin
    # Completions of CLI from Nix. XDG_DATA_DIRS stays untouched: it would
    # duplicate .desktop entries in the app grid.
    set -l nix_completions $HOME/.nix-profile/share/fish/vendor_completions.d
    if test -d $nix_completions; and not contains $nix_completions $fish_complete_path
        set -g fish_complete_path $fish_complete_path $nix_completions
    end
end
