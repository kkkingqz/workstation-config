title: ws-workstation
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

# UBUNTU T2 WORKSTATION — CURRENT BASELINE

**Дата:** 2026-09-23
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
- T2 kernel: `7.2.7-1-t2-resolute` (+ локально исправленный `t2bce`, см. `helpws suspend`)
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

Extensions, являющиеся частью текущего workstation baseline:

```text
xremap@k0kubun.com
window-control@carlo9890.github.io
Tiling Assistant
workstation-smart-popup@local
workstation-dock-spring@local
workstation-input-source@local
```

`Window Monitor Pro` не является зависимостью текущего keyboard/Touch Bar baseline.

---


# GNOME MANAGED APPEARANCE

Штатный GNOME appearance/Dock baseline теперь хранится декларативно:

```text
config/gnome/settings.conf
```

Управление:

```console
ws-gnome status
ws-gnome check
ws-gnome dry-run
ws-gnome apply
ws-gnome rollback
```

Текущий профиль фиксирует небольшой curated набор appearance и Ubuntu Dock
settings. Он намеренно **не** управляет:

```text
display scale / monitors.xml
Mutter experimental-features
input sources / shortcuts
GNOME extension enablement
wallpaper
Flatpak / Distrobox / Wine settings
```

Фактический scale встроенного display сейчас `1.5`; он выбран через GNOME
Settings и остаётся inventory-only.

Application-specific integration выполняется позже:

```text
Flatpak theme / scale / portals  -> plan-flatpak
Distrobox GUI / Wayland / Qt     -> plan-dev
Wine                             -> plan-windows, только внутри отдельного Distrobox
```

Wine на host не устанавливается.

Подробности:

```console
helpws gnome
```

---


# HOST QT INTEGRATION

Host Qt applications используют штатную GNOME/Wayland integration:

```text
qgnomeplatform-qt5
qgnomeplatform-qt6
qtwayland5
qt6-wayland
```

Qt5 и Qt6 автоматически используют native Wayland и GNOME dark appearance.
Глобальные `QT_QPA_PLATFORM`, `QT_QPA_PLATFORMTHEME`, `QT_STYLE_OVERRIDE` и
`QT_SCALE_FACTOR` не задаются.

Это относится только к host applications. Qt внутри Distrobox проверяется
отдельно в `plan-dev`.

---

## Dock spring loading

При внешнем file drag (например, из Nautilus) используется локальный extension:

```text
workstation-dock-spring@local
```

Поведение:

```text
hover running Dock app  1300 ms -> existing window comes forward
minimized app            existing window restores/focuses
other workspace          existing window/workspace activates
closed app               nothing happens; application is not launched
```

Extension не перехватывает сам drop и не патчит Ubuntu Dock или Desktop Icons
NG.

GNOME host layer was finalized and fully smoke-tested on 2026-09-23.

Final GNOME-specific additions include:

```text
managed Yaru / Ubuntu Dock profile
host Qt5/Qt6 native Wayland integration
explicit required-extension policy
workstation-dock-spring@local
```

Dock Spring behavior:

```text
running/minimized app + external file hover ~1.3 s -> existing window focuses
closed app + hover                              -> no action
```

# KEYBOARD / SHORTCUTS

Используется финальный macOS-style semantic profile для Apple и PC keyboards:

```text
Apple Command = PC Win = Super
Apple Option  = PC Alt = Alt
Apple Control = PC Ctrl = Ctrl
```

Архитектура:

```text
GNOME/Mutter                    system shortcuts
xremap                          application/Fn/Nautilus mappings
workstation-input-source@local  EN/RU/UA + Caps + unlock-dialog EN
workstation-smart-popup@local   Smart Tiling Popup
Window Control                  application/window actions
Tiling Assistant                tiling backend
Ghostty                         terminal-safe Super layer
```

Подтверждённые input-source rules:

```text
CapsLock             EN <-> RU; UA -> EN
Fn+CapsLock          UA
Control+Space        EN -> RU -> UA -> EN
Control+Alt+Space    reverse cycle
GDM/login            EN only
GNOME lock screen    EN only
```

Source of truth:

```text
config/keyboard/
config/ghostty/

bin/ws-keyboard*
bin/ws-xremap
bin/ws-window
bin/ws-nautilus-current
bin/ws-input-source
bin/ws-caps-led
bin/ws-tiling-apply
bin/ws-workstation-verify

gnome/extensions/workstation-input-source@local/
gnome/extensions/workstation-smart-popup@local/
gnome/extensions/workstation-dock-spring@local/

systemd/user/xremap.service
system/udev/99-workstation-uinput.rules

system/udev/90-touchbar-native.rules
system/modprobe/
system/usr/local/libexec/ws-touchbar-fn
system/systemd/system/ws-touchbar-fn.service
```

Generated `gschemas.compiled`, `state/` и `runtime/` не являются source files и
не коммитятся.

Полный справочник:

```console
helpws keyboard
```

Полная проверка:

```console
ws-workstation-verify --strict
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

Слой сна:

```text
80-deep-only.conf          только S3, без отката на s2idle
Broadcom ASPM guard        ASPM Wi-Fi off на время сна, без D3cold
t2bce 0.07-nostatefix1     отказ T2 от stateful suspend не роняет ядро
Touch Bar родной режим     без appletbdrm / tiny-dfr
```

ASPM принудительно **не** включается (`pcie_aspm=force` убран 2026-09-25):
все отказы T2 от stateful suspend случились с ним.

Управление и подробности:

```console
ws-suspend status
helpws suspend
```

Дополнительный агрессивный power tuning сейчас не используется.

---

# TOUCH BAR

Родной режим: кнопки рисует T2, режимом управляет `hid-appletb-kbd`.
Touch Bar закреплён в USB configuration 1, `appletbdrm` не загружается.

```text
/etc/modprobe.d/tb.conf                      mode=1 fntoggle=1 autodim=1 ...
/etc/modprobe.d/touchbar-native.conf         blacklist appletbdrm
/etc/udev/rules.d/90-touchbar-native.rules   USB configuration 1
ws-touchbar-fn.service                       Fn bridge за xremap
```

Текущий режим:

```text
normal       F1..F12
hold Fn      media / brightness
release Fn   F1..F12
```

xremap пропускает `KEY_FN` (`skip_key_event: false`) и одновременно использует
Fn для своего Apple `apple_fn` mode. `ws-touchbar-fn` слушает Fn на
`workstation-xremap` и переключает `hid-appletb-kbd` mode 1/2.

`tiny-dfr` (режим дисплея Touch Bar, `appletbdrm`) не используется: на этой
машине все сбои suspend 2026-09-22..25 случились в режиме дисплея, в родном
режиме их не было.

Исторические `react-drm`, `mac-touchbar-plus` и `tiny-dfr` не являются current
baseline.

Подробности:

```console
helpws touchbar
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

## Managed Distrobox layer

Source of truth:

```text
config/distrobox/containers.ini
config/distrobox/exports.ini
config/distrobox/host/modules-load.d/ntsync.conf
config/distrobox/arch/wsbox-host-ntsync/
bin/wsbox
```

Managed containers:

```text
ubuntu   Ubuntu 26.04 base / compatibility
arch     Arch rolling / AUR applications; WinBox 3.x
wine     Ubuntu 26.04 empty base reserved for plan-windows
```

Каждый box использует отдельный persistent HOME под
`~/.local/share/distrobox-homes/`. Rootfs считается disposable.

`arch` использует NTSync из host T2 kernel. Host загружает `ntsync`, а
`wsbox-host-ntsync` внутри Arch только удовлетворяет virtual dependency
`NTSYNC-MODULE`, поэтому container-local `linux`/`mkinitcpio` не нужны.

Управление и проверка:

```console
wsbox status
wsbox apps
wsbox check
wsbox apply [NAME]
```

WinBox prefix хранится в custom HOME и переживает destructive rebuild:

```text
~/.local/share/distrobox-homes/arch/.winbox/wine
LogPixels = 0xc0 = 192 DPI = 200%
```

Подробности:

```console
helpws distrobox
```

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

Актуальная структура включает:

```text
workstation-config/
├── bin/
│   ├── dotgit
│   ├── helpws
│   ├── ws-doc-build
│   ├── ws-keyboard
│   ├── ws-keyboard-apply
│   ├── ws-keyboard-status
│   ├── ws-keyboard-install-extensions
│   ├── ws-keyboard-system-apply
│   ├── ws-workstation-verify
│   ├── ws-gnome
│   ├── ws-gnome-apply
│   ├── ws-gnome-status
│   ├── ws-xremap
│   ├── ws-window
│   ├── ws-nautilus-current
│   ├── ws-input-source
│   ├── ws-caps-led
│   └── ws-tiling-apply
├── config/
│   ├── fish/
│   ├── distrobox/
│   ├── ghostty/
│   ├── gnome/
│   ├── keyboard/
│   └── micro-help/
├── gnome/extensions/
│   ├── workstation-input-source@local/
│   └── workstation-smart-popup@local/
├── system/
│   ├── modprobe/tb.conf, touchbar-native.conf
│   ├── systemd/system/ws-touchbar-fn.service
│   ├── udev/90-touchbar-native.rules, 99-workstation-uinput.rules
│   └── usr/local/libexec/ws-touchbar-fn
├── systemd/user/
│   └── xremap.service
├── docs/
└── man/man1/
```

Runtime helper paths в `~/.local/bin` используют symlink на repository.
GNOME extension runtime copies являются реальными directories в
`~/.local/share/gnome-shell/extensions/`.

Generated/runtime state:

```text
state/
runtime/
gnome/extensions/*/schemas/gschemas.compiled
```

не коммитится.

Перед commit используется:

```console
ws-workstation-verify
git status --short
git diff --check
git diff --cached --check
git diff --cached
```

Не используется `git add .` для workstation cleanup: source files добавляются
явно.

---

# НЕ ИСПОЛЬЗУЕТСЯ

Сейчас сознательно не используются:

- `react-drm`;
- `mac-touchbar-plus`;
- `tiny-dfr` и режим дисплея Touch Bar (`appletbdrm`);
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

Touch Bar работает в родном режиме: `hid-appletb-kbd` + `ws-touchbar-fn`.

---

# CURRENT BASELINE

```text
Ubuntu 26.04.1 LTS
└── GNOME 50 / Wayland
    ├── T2 kernel 7.2.7-1-t2-resolute + patched t2bce
    ├── Intel primary + AMD offload
    ├── Wi-Fi / Bluetooth
    ├── PipeWire audio
    ├── Camera
    ├── deep / S3 suspend
    ├── Btrfs + snapshots architecture
    ├── Touch Bar, родной режим (hid-appletb-kbd)
    │   ├── F1..F12 default
    │   └── hold Fn -> media/brightness (ws-touchbar-fn)
    ├── macOS-style keyboard layer
    │   ├── GNOME/Mutter system shortcuts
    │   ├── xremap GUI/Fn/Nautilus mappings
    │   ├── EN/RU/UA + Caps LED
    │   ├── GDM/login EN
    │   ├── unlock-dialog EN
    │   ├── Tiling Assistant / Tile Editing Mode
    │   └── Smart Popup / Window Control
    └── terminal environment
        ├── Ghostty
        ├── Fish
        ├── fzf / zoxide / eza
        ├── helpws + Micro
        └── workstation-config Git repository
```
