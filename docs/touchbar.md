title: ws-touchbar
section: 1
date: 2026-09-23
source: Workstation
volume: User Commands

# UBUNTU T2 TOUCH BAR — CURRENT BASELINE

## Текущее состояние

Платформа:

```text
MacBookPro16,1
Ubuntu 26.04.1 LTS
GNOME 50 / Wayland
T2 kernel 7.2.6-1-t2-resolute
```

Текущий Touch Bar renderer — **tiny-dfr**.

Это является рабочим baseline. Старые варианты через чистый
`hid_appletb_kbd` firmware layer, `react-drm`, `mac-touchbar-plus` и
`ws-touchbar-fn.service` больше не являются текущей архитектурой.

## Runtime

Package:

```text
tiny-dfr
```

На проверенном состоянии:

```text
tiny-dfr 0.3.7-4-resolute
```

Service:

```console
systemctl status tiny-dfr.service
```

Source config:

```text
~/.local/share/workstation-config/config/tiny-dfr/config.toml
```

Runtime config:

```text
/etc/tiny-dfr/config.toml
```

Эти файлы должны совпадать.

## Layer behavior

```text
normal       F1..F12
hold Fn      media / brightness
release Fn   F1..F12
```

Ключевые параметры:

```text
MediaLayerDefault = false
DoublePressSwitchLayers = 0
```

`DoublePressSwitchLayers = 0` означает, что double-Fn не фиксирует media layer.

## Связь с xremap

Встроенная Apple/T2 keyboard выдаёт `KEY_FN`.

xremap использует Fn как собственный mode для macOS-style tiling, но событие
Fn не поглощается:

```yaml
skip_key_event: false
```

xremap создаёт virtual device:

```text
workstation-xremap
```

tiny-dfr видит Fn через seat/libinput и переключает свой слой.

Чтобы исключить loop, xremap игнорирует:

```text
Dynamic Function Row Virtual Input Device
```

Таким образом одно Fn событие одновременно используется:

```text
xremap     -> внутренний apple_fn mode
tiny-dfr   -> временный media/brightness layer
```

## Старый bridge удалён

Больше не используются:

```text
ws-touchbar-fn
ws-touchbar-fn.service
/usr/local/libexec/ws-touchbar-fn
```

Этот bridge раньше вручную переключал `hid_appletb_kbd` mode при Fn. В
текущей схеме он не нужен.

## Безопасность runtime PM

Для Touch Bar не включать агрессивный USB autosuspend без отдельного теста.

Исторически `power/control=auto` для Touch Bar уже приводил к зависанию
устройства в `suspending`/D-state.

Не использовать для этой системы без отдельной причины:

```text
powertop --auto-tune
агрессивный USB runtime PM для Touch Bar
одновременный запуск нескольких Touch Bar renderer
```

## Старые эксперименты

Ранее исследовались:

```text
react-drm
mac-touchbar-plus
firmware-only hid_appletb_kbd mode
custom ws-touchbar-fn bridge
```

`react-drm` удавалось запустить с DRM renderer 2008x60, но draggable UI
(sliders/progress) был недостаточно надёжен.

Эти сведения остаются полезной историей, но **не описывают current baseline**.

## Проверка

```console
systemctl is-active tiny-dfr.service
dpkg-query -W -f='${Version}\n' tiny-dfr

grep -E '^(MediaLayerDefault|DoublePressSwitchLayers)' \
  /etc/tiny-dfr/config.toml

cmp \
  ~/.local/share/workstation-config/config/tiny-dfr/config.toml \
  /etc/tiny-dfr/config.toml
```

Дополнительно:

```console
ws-workstation-verify --strict
```

Ожидается:

```text
tiny-dfr.service active
tiny-dfr package installed
MediaLayerDefault = false
DoublePressSwitchLayers = 0
runtime config matches repository source
workstation-xremap virtual input device present
```

## Source of truth

```text
config/tiny-dfr/config.toml
bin/ws-xremap
config/keyboard/xremap.yml
```

tiny-dfr package владеет system service и своим DRM/uinput setup.

Generated/system runtime state не коммитится в workstation-config.

## Подтверждённый baseline

```text
F1..F12 default              OK
hold Fn -> media/brightness  OK
release Fn -> F1..F12        OK
xremap Apple Fn mode          OK
tiny-dfr service              OK
runtime config == repo        OK
old ws-touchbar-fn absent     OK
```
