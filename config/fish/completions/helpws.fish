# Completions for helpws.
complete -c helpws -f

set -l helpws_topics terminal term ghostty fish keyboard keys workstation system baseline touchbar suspend sleep power gnome desktop rebuild roadmap distrobox box boxes wsbox plan-t2 plan-gnome plan-flatpak plan-dev plan-windows plan-virt plan-final plan-nix man help

complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a terminal -d 'Ghostty + Fish handbook'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a keyboard -d 'macOS-style keyboard layer'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a workstation -d 'Current workstation baseline'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a touchbar -d 'Touch Bar implementation notes'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a suspend -d 'Suspend / T2 power layer'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a gnome -d 'GNOME desktop status / baseline work'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a rebuild -d 'Reinstall to current baseline'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a roadmap -d 'Remaining workstation roadmap'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a distrobox -d 'Managed Distrobox / Podman layer'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-t2 -d 'T2 optional / power / auth'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-gnome -d 'GNOME visual / input / portals'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-flatpak -d 'Flatpak desktop apps'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-dev -d 'Distrobox / Podman managed layer (completed)'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-windows -d 'Wine / Steam / Proton'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-virt -d 'KVM / libvirt / Unreal'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-final -d 'Backup / inventory / finalization'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a plan-nix -d 'Nix + home-manager migration'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a man -d 'Open generated man page in Micro'
complete -c helpws -n "not __fish_seen_subcommand_from $helpws_topics" -a help -d 'Show helpws usage'

complete -c helpws -n '__fish_seen_subcommand_from man' -a 'ws-terminal ws-keyboard ws-workstation ws-touchbar ws-suspend ws-gnome ws-rebuild ws-roadmap ws-plan-t2 ws-plan-gnome ws-plan-flatpak ws-plan-dev ws-plan-windows ws-plan-virt ws-plan-final ws-plan-nix' -d 'Generated workstation man page'
