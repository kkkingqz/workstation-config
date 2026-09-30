function __wsflatpak_needs_command
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 1
end

function __wsflatpak_using_command
    set -l cmd (commandline -opc)
    test (count $cmd) -ge 2
    and test "$cmd[2]" = "$argv[1]"
end

function __wsflatpak_user_apps
    if command -q flatpak
        flatpak list --user --app --columns=application 2>/dev/null
    end
end

complete -c wsflatpak -f

complete -c wsflatpak -n '__wsflatpak_needs_command' -a install -d 'Install user Flatpak app'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a remove -d 'Remove user Flatpak app'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a uninstall -d 'Alias for remove'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a permissions -d 'Show app permissions'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a reset-permissions -d 'Reset overrides and portal permissions'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a info -d 'Show app information'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a update -d 'Update user Flatpak apps'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a cleanup -d 'Remove unused runtimes'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a list -d 'List user Flatpak refs'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a search -d 'Search Flathub'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a run -d 'Run Flatpak app'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a status -d 'Show Flatpak state'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a check -d 'Check Flatpak policy'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a test -d 'Run integration smoke test'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a apply -d 'Apply managed Flatpak state'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a manage -d 'Add installed app to flatpak/apps.txt'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a unmanage -d 'Remove app from flatpak/apps.txt'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a filesystem -d 'Add filesystem override to flatpak/overrides.txt'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a unfilesystem -d 'Remove filesystem override'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a host -d 'Add filesystem=host override'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a unhost -d 'Remove filesystem=host override'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a env -d 'Add environment override'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a unenv -d 'Remove environment override'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a talk -d 'Add session bus talk override'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a untalk -d 'Remove session bus talk override'

for cmd in remove uninstall
    complete -c wsflatpak -n "__wsflatpak_using_command $cmd" \
        -l keep-data -d 'Keep application data'
end

for cmd in permissions reset-permissions info run remove uninstall manage unmanage \
        filesystem unfilesystem host unhost env unenv talk untalk
    complete -c wsflatpak \
        -n "__wsflatpak_using_command $cmd" \
        -a '(__wsflatpak_user_apps)'
end
complete -c wsflatpak -n "__wsflatpak_using_command install" -l unmanaged -d "Do not add to flatpak/apps.txt"
complete -c wsflatpak -n "__wsflatpak_using_command run" -l direct -d "Use flatpak run directly"


function __wsflatpak_managed_remotes
    # Built by home-manager from flatpak/flatpak.nix.
    set -l file ~/.local/share/workstation/flatpak/remotes.conf

    if test -f $file
        while read -l name url
            if test -n "$name"
                and not string match -q "#*" -- $name
                echo $name
            end
        end < $file
    end
end

complete -c wsflatpak     -n "__wsflatpak_using_command install"     -l remote     -r     -a "(__wsflatpak_managed_remotes)"     -d "Install from managed remote"
