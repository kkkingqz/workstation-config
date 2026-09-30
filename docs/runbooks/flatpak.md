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
flatpak/overrides.txt   overrides приложений: APP KIND VALUE, по строке
flatpak/flatpak.nix     remotes, свои .desktop; читает оба списка
flatpak/desktop/*.desktop  полные .desktop, заменяющие штатные
bin/wsflatpak           владелец: install, apply, check
```

`ws switch` собирает `~/.local/share/workstation/flatpak/` (`remotes.conf`,
`apps.conf`, `overrides/`, `desktop/`) и ставит свои `.desktop` в
`~/.local/share/applications`. `wsflatpak apply` добавляет remotes, ставит
приложения и применяет overrides; overrides управляемого приложения сначала
сбрасываются, так что строка, убранная из `overrides.txt`, исчезает.

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

`ws switch` добавляет изменённые `apps.txt` и `overrides.txt` в сборку и
после успешного switch коммитит их (без push).

## Разрешения и окружение

Постоянные — строки `flatpak/overrides.txt`: `APP filesystem SPEC`
(`Context.filesystems`), `APP env KEY=VALUE` (`Environment`), `APP talk BUS`
(`Session Bus Policy`, только `talk`). Их добавляют и убирают команды, как
`install` — `apps.txt`; систему они не меняют:

```console
wsflatpak filesystem APP SPEC        # home:ro, xdg-download, /mnt/x:ro, ...
wsflatpak host APP                   # = filesystem APP host
wsflatpak env APP KEY VALUE          # или KEY=VALUE; новое значение заменяет
wsflatpak talk APP BUS
wsflatpak unfilesystem|unhost|unenv|untalk APP ...
ws switch                            # собирает и коммитит overrides.txt
wsflatpak apply                      # применяет
```

APP — ID, имя или часть имени установленного приложения. Значение — одно
слово без `#`.

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
