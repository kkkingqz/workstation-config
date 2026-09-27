title: ws-plan-flatpak
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

**Status:** DONE — Flatpak application layer finalized, extended for managed multi-remote support, and verified 2026-09-26.

# PLAN — FLATPAK DESKTOP APPS

**2026-09-27: декларации перенесены в Nix.** Remotes, managed apps, overrides
и desktop overrides объявляются в `modules/home/flatpak.nix`. home-manager
собирает из них `~/.config/workstation/flatpak/` (ссылка на store:
`remotes.conf`, `apps.conf`, `overrides/APP.conf`, `desktop/`) и ставит
`.desktop`-ссылки в `~/.local/share/applications`. `wsflatpak apply|check|test`
работают как раньше, но читают этот каталог. Команды, которые раньше писали
в `config/flatpak/` (`manage`, `unmanage`, `remote-add`, `host`, `unhost`,
`filesystem`, `unfilesystem`, `env`, `unenv`, `talk`, `untalk`), теперь только
печатают строку для `flatpak.nix`. Изменение:

```console
$EDITOR ~/.local/share/workstation-config/modules/home/flatpak.nix
ws switch
wsflatpak apply
```

nix-flatpak не используется: он вызывает `flatpak` из nixpkgs, а не
системный из apt, и заменил бы проверки `wsflatpak check`. Разделы ниже
описывают реализацию и проверки; примеры команд обновлены под Nix.

## Цель

Flatpak является стандартным application layer для обычных сторонних GUI-приложений.

Host сохраняется чистым:

```text
kernel / driver / GNOME / service -> apt host
обычный сторонний GUI app         -> Flatpak
development / SDK                 -> Distrobox
Windows app                       -> отдельный Wine environment
```

Все Flatpak applications и runtimes устанавливаются только в user scope.

---

# 1. Infrastructure — DONE

Host package:

```text
flatpak
```

Используются только managed user remotes.

Текущий baseline:

```text
flathub  -> https://dl.flathub.org/repo/flathub.flatpakrepo
flatpark -> https://dl.flatpark.org/flatpark.flatpakrepo
```

Новый remote объявляется в `remotes` в `modules/home/flatpak.nix`.

Подтверждено:

```text
managed user Flathub    present
managed user Flatpark   present
system remotes          empty
system Flatpak refs     empty
```

`gnome-software-plugin-flatpak` не входит в workstation baseline.

---

# 2. wsflatpak — DONE

Основной интерфейс:

```console
wsflatpak
```

Source of truth:

```text
bin/wsflatpak
modules/home/flatpak.nix                  remotes, apps, overrides
config/flatpak/desktop/                   полные .desktop-файлы
~/.config/workstation/flatpak/            сборка из Nix, читает wsflatpak
config/fish/completions/wsflatpak.fish
```

Основные команды:

```text
install / remove
list / search / info / run
update / cleanup
permissions / reset-permissions
status / check / test / apply
manage, host, env, talk, …   подсказка для flatpak.nix
```

Fish completion поддерживает подкоманды, options и установленные App ID.

---

# 3. Managed-by-default policy — DONE

Обычная установка:

```console
wsflatpak install APP
```

ставит приложение и печатает строку для `apps` в `modules/home/flatpak.nix`
(с 2026-09-27; раньше добавляло его в managed state само). Пока строки нет,
`wsflatpak check` показывает WARN unmanaged user app.

Установка из конкретного managed remote:

```console
wsflatpak install --remote REMOTE APP
```

Managed application inventory хранит origin remote вместе с App ID:

```text
REMOTE APP_ID
```

`wsflatpak check` проверяет фактический origin установленного приложения, а
`wsflatpak apply` использует сохранённый remote при восстановлении отсутствующего
managed application.

Короткие поисковые имена поддерживаются. Проверены, например:

```text
anydesk -> com.anydesk.Anydesk
obs     -> com.obsproject.Studio
winbox  -> com.mikrotik.WinBox
```

После интерактивного выбора Flatpak wrapper использует фактически установленный
App ID, а не исходную поисковую строку.

---

# 4. Remove lifecycle — DONE

Managed application нельзя удалить случайно:

```console
wsflatpak remove APP
```

Для удаления managed application его сначала убирают из `apps` (и
`overrides`) в `modules/home/flatpak.nix`, `ws switch`, затем:

```console
wsflatpak remove APP
```

По умолчанию удаляются также application data.

Для сохранения данных:

```console
wsflatpak remove --keep-data APP
```

Практически проверено на Kate:

```text
managed remove protection       PASS
--keep-data                     PASS
reinstall + preserved data      PASS
default delete-data             PASS
managed state consistency       PASS
```

До 2026-09-27 это делалось одной командой `wsflatpak remove --unmanage`.

Kate использовался как Qt6/lifecycle test application и в итоговый managed set
не входит.

---

# 5. Permissions policy — DONE

Глобальный `filesystem=host` запрещён.

Широкий host access выдаётся только явно, в `overrides` в
`modules/home/flatpak.nix`:

```nix
"APP".Context.filesystems = [ "host" ];
```

Предпочтительный вариант — точечные filesystem permissions:

```nix
"APP".Context.filesystems = [ "SPEC" ];
```

Примеры Flatpak filesystem specs:

```text
/home/user/Projects
/mnt/media:ro
xdg-download
xdg-config/Application:create
```

Практически проверено:

```text
tracked filesystem permission    PASS
drift detection                  PASS
wsflatpak apply restore          PASS
permission removal               PASS
```

---

# 6. Environment overrides — DONE

Tracked environment overrides объявляются в `modules/home/flatpak.nix`:

```nix
"APP".Environment.KEY = "VALUE";
```

Сборка кладёт их в `~/.config/workstation/flatpak/overrides/APP.conf`

и восстанавливаются через:

```console
wsflatpak apply
```

---

# 7. Session D-Bus overrides — DONE

Tracked session bus permissions:

```nix
"APP"."Session Bus Policy"."BUS_NAME" = "talk";
```

Managed override может одновременно содержать несколько типов настроек:

```ini
[Context]
filesystems=...

[Environment]
KEY=value

[Session Bus Policy]
org.example.Service=talk
```

---

# 8. AnyDesk integration — DONE

Для текущего Flatpak AnyDesk используется workstation override:

```ini
[Environment]
GDK_SCALE=2

[Session Bus Policy]
org.kde.StatusNotifierWatcher=talk
```

Source of truth:

```text
modules/home/flatpak.nix (overrides."com.anydesk.Anydesk")
```

Проверено:

```text
scale                    PASS
tray                     PASS
desktop launcher         PASS
check/apply restore      PASS
```

Обычный запуск GUI:

```console
wsflatpak run anydesk
```

использует desktop launcher.

Для диагностики доступен прямой Flatpak launch:

```console
wsflatpak run --direct anydesk
```

---

# 9. Claude Desktop integration — DONE

Claude Desktop установлен из managed Flatpark remote:

```text
flatpark com.anthropic.ClaudeDesktop
```

Tracked permissions:

```ini
[Context]
filesystems=host;

[Session Bus Policy]
org.freedesktop.Flatpak=talk
```

Source of truth:

```text
modules/home/flatpak.nix (overrides."com.anthropic.ClaudeDesktop")
```

Claude является Electron/Chromium application. Для корректного fractional scale
1.5 используется managed desktop launcher override:

```text
config/flatpak/desktop/com.anthropic.ClaudeDesktop.desktop
```

Launcher добавляет:

```text
--ozone-platform=wayland
--force-device-scale-factor=1.5
```

Managed desktop override объявлен в `desktop` в `modules/home/flatpak.nix`;
home-manager публикует его как symlink (в store) в:

```text
~/.local/share/applications/com.anthropic.ClaudeDesktop.desktop
```

Проверено:

```text
native Wayland launch                 PASS
scale 1.5                             PASS
managed permission tracking          PASS
desktop override drift detection     PASS
wsflatpak apply launcher restore     PASS
```

---

# 10. check/apply reproducibility — DONE

```console
wsflatpak check
```

проверяет:

```text
Flatpak installed
managed user remotes configured
system remotes empty
system refs empty
global filesystem=host absent
managed apps installed
managed app origin remotes
unmanaged user apps
tracked filesystem overrides
tracked environment overrides
tracked session D-Bus overrides
managed desktop launcher overrides
override drift
```

Unmanaged user application является WARN, а не автоматически удаляется.

```console
wsflatpak apply
```

восстанавливает:

```text
managed user remotes
missing managed apps from their recorded origin remote
managed filesystem overrides
managed environment overrides
managed session D-Bus permissions
```

Desktop launcher overrides ставит `ws switch` (home-manager).

Reproducibility проверена deliberate drift test:

```text
runtime override removed
        -> wsflatpak check FAIL

wsflatpak apply
        -> managed state restored
        -> wsflatpak check PASS
```

---

# 11. GTK / Qt / Wayland integration — DONE

GTK application smoke-test:

```text
GIMP
```

Qt6 application smoke-test:

```text
Kate
```

Проверено:

```text
Wayland / GNOME scale 1.5       PASS
GTK UI                          PASS
Qt6 UI                          PASS
open/save                       PASS
clipboard                       PASS
Nautilus drag-and-drop          PASS
Dock Spring drag-and-drop       PASS
```

Application-specific global Qt scale hacks не требуются.

---

# 12. Portals / PipeWire / notifications — DONE

Infrastructure:

```text
xdg-desktop-portal
xdg-desktop-portal-gnome
PipeWire
PipeWire Pulse
WirePlumber
```

Проверено на реальных Flatpak applications:

```text
file chooser             PASS
notifications            PASS
PipeWire ScreenCast      PASS
GNOME ScreenCast chooser PASS
```

Zoom использовался для notification и ScreenCast smoke-test.

---

# 13. File and URI associations — DONE

Подтверждены текущие defaults:

```text
HTTP / HTTPS     Firefox
mailto           Thunderbird
PDF              GNOME Papers
JPEG / PNG       GNOME Loupe
text/plain       GNOME Text Editor
video/mp4        VLC Flatpak
anydesk:         AnyDesk Flatpak
```

Flatpak desktop exports доступны в:

```text
~/.local/share/flatpak/exports/share/applications/
```

Проверены:

```text
xdg-mime
gio mime
xdg-open
```

VLC зарегистрирован как default handler для `video/mp4`.

---

# 14. Maintenance — DONE

Основные команды:

```console
wsflatpak list --app
wsflatpak update
wsflatpak cleanup
wsflatpak check
```

Практически проверено:

```text
list       PASS
update     PASS
cleanup    PASS
check      PASS
```

---

# 15. Current managed application baseline

Source of truth:

```text
modules/home/flatpak.nix
```

На текущем verified baseline используются:

```text
flathub  com.github.tchx84.Flatseal
flathub  org.gimp.GIMP
flathub  com.mikrotik.WinBox
flathub  com.anydesk.Anydesk
flathub  us.zoom.Zoom
flathub  com.obsproject.Studio
flathub  org.videolan.VLC
flatpark com.anthropic.ClaudeDesktop
flathub  com.mattjakeman.ExtensionManager
```

Этот список в документации является snapshot состояния на момент закрытия.
Authoritative inventory всегда находится в `modules/home/flatpak.nix`.

---

# 16. Final smoke-test — DONE

Основные проверки:

```console
wsflatpak test
wsflatpak check
```

Manual checklist остаётся внутри `wsflatpak test` для повторного smoke-test
после крупных обновлений GNOME, Flatpak или portals.

Финально подтверждено:

```text
user-only Flatpak policy                PASS
managed multi-remote state               PASS
managed application origins             PASS
install lifecycle                       PASS
remove lifecycle                        PASS
filesystem overrides                    PASS
environment overrides                   PASS
session D-Bus overrides                 PASS
managed desktop launcher overrides      PASS
desktop launcher drift/apply restore    PASS
GTK integration                         PASS
Qt6 integration                         PASS
Electron Wayland / scale                PASS
notifications                           PASS
PipeWire ScreenCast                     PASS
URI/default applications                PASS
maintenance                             PASS
```

**PLAN-FLATPAK CLOSED.**

---

# DONE WHEN

Flatpak stage считается завершённым, когда:

- сторонние GUI apps устанавливаются в user Flatpak;
- system Flatpak scope остаётся пустым;
- applications managed by default;
- несколько user remotes управляются декларативно;
- origin remote каждого managed application отслеживается;
- managed state воспроизводим через `check/apply`;
- application-specific desktop launchers могут быть tracked и восстановлены;
- permissions минимальны и tracked;
- `filesystem=host` не выдаётся автоматически;
- GTK и Qt6 applications работают корректно;
- Wayland и fractional scaling не требуют глобальных hacks;
- portals / PipeWire / notifications работают;
- file и URI associations исправны;
- install/remove/update/cleanup lifecycle проверен;
- `wsflatpak check` возвращает PASS.
