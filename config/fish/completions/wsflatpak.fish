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

function __wsflatpak_managed_apps
    set -l file ~/.local/share/workstation-config/config/flatpak/apps.conf

    if test -f $file
        string replace -r '\s*#.*$' '' < $file \
            | string trim \
            | string match -rv '^$'
    end
end

complete -c wsflatpak -f

complete -c wsflatpak -n '__wsflatpak_needs_command' -a install -d 'Install user Flatpak app'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a remove -d 'Remove user Flatpak app'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a uninstall -d 'Alias for remove'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a manage -d 'Add installed app to managed state'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a unmanage -d 'Remove app from managed state'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a permissions -d 'Show app permissions'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a host -d 'Grant tracked filesystem=host access'
complete -c wsflatpak -n '__wsflatpak_needs_command' -a unhost -d 'Remove tracked filesystem=host access'
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

complete -c wsflatpak -n '__wsflatpak_using_command install' \
    -l unmanaged -d 'Install without adding app to managed state'

for cmd in remove uninstall
    complete -c wsflatpak -n "__wsflatpak_using_command $cmd" \
        -l keep-data -d 'Keep application data'

    complete -c wsflatpak -n "__wsflatpak_using_command $cmd" \
        -l unmanage -d 'Remove app from managed state too'
end

for cmd in manage permissions host unhost reset-permissions info run remove uninstall
    complete -c wsflatpak \
        -n "__wsflatpak_using_command $cmd" \
        -a '(__wsflatpak_user_apps)'
end

complete -c wsflatpak \
    -n '__wsflatpak_using_command unmanage' \
    -a '(__wsflatpak_managed_apps)'
complete -c wsflatpak -n "__wsflatpak_needs_command" -a env -d "Set tracked environment override"
complete -c wsflatpak -n "__wsflatpak_needs_command" -a unenv -d "Remove tracked environment override"
complete -c wsflatpak -n "__wsflatpak_using_command env" -a "(__wsflatpak_user_apps)"
complete -c wsflatpak -n "__wsflatpak_using_command unenv" -a "(__wsflatpak_user_apps)"
complete -c wsflatpak -n "__wsflatpak_needs_command" -a talk -d "Grant tracked session D-Bus talk permission"
complete -c wsflatpak -n "__wsflatpak_needs_command" -a untalk -d "Remove tracked session D-Bus talk permission"
complete -c wsflatpak -n "__wsflatpak_using_command talk" -a "(__wsflatpak_user_apps)"
complete -c wsflatpak -n "__wsflatpak_using_command untalk" -a "(__wsflatpak_user_apps)"
complete -c wsflatpak -n "__wsflatpak_using_command run" -l direct -d "Use flatpak run directly"


function __wsflatpak_filesystem_needs_app
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 2
    and contains -- $cmd[2] filesystem unfilesystem
end

function __wsflatpak_filesystem_needs_spec
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 3
    and contains -- $cmd[2] filesystem unfilesystem
end

complete -c wsflatpak     -n "__wsflatpak_needs_command"     -a filesystem     -d "Grant tracked filesystem permission"

complete -c wsflatpak     -n "__wsflatpak_needs_command"     -a unfilesystem     -d "Remove tracked filesystem permission"

complete -c wsflatpak     -n "__wsflatpak_filesystem_needs_app"     -a "(__wsflatpak_user_apps)"

complete -c wsflatpak     -n "__wsflatpak_filesystem_needs_spec"     -F
