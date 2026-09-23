title: ws-plan-gnome

**Status:** DONE — GNOME host layer finalized and verified 2026-09-23.
section: 1
date: 2026-09-23
source: Workstation
volume: User Commands

# PLAN — GNOME VISUAL / INPUT / PORTALS

## Цель

Завершить desktop layer, оставаясь максимально близко к штатному Ubuntu GNOME
и не создавая конфликтов с будущими Flatpak/Distrobox/Wine application layers.

Уже работают GNOME 50, Wayland, GDM3, Ubuntu Dock, Quick Settings, Nautilus и
системные OSD. Keyboard layer также завершён и является отдельным baseline.

# 1. Read-only inventory — DONE

Реализован:

```console
ws-gnome-status
```

Рабочая машина подтверждена:

```text
GNOME Shell        50.1
Mutter             50.1-0ubuntu2.4
Wayland
3072x1920@60
logical scale      1.5
Yaru-dark
accent             orange
Ubuntu Dock        bottom
portals/PipeWire   active
host Wine          absent
```

Display scale остаётся inventory-only.

---

# 2. Appearance/Dock source of truth — DONE

Создан небольшой curated profile:

```text
config/gnome/settings.conf
```

Управление:

```console
ws-gnome check
ws-gnome dry-run
ws-gnome apply
ws-gnome rollback
```

Profile фиксирует текущий рабочий GNOME/GTK + Ubuntu Dock baseline и специально
не включает display, keyboard, extensions, wallpaper или application-specific
settings.

Полный `dconf dump` не используется.

---

# 3. Color refinement — SKIPPED

Решено сохранить штатный `Yaru-dark` со стандартными цветами Ubuntu/GNOME.

Не создаём дополнительный GTK/libadwaita color override и не используем
`adw-gtk3` как workstation baseline.

Текущий visual baseline остаётся:

```text
color scheme   prefer-dark
accent         orange
GTK theme      Yaru-dark
icons          Yaru-dark
cursor         Yaru
```

Это решение приоритетно сохраняет штатную совместимость и минимизирует
обслуживание после обновлений GNOME/GTK.

Не используем как baseline:

- custom GNOME Shell CSS;
- custom `gtk.css` для изменения системной палитры;
- глобальный `GTK_THEME`;
- глобальный `QT_STYLE_OVERRIDE=kvantum`;
- Kvantum как общий desktop theme layer;
- theme forks без доказанной необходимости.

---

# 4. Display scale — FROZEN

Текущий scale уже выбран через `Settings -> Displays`; проблем с отображением
GNOME сейчас нет. Фактический scale встроенного display — `1.5`.

На GNOME stage:

- scale только инвентаризируется;
- не задаём новое значение автоматически;
- не редактируем `monitors.xml` вручную;
- не используем `xrandr` scale hacks;
- не задаём глобальный `Xft.dpi`;
- текущие Mutter experimental flags не переносим в appearance profile.

Применение того же визуального масштаба к Flatpak, Distrobox и Wine apps будет
проверяться в соответствующих application plans после их реализации.

---

# 5. Ubuntu Dock / application menu

Ubuntu Dock остаётся штатным и расположен снизу.

Текущие Dock values входят в `config/gnome/settings.conf`.

Стандартную кнопку `Show Applications` и меню приложений пока не заменяем.
Установка ArcMenu или другого menu extension отложена.

---

# 6. Host Qt5/Qt6 integration — DONE

Для проверки временно использовались:

```text
JuffEd      Qt5
FeatherPad  Qt6
```

До integration packages оба приложения запускались через XCB/XWayland и не
следовали GNOME dark appearance.

Постоянный host baseline:

```text
qgnomeplatform-qt5
qgnomeplatform-qt6
qtwayland5
qt6-wayland
```

После установки подтверждено:

```text
Qt5  -> QGnomePlatform auto + libqwayland-generic.so
Qt6  -> QGnomePlatform auto + libqwayland.so
```

Обычный запуск автоматически использует native Wayland; принудительный
`QT_QPA_PLATFORM=wayland` не требуется.

Не задаём глобально:

```text
QT_QPA_PLATFORM
QT_QPA_PLATFORMTHEME
QT_STYLE_OVERRIDE
QT_SCALE_FACTOR
```

Dark appearance наследуется автоматически через GNOME/QGnomePlatform.
Fractional display scale `1.5` обслуживается compositor/Qt Wayland и не требует
ручного Qt scale override.

`JuffEd` и `FeatherPad` являются только test applications и после проверки
удаляются. `apt autoremove` в рамках этого этапа не выполняется.

Qt integration внутри Distrobox остаётся задачей `plan-dev`.

---

# 7. GNOME Tweaks — только при необходимости

`gnome-tweaks` сейчас не установлен и не требуется для baseline.

Устанавливать только если конкретная нужная настройка отсутствует в штатных
Settings и её разумно хранить как обычный GSettings state.

---

# 8. Extensions policy — DONE

Текущий осознанный enabled set:

Project/workstation:

```text
xremap@k0kubun.com
window-control@carlo9890.github.io
tiling-assistant@ubuntu.com
workstation-smart-popup@local
workstation-dock-spring@local
workstation-input-source@local
```

Ubuntu/GNOME:

```text
ding@rastersoft.com
snapd-prompting@canonical.com
snapd-search-provider@canonical.com
ubuntu-appindicators@ubuntu.com
ubuntu-dock@ubuntu.com
web-search-provider@ubuntu.com
```

Legacy `window-monitor-pro@muhammed.hussien2030.gmail.com` удалён и не входит в
baseline.

Policy:

- отсутствие любого перечисленного baseline extension -> FAIL;
- повторное появление Window Monitor Pro -> FAIL;
- другой неизвестный enabled extension -> WARN;
- автоматически ничего не отключаем.

---

# 9. Keyboard / shortcuts — FROZEN

Keyboard layer **завершён и является частью baseline**; GNOME appearance plan его не перенастраивает.

Source of truth:

```text
docs/keyboard.md
config/keyboard/
bin/ws-keyboard*
gnome/extensions/workstation-input-source@local/
gnome/extensions/workstation-smart-popup@local/
```

---

# 10. Portals infrastructure

Подтверждено active:

```text
xdg-desktop-portal
xdg-desktop-portal-gnome
PipeWire
PipeWire Pulse
WirePlumber
```

Не создавать собственный `portals.conf`, пока нет доказанной проблемы.

Полный Flatpak file chooser / screenshot / screen sharing smoke-test переносится
в `plan-flatpak`.

---

# 11. Deferred application integration

После завершения соответствующих планов отдельно проверить:

```text
plan-flatpak
    Flatpak theme / scale / portals

plan-dev
    Distrobox GUI / Wayland / GTK / Qt scaling

plan-windows
    Wine внутри отдельного Distrobox
    Wine Wayland / legacy scaling / per-prefix DPI
```

Wine на host не устанавливается.

---

# 12. Dock spring-loaded drag-and-drop — VERIFIED

Для внешнего file drag добавлен локальный extension:

```text
workstation-dock-spring@local
```

Финально проверенная policy:

```text
hover delay             1300 ms
target                  Ubuntu Dock app icon
running/minimized app   activate existing Meta.Window
app on other workspace  switch/focus existing window
closed application      NO ACTION
application launch      forbidden on hover
drop                    не перехватывается
```

Практический workflow:

```text
Nautilus file drag
    -> hover running app icon ~1.3 s
    -> existing app window comes forward
    -> continue the same drag into the window
    -> drop
```

Desktop Icons NG остаётся установленным и самостоятельным; Ubuntu Dock не
патчится.

Task функционально проверен и включён в GNOME source-of-truth.

---

# 13. Final host smoke-test — DONE

Реализован read-only helper:

```console
ws-gnome test
```

Он автоматически проверяет:

```text
GNOME / Wayland / scale 1.5
Yaru-dark / orange / managed profile
Ubuntu Dock
extension policy
host Qt5/Qt6 integration
portals
PipeWire / WirePlumber
XWayland availability
GNOME Shell/Mutter crash-level journal
```

Из теста сознательно исключены:

```text
tiny-dfr / Touch Bar
Flatpak
Distrobox
Wine
```

После автоматической части остаётся короткий ручной checklist: Overview/Dock/
Quick Settings, Nautilus/Settings, window controls, clipboard, drag-and-drop,
host file chooser и browser ScreenCast chooser.

После успешного выполнения автоматического и ручного smoke-test этот план можно
пометить DONE.

---

Финальная проверка выполнена 2026-09-23.

Подтверждено:

```text
GNOME / Wayland / scale 1.5                  PASS
Yaru appearance + managed Dock profile       PASS
Qt5/Qt6 QGnomePlatform + native Wayland      PASS
portals / PipeWire / WirePlumber             PASS
extension policy                             PASS
Window Monitor Pro removed                   PASS
Dock Spring 1300 ms / running-only           PASS
Nautilus -> application window DnD            PASS
clipboard / file chooser / ScreenCast         PASS
manual desktop smoke-test                     PASS
```

`tiny-dfr` не относится к `plan-gnome` и остаётся отдельным T2/Touch Bar
вопросом.

**PLAN-GNOME CLOSED.**

---

# DONE WHEN

GNOME stage считается завершённым, когда:

- current inventory сохранён и воспроизводим;
- managed appearance/Dock profile стабилен;
- сохранён штатный `Yaru-dark` со стандартными цветами;
- display scale `1.5` не ухудшен и не управляется appearance layer;
- host Qt5/Qt6 integration подтверждена на native Wayland без глобальных overrides;
- Overview/Dock/Quick Settings остаются отзывчивыми;
- portals/PipeWire/WirePlumber infrastructure исправна;
- extension set короткий и осознанный;
- application-specific integration оставлена соответствующим будущим планам.
