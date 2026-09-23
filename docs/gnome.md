title: ws-gnome
section: 1
date: 2026-09-23
source: Workstation
volume: User Commands

# GNOME DESKTOP — CURRENT MANAGED BASELINE

Этот документ описывает управляемую часть GNOME layer workstation.

## Архитектурные границы

GNOME остаётся максимально штатным Ubuntu desktop:

```text
GDM3
GNOME Shell + Mutter
Wayland
Ubuntu Dock
Quick Settings
Nautilus
GNOME Settings
xdg-desktop-portal + GNOME backend
PipeWire / WirePlumber
```

Не заменяем штатные panel, Dock, notifications или OSD.

Текущий display scale уже выбран через `Settings -> Displays` и считается
рабочим. На этой машине фактический logical monitor scale — `1.5`. GNOME
appearance profile его не задаёт и не меняет.

Стандартную кнопку `Show Applications` и меню приложений пока не заменяем.

## Application layers вне текущего этапа

Интеграцию приложений специально разводим по соответствующим планам:

```text
Flatpak theme / scale / portals
    -> plan-flatpak

Distrobox GUI / Wayland / Qt
    -> plan-dev

Wine
    -> plan-windows
    -> Wine устанавливается в отдельный Distrobox
    -> Wine на host не устанавливается
```

# Управляемый appearance profile

Source of truth:

```text
config/gnome/settings.conf
```

Формат строки:

```text
GSETTINGS_SCHEMA|KEY|GVARIANT_VALUE
```

Текущий профиль фиксирует только небольшой curated набор GNOME/GTK и Ubuntu
Dock settings, полученный с рабочей системы 2026-09-23.

Текущий visual baseline:

```text
color scheme      prefer-dark
accent            orange
GTK theme         Yaru-dark
icons             Yaru-dark
cursor            Yaru
UI font           Ubuntu Sans 11
document font     Sans 11
monospace         Ubuntu Sans Mono 11
Ubuntu Dock       bottom
Dock icon size    50
Dock autohide     true
Show Applications true
click action      focus-minimize-or-appspread
```

Дополнительные текущие Dock settings также записаны в `settings.conf` для
воспроизводимости.

## Что profile намеренно НЕ управляет

```text
display scale / monitors.xml
org.gnome.mutter experimental-features
input sources
keyboard shortcuts
GNOME extension enablement
wallpaper
Flatpak settings
Distrobox settings
Wine settings
```

Это защищает уже завершённый keyboard layer и не смешивает desktop baseline с
application-specific integration.

# ws-gnome

Основной wrapper:

```console
ws-gnome status
ws-gnome check
ws-gnome dry-run
ws-gnome apply
ws-gnome rollback
```

## status

```console
ws-gnome status
```

Read-only inventory. Показывает GNOME/Wayland session, Mutter display state,
appearance, Dock, extensions, portals, host toolkit environment и состояние
managed profile.

Прямой вызов:

```console
ws-gnome-status
```

## check

```console
ws-gnome check
```

Сравнивает все managed keys с `config/gnome/settings.conf`. Ничего не меняет.

Exit status:

```text
0  profile полностью совпадает
1  есть drift или ошибка проверки
```

## dry-run

```console
ws-gnome dry-run
```

Показывает, какие значения изменил бы apply, но не вызывает `gsettings set`.

## apply

```console
ws-gnome apply
```

Перед изменениями сохраняет предыдущие managed values в:

```text
state/gnome/last-apply.before
```

После успешного применения сохраняет итоговый managed state в:

```text
state/gnome/last-apply.after
```

`state/` является machine-local runtime state и не коммитится.

Apply проверяет наличие и writable-state каждого schema/key до начала записи.
При ошибке во время применения выполняется best-effort автоматический rollback
к `last-apply.before`.

## rollback

```console
ws-gnome rollback
```

Восстанавливает managed values, сохранённые перед последним `apply`.

# Safety ownership rules

`ws-gnome-apply` отказывается принимать profile entries, которые принадлежат
другим workstation layers, включая:

```text
org.gnome.desktop.interface text-scaling-factor
org.gnome.mutter experimental-features
org.gnome.desktop.input-sources/*
org.gnome.desktop.wm.keybindings/*
org.gnome.settings-daemon.plugins.media-keys/*
org.gnome.shell enabled-extensions / disabled-extensions
org.gnome.shell.extensions.tiling-assistant/*
```

Таким образом GNOME appearance apply не может случайно переписать display,
keyboard, Tiling Assistant или extension baseline.

# Current inventory checkpoint

На рабочей системе 2026-09-23 подтверждено:

```text
GNOME Shell            50.1
Mutter                  50.1-0ubuntu2.4
session                 Wayland
internal display        3072x1920@60
logical scale           1.5
color scheme            prefer-dark
accent                  orange
GTK / icons             Yaru-dark
Ubuntu Dock             BOTTOM
portals                  active
PipeWire / WirePlumber  active
host Wine               absent
```

Mutter experimental features сейчас содержат:

```text
scale-monitor-framebuffer
xwayland-native-scaling
```

Они только инвентаризируются и не являются частью `settings.conf`.


# Host Qt5/Qt6 — CURRENT BASELINE

Для host Qt applications используется минимальная GNOME integration layer:

```text
qgnomeplatform-qt5
qgnomeplatform-qt6
qtwayland5
qt6-wayland
```

Тестирование выполнено на временных приложениях:

```text
JuffEd      Qt5
FeatherPad  Qt6
```

Подтверждено:

```text
Qt5 normal launch  -> libqwayland-generic.so
Qt6 normal launch  -> libqwayland.so
dark appearance    -> автоматически через QGnomePlatform
display scale      -> compositor/Qt Wayland
```

Никакие глобальные overrides не используются:

```text
QT_QPA_PLATFORM
QT_QPA_PLATFORMTHEME
QT_STYLE_OVERRIDE
QT_SCALE_FACTOR
```

Это важно: обычное Qt приложение получает native Wayland и GNOME appearance
без workstation-specific environment hacks.

Тестовые `juffed` и `featherpad` не являются частью workstation baseline и
после проверки удаляются. `apt autoremove` на этом этапе специально не
выполняется.

Distrobox Qt integration не наследуется из этого раздела автоматически и будет
проверяться отдельно в `plan-dev`.

---


# Colors — FROZEN

Цветовой эксперимент завершён без изменения baseline.

Остаётся штатный Ubuntu/GNOME visual profile:

```text
color scheme   prefer-dark
accent         orange
GTK theme      Yaru-dark
icons          Yaru-dark
cursor         Yaru
```

Не используем custom GTK/libadwaita palette, custom GNOME Shell CSS или
стороннюю GTK theme как workstation baseline. Это сохраняет максимально
штатное поведение GNOME и снижает риск несовместимости после обновлений.

Flatpak, Distrobox/Qt и Wine visual integration по-прежнему проверяются позже
в соответствующих application plans.

