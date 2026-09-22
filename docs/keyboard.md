title: ws-keyboard
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# KEYBOARD — macOS-STYLE SHORTCUTS ON GNOME

## Цель

Единая семантика для встроенной Apple keyboard и обычной PC/Windows keyboard:

```text
Apple Command   = PC Win   = Linux Super
Apple Option    = PC Alt   = Linux Alt
Apple Control   = PC Ctrl  = Linux Ctrl
```

Физические modifier keys глобально не меняются местами. Ctrl остаётся Ctrl,
чтобы не ломать terminal/TUI semantics.

```text
PROFILE=macos
PC_MODIFIER_LAYOUT=semantic
```

# ARCHITECTURE

```text
physical keyboard
      │
      ├── GNOME / Mutter   system shortcuts
      ├── xremap           macOS application shortcuts
      └── Ghostty          terminal-safe Super shortcuts
```

Все поддерживаемые вручную файлы находятся в
`~/.local/share/workstation-config/`. Вне repository создаются только runtime
symlink'и и system state.

# APPLE И PC KEYBOARD

```text
Function             Apple keyboard       PC keyboard
Copy                 Command+C            Win+C
Paste                Command+V            Win+V
Switch application   Command+Tab          Win+Tab
Search / Overview    Command+Space        Win+Space
Previous workspace   Control+Left         Ctrl+Left
Word left            Option+Left          Alt+Left
```

# SYSTEM SHORTCUTS — GNOME

```text
Super+Tab                 next application
Shift+Super+Tab           previous application
Super+`                   windows of current application
Ctrl+Down                 windows of current application

Super+Space               Overview / search
Ctrl+Up                   Overview

Ctrl+Left                 previous workspace
Ctrl+Right                next workspace

Super+M                   minimize
Ctrl+Super+F              fullscreen
F11                       show desktop

Ctrl+Space                previous input source
Ctrl+Alt+Space            next input source

Ctrl+Super+Q              lock screen

Shift+Super+3             screenshot
Shift+Super+4             screenshot UI
Shift+Super+5             screenshot / recording UI
```

Workspace navigation uses private GNOME chords internally:

```text
Ctrl+Left   -> Ctrl+Alt+Super+Left
Ctrl+Right  -> Ctrl+Alt+Super+Right
```

# APPLICATION SHORTCUTS — XREMAP

```text
Super+C / V / X           copy / paste / cut
Super+A                   select all
Super+Z                   undo
Shift+Super+Z             redo
Super+S / O / P           save / open / print
Super+F                   find
Super+N / T               new / new tab
Super+W                   close
Super+Q                   quit where Ctrl+Q is supported
Super+,                   preferences where Ctrl+, is supported

Super+Left/Right          line start/end
Super+Up/Down             document start/end
Alt+Left/Right            previous/next word
Shift+Alt+Left/Right      select by word
Alt+Backspace             delete previous word
```

`exact_match: true` prevents system combinations such as Ctrl+Super+F from
being swallowed by the generic Super+F mapping.

# TERMINALS

Generic GUI translation excludes terminal application classes. A small
terminal-specific xremap block handles navigation that GNOME would otherwise
consume before Ghostty can see it:

```text
Super+Left                 Ctrl+A / shell line start
Super+Right                Ctrl+E / shell line end
Super+Backspace            Ctrl+U / delete to shell line start
Alt+Left                   Alt+B / previous word
Alt+Right                  Alt+F / next word
```

Ghostty itself keeps native Super bindings for clipboard, tabs, windows and
search:

```text
Super+C / V               copy / paste
Super+A                   select all
Super+F                   search
Super+T                   new tab
Super+N                   new window
Super+W                   close surface
Super+Q                   close all Ghostty windows
Super+,                   open config
Super+= / - / 0           font larger / smaller / reset
```

Therefore Ctrl+C remains terminal interrupt, while Command+C / Win+C is copy.

# FILES

```text
config/keyboard/settings.conf
config/keyboard/xremap.yml
systemd/user/xremap.service
bin/ws-keyboard
bin/ws-keyboard-apply
bin/ws-keyboard-status
bin/ws-xremap
config/ghostty/keybinds.ghostty
```

Runtime service path is only a symlink:

```text
~/.config/systemd/user/xremap.service
  -> ~/.local/share/workstation-config/systemd/user/xremap.service
```

Original GSettings values are stored in:

```text
~/.local/share/workstation-config/state/keyboard/gsettings-backup.tsv
```

`state/keyboard/` is ignored by Git.

# XREMAP PREREQUISITES

xremap runs as the logged-in user, never through sudo. Required:

1. full xremap binary in PATH;
2. access to keyboard evdev devices;
3. write access to `/dev/uinput`;
4. GNOME extension `xremap@k0kubun.com` installed and enabled.

The upstream extension currently declares GNOME Shell 50 support.

The service wrapper refuses to start on GNOME Wayland if the extension D-Bus
bridge is unavailable. This is deliberate: terminal exclusions are a safety
requirement.

# APPLY / STATUS

First apply can be run directly from repository:

```console
~/.local/share/workstation-config/bin/ws-keyboard-apply
```

Then:

```console
ws-keyboard apply
ws-keyboard status
```

Apply performs a full runtime preflight first. If xremap, input permissions,
/uinput access or the GNOME bridge are missing, no GNOME shortcut is changed.
Only repository-backed runtime symlinks may have been created.

# SERVICE

```console
ws-keyboard start
ws-keyboard stop
ws-keyboard restart
ws-keyboard logs
```

xremap uses `--watch=config,device`, so newly attached keyboards and config
changes are detected automatically.

# RESTORE

```console
ws-keyboard restore
```

The initial GNOME shortcut backup is never overwritten by later apply runs.

# KNOWN DIFFERENCES FROM macOS

- GNOME has no exact App Exposé clone; Ctrl+Down uses the current-application
  window switcher.
- Option+Command+Esc is intentionally not mapped to a synthetic kill command.
- Shift+Command+4 opens GNOME screenshot UI; the exact macOS follow-up Space
  sequence is not reproduced.
- Super+Q maps to application Ctrl+Q; applications without Ctrl+Q cannot be
  quit generically.

# DIAGNOSTICS

```console
ws-keyboard status
ws-keyboard devices
ws-keyboard gnome-apps
systemctl --user status xremap.service
journalctl --user -u xremap.service
```
