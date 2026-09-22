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

---

## GNOME RESERVED SUPER KEYS

GNOME Shell has several global `Super+letter` shortcuts that conflict with
macOS-style application commands. The workstation profile disables these Shell
bindings so the event can reach xremap/Ghostty:

```text
Super+A        Show Applications    -> disabled; application gets Command+A
Super+V        notification list    -> disabled; application gets Command+V
Super+M        notification list    -> disabled; GNOME minimize owns Super+M
Super+S        Quick Settings       -> disabled; application gets Command+S
Super+N        focus notification   -> disabled; application gets Command+N
```

The original values are kept in
`state/keyboard/gsettings-backup.tsv` and restored by `ws-keyboard restore`.
---

## GNOME / UBUNTU DOCK NUMBER KEYS

Ubuntu Dock and GNOME Shell reserve `Super+1..9`; Ubuntu Dock also
uses `Shift+Super+1..9`. These conflict with macOS-style screenshots
such as `Shift+Command+3/4/5`.

The workstation profile therefore:

- clears `org.gnome.shell.keybindings switch-to-application-1..9`;
- sets `org.gnome.shell.extensions.dash-to-dock hot-keys` to `false`
  when Ubuntu Dock is installed;
- keeps the original values in `state/keyboard/gsettings-backup.tsv`.

The dock itself and pinned applications are not removed or otherwise
changed; only their Super-number keyboard launcher shortcuts are disabled.

---

## MUTTER OVERLAY KEY

GNOME normally treats a standalone `Super_L` press as the Activities/Overview
trigger. That conflicts with macOS semantics, where Command by itself does
nothing, and it can also cause accidental Overview activation after remapped
`Command+Arrow` sequences.

The workstation profile therefore sets:

```text
org.gnome.mutter overlay-key = ''
```

`Super` remains fully usable as a modifier. Overview remains available through
`Command/Win+Space` and `Control+Up`.

The original value is kept in `state/keyboard/gsettings-backup.tsv` and restored
by `ws-keyboard restore`.

---

## NAUTILUS / FINDER LAYER

When GNOME Files (`org.gnome.Nautilus`) is active, xremap applies a Finder-like
override before the generic GUI mappings.

```text
Command/Win+Up             parent folder
Command/Win+Down           open selected item
Command/Win+[              back
Command/Win+]              forward

Command/Win+I              Properties
Command/Win+Backspace      Move to Trash
Shift+Command/Win+N        New Folder

Shift+Command/Win+G        Go to Folder / location entry
Command/Win+K              Network / Connect to Server view
Shift+Command/Win+.        show/hide hidden files

Space                      Quick Look via GNOME Sushi
```

Back/Forward use Nautilus supported Back/Forward input events rather than
Alt+Left/Right.

`Command/Win+K` opens Nautilus `x-network-view:///`, which exposes the
dedicated network server address bar for GVfs URIs such as `smb://`,
`sftp://`, `ssh://`, `nfs://`, and `dav://`.

Deletion:

```text
Command/Win+Backspace      macOS-style Move to Trash
Delete                     Nautilus native Move to Trash
Shift+Delete               Nautilus native permanent delete
Fn+Delete on Apple         normally emits forward Delete
```

The bare Apple key labelled `delete` normally emits Backspace. It is not
globally changed to Delete because that would break Backspace while editing
the Nautilus location/search fields.

Empty Trash is intentionally not mapped.

---

## KEYBOARD LAYOUT DEPENDENCE

The workstation xremap triggers are based on evdev physical key codes, so
trigger matching itself is independent of EN/UA/RU layout.

The receiving application can still make a remap layout-dependent when the
output is a printable shortcut such as `Ctrl+N`. For that reason:

- Nautilus `Shift+Command/Win+N -> Ctrl+Shift+N` is intentionally retained and
  is currently considered EN-layout-only.
- No Nautilus Python extension or other plugin is installed for this shortcut.
- Generic GUI mappings (`Command+C -> Ctrl+C`, etc.) remain native application
  shortcuts. Their non-Latin behavior depends on the application's toolkit.
- Ghostty does not use xremap-generated Ctrl-letter sequences. It uses physical
  W3C key codes and explicit terminal control bytes/ESC sequences, so terminal
  controls and macOS-style shell navigation are layout-independent.
- Ghostty punctuation bindings use physical `Comma`, `Equal`, `Minus`, and
  `Digit0` key codes.

If a specific GUI application fails to honor its native Ctrl shortcut on a
non-Latin layout, add an application-specific solution instead of globally
switching keyboard layouts inside xremap.

---

## MACOS APP WINDOW ACTIONS

Application-level window operations use the third-party GNOME Shell extension
Window Control (`window-control@carlo9890.github.io`) through its D-Bus API.
No workstation-owned GNOME Shell extension is used.

```text
Option+Command/Win+Esc       GNOME System Monitor
Command/Win+H                minimize all windows of current app
Option+Command/Win+H         minimize all windows except current app
Option+Command/Win+W         close all windows of current app
Option+Command/Win+M         minimize all windows of current app

Shift+Command/Win+Q          logout with confirmation
Option+Shift+Command/Win+Q   logout immediately
```

`ws-window` gets the complete window list from Window Control's
`ListDetailed` D-Bus method. It identifies the focused application using, in
order, `sandboxed_app_id`, `gtk_application_id`, and `wm_class`.

`Close All` calls Window Control's polite `Close` method for every window of
the current application, so applications can still present save/confirm
dialogs.

`Option+Command/Win+Esc` deliberately does not force-kill anything. It opens
GNOME System Monitor, where the process/application can be inspected and
terminated manually.

Dependency:

```text
GNOME Shell extension: window-control@carlo9890.github.io
```

---

## FINDER EXTRA SHORTCUTS

Additional Finder-style mappings in GNOME Files:

```text
Command/Win+1             Grid / icon view
Command/Win+2             List view
Command/Win+F             Search current folder (existing generic mapping)

Shift+Command/Win+H       Home
Shift+Command/Win+C       Computer equivalent: filesystem root /
Shift+Command/Win+O       XDG Documents
Shift+Command/Win+D       XDG Desktop
```

The following Finder shortcuts are intentionally left unmapped because
Nautilus 50 has no direct native equivalent suitable for this keyboard layer:

```text
Command/Win+3             Column View
Command/Win+4             Gallery View
Command/Win+J             View Options
Command/Win+D             Duplicate
Command/Win+E             Eject
Shift+Command/Win+U       Utilities
```

Existing Nautilus/Finder mappings remain unchanged:

```text
Command/Win+Up            parent folder
Command/Win+Down          open selection
Command/Win+[ / ]         back / forward
Command/Win+I             Properties
Command/Win+Backspace     Move to Trash
Delete                    Move to Trash
Shift+Delete              Delete permanently
Shift+Command/Win+N       New Folder (EN layout only)
Shift+Command/Win+G       Go to Folder / location entry
Command/Win+K             Network / Connect to Server
Shift+Command/Win+.       show/hide hidden files
Space                     Quick Look
```
