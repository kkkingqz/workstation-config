title: ws-workstation
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# UBUNTU T2 WORKSTATION — CURRENT BASELINE

**Дата:** 2026-09-21  
**Платформа:** MacBook Pro 16" 2019 (`MacBookPro16,1`, Intel/T2)

> Этот документ описывает текущее рабочее состояние workstation.
> Практический справочник по терминалу открывается командой `helpws`.

---

# PLATFORM

- **Ubuntu 26.04.1 LTS**
- **GNOME 50**
- **Wayland**
- **GDM3**
- **rEFInd** как основное boot menu
- T2 kernel: `7.2.6-1-t2-resolute`
- Generic Ubuntu kernel оставлен как fallback
- Secure Boot отключён для T2 Linux

---

# FILESYSTEM / RECOVERY

Root работает на **Btrfs**.

## Subvolumes

```text
@
@home
@root
@srv
@cache
@tmp
@log
.snapshots
```

## Root boot

```text
rootflags=subvol=@
```

Структура подготовлена для snapshots и отката системы.

---

# GNOME DESKTOP

Используется максимально штатный Ubuntu/GNOME stack:

```text
GDM3
  ↓
GNOME Shell + Mutter
  ↓
Wayland
```

Работают:

- Ubuntu Dock;
- Quick Settings;
- GNOME Settings;
- Nautilus;
- notifications и OSD;
- NetworkManager integration;
- Bluetooth integration;
- PipeWire / WirePlumber;
- XWayland для legacy applications.

Сторонняя extension, оставшаяся после экспериментов:

```text
Window Monitor Pro
```

Она остаётся установленной и может быть использована позже для определения активного окна.

---

# KEYBOARD / SHORTCUTS

Используется единый macOS-style semantic profile для Apple и PC keyboards:

```text
Apple Command = PC Win = Super
Apple Option  = PC Alt = Alt
Apple Control = PC Ctrl = Ctrl
```

Системные shortcuts обслуживаются GNOME/Mutter, application shortcuts —
`xremap`, а Ghostty имеет отдельный terminal-safe Super layer.

Source of truth:

```text
config/keyboard/settings.conf
config/keyboard/xremap.yml
systemd/user/xremap.service
bin/ws-keyboard*
```

Runtime конфиги не копируются: вне repository используются только symlink'и
и system state. Проверка:

```console
helpws keyboard
ws-keyboard status
```

---

# T2 HARDWARE

Работают:

- keyboard;
- trackpad;
- Wi‑Fi;
- Bluetooth;
- T2 audio;
- microphone;
- camera;
- Touch Bar;
- suspend/resume.

T2 hardware обслуживается T2Linux kernel stack.

---

# GRAPHICS

```text
Intel UHD 630      → primary GPU
AMD Radeon dGPU    → render/offload GPU
```

Intel используется для desktop. AMD доступна приложениям через GPU offload.

Runtime power-off AMD dGPU в текущей конфигурации не используется.

---

# SUSPEND / POWER

Рабочий режим:

```text
deep / S3
```

Suspend/resume протестирован и работает.

ASPM:

```text
pcie_aspm=force
pcie_aspm.policy=powersave
```

Дополнительный агрессивный power tuning сейчас не используется.

---

# TOUCH BAR

После экспериментов система возвращена к штатному T2 kernel driver:

```text
hid_appletb_kbd
hid_appletb_bl
```

Не используются `react-drm`, `mac-touchbar-plus`, `tiny-dfr` и отдельный userspace renderer.

## Текущий режим

```text
обычный режим:
F1 ... F12

удержание Fn:
media / brightness controls

отпускание Fn:
F1 ... F12
```

Включены autodim и auto-off.

Конфигурация:

```text
/etc/modprobe.d/tb.conf
```

Параметры:

```text
options hid_appletb-kbd mode=1 fntoggle=1 autodim=1 dim_timeout=30 idle_timeout=15 double_press_switch_time=300
```

Применение после изменения:

```sh
sudo update-initramfs -u -k "$(uname -r)"
```

---

# APPLICATION ARCHITECTURE

```text
Host
├── kernel / drivers / GNOME / network / audio / virtualization
│   └── apt
│
├── ordinary GUI applications
│   └── Flatpak
│
├── development / toolchains
│   └── Distrobox + Podman
│
└── Windows applications
    └── separate Wine environments / prefixes
```

Host сознательно не используется как общий development environment.

---

# TERMINAL ENVIRONMENT

## Ghostty

Основной лёгкий terminal:

```text
Ghostty 1.3.0
GTK4 / libadwaita
Wayland
OpenGL renderer
```

Визуальный baseline:

```ini
theme = Desert
background-opacity = 0.90
```

Работают:

- tabs;
- splits;
- search;
- scrollback;
- clipboard protection;
- URL handling;
- shell integration;
- cwd inheritance для tabs/splits/windows;
- notifications после долгих команд в unfocused surfaces;
- physical layout-independent hotkeys.

Конфиги:

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/behavior.ghostty
~/.config/ghostty/keybinds.ghostty
~/.config/ghostty/shell-keys.ghostty
```

## Fish

Основной interactive shell:

```text
fish 4.9.3
```

Установлен из stable PPA:

```text
ppa:fish-shell/release-4
```

Работают:

- syntax highlighting;
- autosuggestions;
- contextual completion;
- history;
- Emacs-style line editing;
- Git-aware prompt.

Основные конфиги:

```text
~/.config/fish/config.fish
~/.config/fish/conf.d/eza.fish
~/.config/fish/conf.d/fzf-options.fish
~/.config/fish/conf.d/git-prompt.fish
~/.config/fish/conf.d/user-bin.fish
~/.config/fish/functions/fish_prompt.fish
~/.config/fish/functions/fish_right_prompt.fish
~/.config/fish/functions/fzf_cd_browser.fish
~/.config/fish/completions/helpws.fish
```

## fzf

```text
Ctrl+R     → fuzzy history
Option+C   → directory browser
```

`Ctrl+T` от fzf отключён, потому что `Ctrl+T` занят Ghostty.

Directory browser:

```text
Enter на каталоге     → открыть и остаться в browser
../ + Enter           → уровень вверх
./ + Enter            → принять current directory и выйти
Ctrl+Enter            → принять выбранный directory и выйти
Esc                   → cancel
```

## zoxide

```console
z NAME
zi
```

Для Fish >= 4.8 используется compatibility workaround из-за embedded `cd` function.

## eza

```console
ls
ll
la
lt
```

Используются icons, hyperlinks, directories first и Git metadata для long modes.

## Wave Terminal

Wave Terminal остаётся отдельным тяжёлым workspace terminal. Ghostty используется как быстрый ежедневный terminal.

---

# HELP SYSTEM

## helpws

Пользовательский terminal help viewer:

```console
helpws
helpws terminal
helpws ghostty
helpws fish
helpws keys
helpws workstation
helpws man ws-terminal
helpws man ws-workstation
```

Fish completion работает для topics, например:

```console
helpws wo<Tab>
```

дополняется до:

```text
helpws workstation
```

Viewer — **Micro в read-only режиме** с отдельной конфигурацией.

Управление:

```text
стрелки / PgUp / PgDn   navigation
mouse / wheel           scroll
Ctrl+F                  search
Ctrl+C                  copy
Esc                     exit
Ctrl+Q                  exit
```

Micro help-viewer использует true-color scheme и Markdown syntax highlighting.

## Documentation source

```text
~/.local/share/workstation-config/docs/terminal.md
~/.local/share/workstation-config/docs/workstation.md
```

## Man generation

```console
ws-doc-build
```

Генерирует:

```text
man/man1/ws-terminal.1
man/man1/ws-workstation.1
```

Просмотр:

```console
man ws-terminal
man ws-workstation
```

---

# USER SCRIPTS / WRAPPERS

Единое место runtime symlink'ов:

```text
~/.local/bin
```

Исходники собственных wrapper'ов хранятся в Git repository:

```text
~/.local/share/workstation-config/bin
```

Правило:

```text
executable source   workstation-config/bin/<tool>
runtime link        ~/.local/bin/<tool>
config source       workstation-config/config/<tool>/...
data                  ~/.local/share/<tool>/...
```

Shebang:

```sh
#!/usr/bin/env fish
#!/usr/bin/env bash
#!/usr/bin/env python3
```

---

# WORKSTATION CONFIG REPOSITORY

Единый обычный Git repository:

```text
~/.local/share/workstation-config
```

Структура:

```text
workstation-config/
├── bin/
│   ├── dotgit
│   ├── helpws
│   └── ws-doc-build
├── config/
│   ├── fish/
│   ├── ghostty/
│   ├── keyboard/
│   └── micro-help/
├── systemd/user/
│   └── xremap.service
├── docs/
│   ├── keyboard.md
│   ├── terminal.md
│   └── workstation.md
└── man/man1/
    ├── ws-terminal.1
    └── ws-workstation.1
```

Рабочие пути `~/.config/...`, `~/.local/bin/...` и `~/.local/share/man/...` используют symlink'и на repository.

Wrapper:

```text
~/.local/bin/dotgit
```

`dotgit` выполняет Git непосредственно в repository:

```console
git -C ~/.local/share/workstation-config ...
```

Примеры:

```console
dotgit status
dotgit diff
dotgit add config/fish/completions/helpws.fish
dotgit commit -m "Update terminal help"
```

Старый bare repository `~/.local/share/dotfiles.git` больше не является текущей архитектурой; до окончательной проверки новой схемы его можно сохранять как резервную копию.

---

# НЕ ИСПОЛЬЗУЕТСЯ

Сейчас сознательно не используются:

- `react-drm`;
- `mac-touchbar-plus`;
- `tiny-dfr`;
- отдельный Touch Bar userspace renderer;
- `powertop --auto-tune`;
- TLP;
- auto-cpufreq;
- агрессивный USB runtime PM для Touch Bar;
- custom GNOME Shell CSS;
- replacement GNOME panel/OSD/notifications stack;
- Kitty как основной terminal;
- XWayland workaround для terminal decorations;
- Starship;
- Oh My Fish;
- Fisher как обязательный framework;
- Neovim как часть terminal setup.

---

# CURRENT BASELINE

```text
Ubuntu 26.04.1 LTS
└── GNOME 50 / Wayland
    ├── T2 kernel 7.2.6-1-t2-resolute
    ├── Intel primary + AMD offload
    ├── Wi-Fi / Bluetooth
    ├── PipeWire audio
    ├── Camera
    ├── deep / S3 suspend
    ├── Btrfs + snapshots architecture
    ├── stock T2 Touch Bar
    ├── macOS-style keyboard layer
    │   ├── GNOME system shortcuts
    │   ├── xremap GUI shortcuts
    │   └── Apple + PC semantic modifiers
    └── terminal environment
        ├── Ghostty 1.3.0 / Desert / opacity 0.90
        ├── Fish 4.9.3
        ├── fzf / zoxide / eza
        ├── helpws + Micro
        └── workstation-config Git repository
```
