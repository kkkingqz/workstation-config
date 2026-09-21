title: ws-workstation
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# Текущий реализованный стек Ubuntu T2 workstation

Дата: 2026-09-21

## Платформа

- MacBook Pro 16" 2019 (`MacBookPro16,1`, Intel/T2).
- Ubuntu 26.04.1 LTS.
- GNOME 50.
- Wayland session.
- GDM3.
- rEFInd как основное boot menu.
- T2 kernel: `7.2.6-1-t2-resolute`.
- Generic Ubuntu kernel оставлен как fallback.
- Secure Boot отключён для T2 Linux.

## Файловая система и восстановление

Root работает на Btrfs.

Используемые subvolume:

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

Root загружается с:

```text
rootflags=subvol=@
```

Структура подготовлена для snapshots и отката системы.

## GNOME desktop

Используется максимально штатный Ubuntu/GNOME стек:

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
- штатные notifications и OSD;
- NetworkManager integration;
- Bluetooth integration;
- PipeWire / WirePlumber;
- XWayland для legacy applications.

Сторонняя GNOME extension, оставшаяся после экспериментов:

```text
Window Monitor Pro
```

Она остаётся установленной и может быть использована позже для определения активного окна.

## T2 hardware

Работают:

- клавиатура;
- trackpad;
- Wi-Fi;
- Bluetooth;
- T2 audio;
- microphone;
- camera;
- Touch Bar;
- suspend/resume.

T2 hardware обслуживается штатным T2Linux kernel stack.

## Графика

MacBookPro16,1 использует:

```text
Intel UHD 630      → primary GPU
AMD Radeon dGPU    → render/offload GPU
```

Intel используется для desktop.

AMD доступна для приложений через GPU offload.

Runtime power-off AMD dGPU в текущей конфигурации не используется.

## Suspend

Рабочий режим:

```text
deep / S3
```

Suspend/resume протестирован и работает.

ASPM включён:

```text
pcie_aspm=force
pcie_aspm.policy=powersave
```

Дополнительный агрессивный power tuning сейчас не используется.

## Touch Bar

После экспериментов с `react-drm`, `mac-touchbar-plus` и `tiny-dfr` система возвращена к штатному T2 kernel driver:

```text
hid_appletb_kbd
hid_appletb_bl
```

Кастомные Touch Bar renderer/daemon больше не используются.

Текущая конфигурация:

```text
обычный режим:
F1 ... F12

удержание Fn:
media / brightness controls

отпускание Fn:
F1 ... F12
```

Автоматическое затемнение и выключение Touch Bar включено.

Текущий конфиг:

```text
/etc/modprobe.d/tb.conf
```

с параметрами:

```text
options hid_appletb-kbd mode=1 fntoggle=1 autodim=1 dim_timeout=30 idle_timeout=15 double_press_switch_time=300
```

Чтобы параметры применились при загрузке, потребовалось обновить initramfs:

```bash
sudo update-initramfs -u -k "$(uname -r)"
```

После обновления initramfs и reboot штатный Touch Bar работает корректно.

## Изоляция приложений и development

Принята архитектура:

```text
Host
├── kernel / drivers / GNOME / network / audio / virtualization
│   └── apt
│
├── обычные GUI applications
│   └── Flatpak
│
├── development/toolchains
│   └── Distrobox + Podman
│
└── Windows applications
    └── отдельные Wine environments/prefixes
```

Distrobox/Podman уже использовались на практике для изолированной сборки `react-drm`.

Host не используется как общий development environment.

## Терминальная среда

### Ghostty

Ghostty выбран основным лёгким терминалом.

Установлен из Ubuntu 26.04 repository:

```text
Ghostty 1.3.0
GTK4 / libadwaita runtime
Wayland enabled
OpenGL renderer
```

Оконное оформление использует нативный GTK/libadwaita стек и корректно интегрируется с GNOME.

Текущий визуальный baseline:

```text
theme = Desert
background-opacity = 0.90
```

Тема `Desert` используется без пользовательской коррекции цветов.

В Ghostty настроены:

- tabs;
- splits;
- search;
- scrollback;
- clipboard protection;
- URL handling;
- shell integration;
- наследование текущего каталога для новых tabs/splits/windows;
- уведомления о завершении долгих команд в неактивных surfaces;
- физические hotkeys, независимые от текущей раскладки клавиатуры.

Основные конфиги:

```text
~/.config/ghostty/config.ghostty
~/.config/ghostty/behavior.ghostty
~/.config/ghostty/keybinds.ghostty
~/.config/ghostty/shell-keys.ghostty
```

Для буквенных hotkeys используются физические клавиши Ghostty (`KeyC`, `KeyV`, `KeyR` и т. п.), поэтому сочетания продолжают работать при переключении English / Українська / Русская раскладки.

`Ctrl+Enter` специально переводится Ghostty в terminal sequence `Alt+Enter` для использования в TUI-приложениях, в частности в пользовательском directory browser на `fzf`.

### Fish

Основной интерактивный shell:

```text
fish 4.9.3
```

Fish установлен из официального stable PPA:

```text
ppa:fish-shell/release-4
```

Ubuntu-пакет `fish-common` не используется: в актуальном Fish стандартные функции могут быть встроены в сам binary (`embedded:functions/...`).

Fish предоставляет штатно:

- syntax highlighting;
- autosuggestions;
- contextual TAB completion;
- history;
- Emacs-style line editing;
- prompt integration.

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
```

Prompt показывает:

- `user@host`;
- текущий каталог;
- Git branch/state;
- exit status последней неуспешной команды;
- длительность команды справа, если она выполнялась дольше примерно 2 секунд.

### fzf

`fzf` используется для интерактивного fuzzy search.

Работают:

```text
Ctrl+R     → fuzzy search по истории Fish
Option+C   → пользовательский directory browser
```

`Ctrl+T` от стандартной fzf integration не используется, потому что это сочетание занято Ghostty для нового tab.

Directory browser на `Option+C` показывает только каталоги текущего уровня, а не всё рекурсивное дерево.

Его логика:

```text
Enter на каталоге     → открыть каталог и остаться в browser
../ + Enter           → перейти на уровень вверх
./ + Enter            → принять текущий каталог и вернуться в shell
Ctrl+Enter             → принять выбранный каталог и вернуться в shell
Esc                    → отменить
```

### zoxide

`zoxide` используется как быстрый каталоговый jump database.

Основные команды:

```text
z NAME    → перейти в наиболее подходящий ранее посещённый каталог
zi        → интерактивно выбрать каталог из базы zoxide
```

Для Fish >= 4.8 используется compatibility workaround, так как установленная версия zoxide ожидает физический `/usr/share/fish/functions/cd.fish`, а новый Fish может хранить `cd` как embedded function.

### eza

`eza` используется как улучшенный `ls`.

Определены команды:

```text
ls    → компактный список
ll    → long listing + Git status
la    → long listing + hidden files + Git status
lt    → tree глубиной 2 уровня
```

Используются icons, hyperlinks и группировка каталогов первыми.

Для установленной версии `eza` флаг hyperlink используется как boolean:

```text
--hyperlink
```

а не `--hyperlink=auto`.

### Wave Terminal

Wave Terminal остаётся установленным как более тяжёлый workspace terminal для сложных рабочих сессий, SSH/workspace задач и блочной организации.

Ghostty используется как основной быстрый ежедневный terminal.

## Пользовательские scripts и wrappers

Принято единое место:

```text
~/.local/bin
```

Этот каталог добавляется в `PATH` через:

```text
~/.config/fish/conf.d/user-bin.fish
```

Правило размещения:

```text
~/.local/bin/<tool>             → executable / wrapper
~/.config/<tool>/...            → пользовательская конфигурация tool
~/.local/share/<tool>/...       → дополнительные данные большого tool
```

Для переносимости shebang выбирается через `/usr/bin/env`, например:

```text
#!/usr/bin/env fish
#!/usr/bin/env bash
#!/usr/bin/env python3
```

## Git для пользовательских конфигов

Для вручную поддерживаемых dotfiles создан bare Git repository:

```text
~/.local/share/dotfiles.git
```

Work tree:

```text
$HOME
```

Wrapper:

```text
~/.local/bin/dotgit
```

Использование:

```text
dotgit status
dotgit diff
dotgit add <конкретный-файл>
dotgit commit -m "..."
```

В repository используется whitelist-подход: добавляются только файлы, которые правятся вручную.

Сейчас отслеживаются:

```text
.config/fish/conf.d/eza.fish
.config/fish/conf.d/fzf-options.fish
.config/fish/conf.d/git-prompt.fish
.config/fish/conf.d/user-bin.fish
.config/fish/config.fish
.config/fish/functions/fish_prompt.fish
.config/fish/functions/fish_right_prompt.fish
.config/fish/functions/fzf_cd_browser.fish
.config/ghostty/behavior.ghostty
.config/ghostty/config.ghostty
.config/ghostty/keybinds.ghostty
.config/ghostty/shell-keys.ghostty
.local/bin/dotgit
```

Git настроен так, чтобы не показывать весь `$HOME` как untracked:

```text
status.showUntrackedFiles = no
```

Первый commit создан в branch:

```text
main
```

В dotfiles repository сознательно не добавляются автоматически генерируемые и чувствительные данные, например:

```text
~/.config/fish/fish_variables
~/.local/share/fish/fish_history
SSH private keys
API tokens
passwords
browser profiles
credentials
```

Не используется `dotgit add .` из `$HOME`; новые конфиги и wrappers добавляются явно.

Remote repository пока не является обязательной частью baseline.

## Что сознательно не используется

Сейчас не используются:

- `react-drm`;
- `mac-touchbar-plus`;
- `tiny-dfr`;
- отдельный Touch Bar userspace renderer;
- `powertop --auto-tune`;
- TLP;
- auto-cpufreq;
- агрессивный USB runtime PM для Touch Bar;
- кастомный GNOME Shell CSS;
- замена штатного GNOME наборами отдельных panel/OSD/notification компонентов;
- Kitty как основной terminal;
- XWayland workaround для terminal window decorations;
- Starship;
- Oh My Fish;
- Fisher как обязательный framework;
- Neovim как часть terminal setup.

## Текущее базовое состояние

```text
Ubuntu 26.04.1 LTS
└── GNOME 50 / Wayland
    ├── T2 kernel 7.2.6-1-t2-resolute
    ├── Intel primary + AMD offload
    ├── Wi-Fi / Bluetooth
    ├── PipeWire audio
    ├── Camera
    ├── deep/S3 suspend
    ├── Btrfs + snapshots architecture
    ├── штатный Touch Bar
    │   ├── F1–F12
    │   ├── Fn → media controls
    │   └── autodim / auto-off
    └── terminal environment
        ├── Ghostty 1.3.0
        │   ├── Desert
        │   ├── opacity 0.90
        │   ├── tabs / splits / search / scrollback
        │   └── layout-independent physical hotkeys
        ├── Fish 4.9.3
        │   ├── syntax highlighting
        │   ├── autosuggestions
        │   ├── completion
        │   └── Git-aware prompt
        ├── fzf
        ├── zoxide
        ├── eza
        ├── ~/.local/bin user tools
        └── bare dotfiles Git repository
```

Это состояние считаем текущим рабочим baseline для дальнейшего развития workstation.
