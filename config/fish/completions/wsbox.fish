function __wsbox_needs_command
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 1
end

function __wsbox_using_command
    set -l cmd (commandline -opc)

    test (count $cmd) -ge 2
    and test "$cmd[2]" = "$argv[1]"
end

function __wsbox_managed_boxes
    set -l manifest \
        ~/.local/share/workstation-config/config/distrobox/containers.ini

    if test -f $manifest
        string match -rg '^\[([^]]+)\]$' < $manifest
    end
end

complete -c wsbox -f

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a list \
    -d 'List Distrobox containers'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a status \
    -d 'Show managed container state'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a check \
    -d 'Check managed Distrobox policy'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a dry-run \
    -d 'Show generated create commands'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a apply \
    -d 'Create missing managed containers'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a create \
    -d 'Create one managed container'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a enter \
    -d 'Enter managed container'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a run \
    -d 'Run command inside managed container'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a stop \
    -d 'Stop managed container'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a remove \
    -d 'Remove runtime container'

complete -c wsbox \
    -n '__wsbox_needs_command' \
    -a recreate \
    -d 'Recreate container from manifest'

for cmd in status dry-run apply create enter run stop remove recreate
    complete -c wsbox \
        -n "__wsbox_using_command $cmd" \
        -a '(__wsbox_managed_boxes)'
end

complete -c wsbox \
    -n '__wsbox_using_command remove' \
    -l force \
    -d 'Allow removal of managed container'
