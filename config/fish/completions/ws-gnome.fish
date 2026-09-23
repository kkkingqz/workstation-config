# Completions for ws-gnome.
complete -c ws-gnome -f

complete -c ws-gnome -n 'not __fish_seen_subcommand_from status check dry-run apply rollback help' -a status -d 'Read-only GNOME inventory'
complete -c ws-gnome -n 'not __fish_seen_subcommand_from status check dry-run apply rollback help' -a check -d 'Compare runtime settings with managed profile'
complete -c ws-gnome -n 'not __fish_seen_subcommand_from status check dry-run apply rollback help' -a dry-run -d 'Show changes without applying them'
complete -c ws-gnome -n 'not __fish_seen_subcommand_from status check dry-run apply rollback help' -a apply -d 'Apply managed GNOME appearance profile'
complete -c ws-gnome -n 'not __fish_seen_subcommand_from status check dry-run apply rollback help' -a rollback -d 'Restore values saved before last apply'
complete -c ws-gnome -n 'not __fish_seen_subcommand_from status check dry-run apply rollback help' -a help -d 'Show ws-gnome help'

complete -c ws-gnome -a test -d 'Final GNOME host smoke-test'
