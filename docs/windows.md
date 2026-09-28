title: ws-windows
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# WINDOWS PROGRAMS — WINE / PROTON / STEAM

План и решения: `helpws plan-windows`.

## Контейнеры

```text
wine-wayland  Arch                 Wine из Arch, родной Wayland-драйвер;
                                   контейнер по умолчанию
wine          Ubuntu релиза host   WineHQ stable, XWayland: программы, которым
                                   Wayland-драйвер не подходит; WinBox
proton        Arch                 umu-launcher + Proton: игры, тяжёлое 3D
```

Описаны в `distrobox/distrobox.nix` (`windows = { profile; driver; dpi; }`),
живут как обычные managed boxes: `wsbox status`, `wsbox update`,
`wsbox recreate NAME`. HOME каждого — `~/distrobox/NAME`, переживает
recreate. Что ставится при создании:

```text
wine-wayland  wsbox-host-ntsync, затем wine wine-mono wine-gecko winetricks
              (distrobox/arch/pacman-install-hook)
wine          репозиторий WineHQ для релиза контейнера, winehq-stable,
              winetricks (distrobox/wine/winehq-install-hook)
proton        [multilib] (distrobox/arch/multilib-hook), umu-launcher,
              32-битные Mesa/Vulkan, wsbox-host-ntsync
```

Proton и Steam Runtime umu скачивает при первом запуске в
`~/distrobox/proton/.local/share/{Steam/compatibilitytools.d,umu}`.

## Prefixes

```text
стандартный   ~/distrobox/BOX/.wine
свой          ~/distrobox/BOX/prefixes/NAME
```

При создании prefix `wswin` задаёт драйвер (`wine-wayland`: `Graphics=wayland`
в `HKCU\Software\Wine\Drivers`) и DPI контейнера (`wine`: `LogPixels=192`,
200% при `xwayland-native-scaling`). Настройки стандартного prefix общие для
всех программ в нём.

`wine-wayland`: `LogPixels=144` (150%, масштаб экрана 1.5) — Wayland-драйвер
сам не масштабирует окна (проверено на Notepad++ 2026-09-28).

## wswin

```console
wswin list
wswin install [--box BOX] [--prefix NAME] SETUP.exe|.msi [ARG...]
wswin portable [--box BOX] [--prefix NAME] FILE.exe|DIR|FILE.zip [APPNAME]
wswin run APP [ARG...]
wswin exec [--box BOX] [--prefix NAME] PROGRAM [ARG...]
wswin prefix [--box BOX] NAME init [--dpi N]
wswin prefix [--box BOX] NAME winecfg|regedit|kill|path
wswin prefix [--box BOX] NAME winetricks [ARG...]
wswin prefix [--box BOX] NAME remove --force
wswin shell [--box BOX] [--prefix NAME]
wswin menu [--box BOX] [--prefix NAME] add
wswin menu list|sync
wswin menu remove ID
```

- По умолчанию `--box wine-wayland` и стандартный prefix (`NAME` = `default`).
- В `proton` всё идёт через `umu-run` (`GAMEID=umu-default`, если не задан).
- Файлы из host HOME, `/tmp`, `/media`, `/mnt` видны в контейнере по тому же
  пути.

## Меню GNOME

Пункты, которые Wine создаёт при установке (winemenubuilder), остаются в HOME
контейнера. После установщика `wswin install` спрашивает про каждый новый
пункт этого prefix, добавить ли его в меню host; позже —
`wswin menu --box BOX --prefix NAME add`.

```console
wswin install --prefix foo ~/Downloads/foo-setup.exe
```

Portable-программа (exe, каталог или zip) копируется в
`PREFIX/drive_c/Portable/APPNAME`; если exe несколько — выбор по номеру;
иконка берётся из exe (`icoutils` в контейнере), затем вопрос про меню:

```console
wswin portable --prefix tools ~/Downloads/tool.zip
```

Пункт меню хранится в prefix (`PREFIX/.wswin/menu/wswin-BOX-PREFIX-NAME.desktop`
и иконка), в `~/.local/share/applications` — ссылка на него. Запуск:
`wswin exec --box BOX --prefix NAME …`. Удаляется вместе с prefix
(`wswin prefix … remove --force`) или `wswin menu remove ID`; после новой
системы с сохранённым HOME — `wswin menu sync`.

Программы, которые должны возвращаться вместе с репозиторием, — в
`windows/apps.nix` (`exe` — путь внутри prefix), `ws switch`: launcher
`ws-win-NAME.desktop` (`wswin run NAME`), как у WinBox.

## GPU

```console
ws-gpu status
```

`proton` (`gpu = "amd"` в `distrobox.nix`) и Steam работают на AMD, если
система загружена в rEFInd «Ubuntu (AMD)», иначе на Intel. `ws-gpu` ищет
render node с драйвером `amdgpu` при каждом запуске и передаёт
`DRI_PRIME=pci-0000_03_00_0`; `wsbox enter/run proton` добавляют его через
`distrobox enter --additional-flags`, поэтому контейнер один для обеих
загрузок. `wine` и `wine-wayland` GPU не выбирают.

## Steam

`com.valvesoftware.Steam` (flatpak, `flatpak/flatpak.nix`), udev-правила
контроллеров — `steam-devices` (apt). Свой launcher
`flatpak/desktop/com.valvesoftware.Steam.desktop` (тот же id, поэтому и
`steam://`) запускает Steam через `ws-gpu run`. Прямой `flatpak run` из
терминала GPU не выбирает.

## WinBox

`wine`, свой prefix `winbox`, `drive_c/Program Files/WinBox/winbox.exe`,
`LogPixels=192`, без Mono (`WINEDLLOVERRIDES=mscoree=`).

## Проверка

```console
ws check
wsbox check
wswin list
```
