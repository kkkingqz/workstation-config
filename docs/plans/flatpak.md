title: ws-plan-flatpak

**Status:** DONE — Flatpak application layer finalized and verified 2026-09-24.
section: 1
date: 2026-09-24
source: Workstation
volume: User Commands

# PLAN — FLATPAK DESKTOP APPS

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

Используется только user Flathub:

```text
flathub -> https://dl.flathub.org/repo/
```

Подтверждено:

```text
user Flathub          present
system remotes        empty
system Flatpak refs   empty
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
config/flatpak/apps.conf
config/flatpak/remotes.conf
config/flatpak/overrides/
config/fish/completions/wsflatpak.fish
```

Основные команды:

```text
install / remove
manage / unmanage
list / search / info / run
update / cleanup
permissions
host / unhost
filesystem / unfilesystem
env / unenv
talk / untalk
status / check / test / apply
```

Fish completion поддерживает подкоманды, options и установленные App ID.

---

# 3. Managed-by-default policy — DONE

Обычная установка:

```console
wsflatpak install APP
```

автоматически добавляет установленное приложение в managed state.

Исключение:

```console
wsflatpak install --unmanaged APP
```

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

Для удаления managed application требуется явно одновременно вывести его из
source of truth:

```console
wsflatpak remove --unmanage APP
```

По умолчанию удаляются также application data.

Для сохранения данных:

```console
wsflatpak remove --unmanage --keep-data APP
```

Практически проверено на Kate:

```text
managed remove protection       PASS
--keep-data                     PASS
reinstall + preserved data      PASS
default delete-data             PASS
managed state consistency       PASS
```

`unmanage` выполняется после успешного uninstall, поэтому ошибка или отмена
удаления не должна оставлять установленное приложение unmanaged.

Kate использовался как Qt6/lifecycle test application и в итоговый managed set
не входит.

---

# 5. Permissions policy — DONE

Глобальный `filesystem=host` запрещён.

Широкий host access выдаётся только явно:

```console
wsflatpak host APP
wsflatpak unhost APP
```

Предпочтительный вариант — точечные filesystem permissions:

```console
wsflatpak filesystem APP SPEC
wsflatpak unfilesystem APP SPEC
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

Tracked environment overrides:

```console
wsflatpak env APP KEY VALUE
wsflatpak unenv APP KEY
```

Они хранятся в:

```text
config/flatpak/overrides/APP.conf
```

и восстанавливаются через:

```console
wsflatpak apply
```

---

# 7. Session D-Bus overrides — DONE

Tracked session bus permissions:

```console
wsflatpak talk APP BUS_NAME
wsflatpak untalk APP BUS_NAME
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
config/flatpak/overrides/com.anydesk.Anydesk.conf
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

# 9. check/apply reproducibility — DONE

```console
wsflatpak check
```

проверяет:

```text
Flatpak installed
user Flathub configured
system remotes empty
system refs empty
global filesystem=host absent
managed apps installed
unmanaged user apps
tracked filesystem overrides
tracked environment overrides
tracked session D-Bus overrides
override drift
```

Unmanaged user application является WARN, а не автоматически удаляется.

```console
wsflatpak apply
```

восстанавливает:

```text
user remotes
missing managed apps
managed filesystem overrides
managed environment overrides
managed session D-Bus permissions
```

Reproducibility проверена deliberate drift test:

```text
runtime override removed
        -> wsflatpak check FAIL

wsflatpak apply
        -> managed state restored
        -> wsflatpak check PASS
```

---

# 10. GTK / Qt / Wayland integration — DONE

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

# 11. Portals / PipeWire / notifications — DONE

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

# 12. File and URI associations — DONE

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

# 13. Maintenance — DONE

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

# 14. Current managed application baseline

Source of truth:

```text
config/flatpak/apps.conf
```

На момент закрытия этапа используются:

```text
com.github.tchx84.Flatseal
org.gimp.GIMP
com.mikrotik.WinBox
com.anydesk.Anydesk
us.zoom.Zoom
com.obsproject.Studio
org.videolan.VLC
```

Этот список в документации является snapshot состояния на момент закрытия.
Authoritative inventory всегда находится в `config/flatpak/apps.conf`.

---

# 15. Final smoke-test — DONE

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
managed application state               PASS
install lifecycle                       PASS
remove lifecycle                        PASS
filesystem overrides                    PASS
environment overrides                   PASS
session D-Bus overrides                 PASS
drift detection / apply restore         PASS
GTK integration                         PASS
Qt6 integration                         PASS
Wayland / scale                         PASS
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
- managed state воспроизводим через `check/apply`;
- permissions минимальны и tracked;
- `filesystem=host` не выдаётся автоматически;
- GTK и Qt6 applications работают корректно;
- Wayland и fractional scaling не требуют глобальных hacks;
- portals / PipeWire / notifications работают;
- file и URI associations исправны;
- install/remove/update/cleanup lifecycle проверен;
- `wsflatpak check` возвращает PASS.
