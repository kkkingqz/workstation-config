# Completions for helpws.
complete -c helpws -f

set -l helpws_topics terminal term ghostty fish keys workstation system baseline man help

complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a terminal -d 'Ghostty + Fish handbook'
complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a ghostty -d 'Ghostty section in terminal handbook'
complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a fish -d 'Fish section in terminal handbook'
complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a keys -d 'Keyboard shortcuts in terminal handbook'
complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a workstation -d 'Full workstation baseline'
complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a man -d 'Open generated man page in Micro'
complete -c helpws -n 'not __fish_seen_subcommand_from terminal term ghostty fish keys workstation system baseline man help' -a help -d 'Show helpws usage'

complete -c helpws -n '__fish_seen_subcommand_from man' -a 'ws-terminal ws-workstation' -d 'Generated workstation man page'
