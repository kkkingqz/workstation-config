title: ws-flatpak
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# FLATPAK — DESKTOP APPLICATIONS

GUI-приложения — Flatpak (user installation), host остаётся чистым. Как слой
строился: `helpws history-flatpak`.

## Источник

```text
flatpak/apps.txt        управляемые приложения: REMOTE APP, по строке
flatpak/flatpak.nix     remotes, overrides приложений, свои .desktop
flatpak/desktop/*.desktop  полные .desktop, заменяющие штатные
bin/wsflatpak           владелец: install, apply, check
```

`ws switch` собирает `~/.local/share/workstation/flatpak/` (`remotes.conf`,
`apps.conf`, `overrides/`, `desktop/`) и ставит свои `.desktop` в
`~/.local/share/applications`. `wsflatpak apply` добавляет remotes, ставит
приложения и применяет overrides; overrides управляемого приложения сначала
сбрасываются, так что ключ, убранный из `flatpak.nix`, исчезает.

Remotes: `flathub`, `flatpark` (Claude Desktop).

## Установить и убрать

```console
wsflatpak install APP                # ставит и дописывает в apps.txt
wsflatpak install --unmanaged APP    # только ставит
wsflatpak manage APP [REMOTE]        # уже установленное — в apps.txt
wsflatpak unmanage APP               # убрать строку из apps.txt
wsflatpak remove APP                 # управляемое — сначала unmanage
ws switch                            # собирает и коммитит apps.txt
```

`ws switch` добавляет изменённый `apps.txt` в сборку и после успешного
switch коммитит его (без push).

## Разрешения и окружение

Постоянные — в `overrides` `flatpak/flatpak.nix` (`Context.filesystems`,
`Environment`, `Session Bus Policy` с `talk`), затем `ws switch` и
`wsflatpak apply`. Команды `host`, `filesystem`, `env`, `talk` (и `un…`)
печатают строку для `flatpak.nix`, а не меняют систему.

```console
wsflatpak permissions APP
wsflatpak reset-permissions APP
```

Свои `.desktop`: Claude Desktop (Wayland, масштаб 1.5, URL handler), Steam
через `ws-gpu run` (`helpws windows`, GPU).

## Прочее

```console
wsflatpak list | search TERM | info APP | run APP [ARG...]
wsflatpak update                     # flatpak update --user (ws update flatpak)
wsflatpak cleanup                    # unused runtimes
wsflatpak status
wsflatpak test                       # portals, PipeWire + check
```

## Проверка

```console
wsflatpak check [--json]
ws check
```

`check`: remotes (системных нет), системная установка пуста, нет глобального
`filesystem=host`, приложения `apps.txt` установлены из своих remotes,
overrides применены, свои `.desktop` на месте; приложение или remote вне
объявленных — предупреждение.
