title: ws-touchbar
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

# UBUNTU T2 TOUCH BAR — CURRENT BASELINE

## Текущее состояние

Платформа:

```text
MacBookPro16,1
Ubuntu 26.04.1 LTS
GNOME 50 / Wayland
T2 kernel 7.2.7-1-t2-resolute
```

Текущий режим Touch Bar — **родной**: кнопки рисует сама T2, host только
переключает режим через `hid-appletb-kbd`.

Touch Bar закреплён в USB configuration 1. Режим дисплея (configuration 2,
`appletbdrm`, `tiny-dfr`) не используется: на этой машине с ним связаны все
сбои suspend (см. «Почему не tiny-dfr»).

## Компоненты

```text
/etc/modprobe.d/tb.conf                      параметры hid-appletb-kbd
/etc/modprobe.d/touchbar-native.conf         blacklist appletbdrm
/etc/udev/rules.d/90-touchbar-native.rules   USB configuration 1
/usr/local/libexec/ws-touchbar-fn            Fn и autodim bridge за xremap
/etc/systemd/system/ws-touchbar-fn.service   system service для bridge
```

Все файлы лежат в `system/` repository и ставятся `ws-keyboard-system-apply`.

## hid-appletb-kbd

```text
options hid_appletb_kbd mode=1 fntoggle=1 autodim=1 dim_timeout=30 idle_timeout=15 double_press_switch_time=300
```

- `mode=1` — F1..F12 по умолчанию;
- `fntoggle=1` — Fn переключает F-keys и media;
- `autodim=1`, `dim_timeout=30`, `idle_timeout=15` — затемнение и выключение
  Touch Bar при бездействии. Пока работает `ws-touchbar-fn`, расписание ведёт
  он (см. «Автозатемнение»).

Модуль грузится из initramfs, поэтому после изменения `tb.conf` нужен
`update-initramfs`. `ws-keyboard-system-apply` делает это сам, если
modprobe-файлы изменились.

## Layer behavior

```text
normal       F1..F12
hold Fn      media / brightness
release Fn   F1..F12
```

## Связь с xremap

Встроенная Apple/T2 keyboard выдаёт `KEY_FN`. xremap забирает события
встроенной клавиатуры, поэтому штатное переключение по Fn в `hid-appletb-kbd`
за ним не срабатывает.

xremap использует Fn как собственный mode для macOS-style tiling, но событие
Fn не поглощается:

```yaml
skip_key_event: false
```

Поэтому `KEY_FN` появляется на virtual device `workstation-xremap`. Его слушает
`ws-touchbar-fn.service`:

```text
Fn press     hid-appletb-kbd mode 1 -> 2   (media / brightness)
Fn release   mode 2 -> 1                   (F1..F12)
```

Одно Fn событие используется одновременно:

```text
xremap           -> внутренний apple_fn mode
ws-touchbar-fn   -> временный media/brightness mode Touch Bar
```

Если `hid-appletb-kbd` не привязан (Touch Bar в режиме дисплея или
переподключается после сна), мост молча ждёт. В journal попадают только
подключение к xremap и смена узла `mode`; отдельные нажатия Fn не пишутся.

### Автозатемнение

Драйвер продлевает подсветку только по касаниям Touch Bar и событиям
встроенных клавиатуры и трекпада. Клавиатуру забирает xremap, поэтому набор
текста до драйвера не доходит, и полоса гасла посреди набора.

Пока в драйвере `autodim=Y`, мост переключает его в `N` и ведёт то же
расписание сам: через `dim_timeout` секунд тишины полоса тускнеет, ещё через
`idle_timeout` гаснет. Активностью считается ввод с `workstation-xremap`,
встроенных клавиатуры и трекпада и клавиш Touch Bar. Закрытая крышка гасит
полосу. Если в `tb.conf` задан `autodim=0`, мост подсветку не трогает.

При остановке мост возвращает драйверу `autodim=Y` и включает полосу. После
падения то же делает `ExecStopPost` (`ws-touchbar-fn --hand-back`) по файлу
`/run/ws-touchbar-fn.autodim`.

xremap игнорирует `Dynamic Function Row Virtual Input Device`. В родном режиме
такого устройства нет; исключение оставлено как защита от петли на случай
возврата `tiny-dfr`.

## Почему не tiny-dfr

С 2026-09-22 по 2026-09-25 Touch Bar работал в режиме дисплея: сначала через
`tiny-dfr`, затем, после удаления `tiny-dfr`, его подхватывал GNOME/Mutter как
второй монитор. Сводка по всем S3-циклам на kernel 7.2.x
(`/var/log/syslog`, `/var/log/kern.log`):

| Touch Bar | pcie_aspm | S3 циклов | сбои |
|---|---|---|---|
| родной (configuration 1) | force | 16 | 0 |
| родной | default | 4 | 0 |
| дисплей, работает tiny-dfr | force | 3 | 2 отказа T2 |
| дисплей, рисует Mutter | force | 7 | 1 отказ T2 |
| дисплей, никто не рисует | force | 6 | 1 зависание без логов |
| дисплей, Mutter или никто | default | 13 | 1 зависание без логов |

Зависание 2026-09-25 12:00 (brcmfmac не ушёл в D3, systemd откатился на s2idle)
в таблицу не включено: к Touch Bar оно не относится.

Отказ T2 — это `t2bce_core: remote rejected stateful suspend payload`; за ним
драйвер уходил в no-state fallback и падал с NULL dereference в
`t2bce_dma_reserve_submission` (upstream:
t2linux/T2-Debian-and-Ubuntu-Kernel#215). Оба зависания без логов случились,
когда `tiny-dfr` останавливали прямо перед сном.

Кроме того, без udev-правила `tiny-dfr` (`99-touchbar-seat.rules`) GNOME
использует `appletbdrm` как обычный KMS output. При resume Touch Bar
переподключается, и так однажды получился чёрный экран с
`drmModeAtomicCommit: Invalid argument`.

## Безопасность runtime PM

Для Touch Bar не включать агрессивный USB autosuspend без отдельного теста.

Исторически `power/control=auto` для Touch Bar уже приводил к зависанию
устройства в `suspending`/D-state.

Не использовать для этой системы без отдельной причины:

```text
powertop --auto-tune
агрессивный USB runtime PM для Touch Bar
Touch Bar display mode (appletbdrm) вместе с suspend
```

## Старые эксперименты

Ранее исследовались:

```text
react-drm
mac-touchbar-plus
tiny-dfr (2026-09-22 .. 2026-09-25)
tiny-dfr-sleep.service (остановка tiny-dfr на время сна)
```

`react-drm` удавалось запустить с DRM renderer 2008x60, но draggable UI
(sliders/progress) был недостаточно надёжен. `tiny-dfr` работал, но в режиме
дисплея suspend был ненадёжен (см. выше).

Эти сведения остаются полезной историей, но **не описывают current baseline**.

## Возврат к tiny-dfr

Не рекомендуется, пока сбои suspend в режиме дисплея не исправлены upstream.
Если всё же нужно:

```console
sudo systemctl disable --now ws-touchbar-fn.service
sudo rm /etc/udev/rules.d/90-touchbar-native.rules /etc/modprobe.d/touchbar-native.conf
sudo update-initramfs -u
sudo apt install tiny-dfr
sudo reboot
```

## Проверка

```console
cat /sys/bus/usb/devices/7-6/bConfigurationValue
lsmod | grep appletbdrm
cat /sys/bus/hid/drivers/hid-appletb-kbd/*/mode
cat /sys/module/hid_appletb_kbd/parameters/autodim
systemctl is-active ws-touchbar-fn.service
journalctl -b -u ws-touchbar-fn.service
```

`7-6` — порт Touch Bar на T2 VHCI этой машины.

Ожидается:

```text
bConfigurationValue          1
appletbdrm                   не загружен
hid-appletb-kbd mode         1
autodim                      N (затемнением управляет мост)
ws-touchbar-fn.service       active
journal                      listening on /dev/input/eventN (workstation-xremap)
```

Дополнительно:

```console
ws-workstation-verify --strict
```

## Source of truth

```text
system/modprobe/tb.conf
system/modprobe/touchbar-native.conf
system/udev/90-touchbar-native.rules
system/usr/local/libexec/ws-touchbar-fn
system/systemd/system/ws-touchbar-fn.service
bin/ws-keyboard-system-apply
bin/ws-xremap
config/keyboard/xremap.yml
```

Generated/system runtime state не коммитится в workstation-config.

## Подтверждённый baseline

2026-09-25:

```text
Touch Bar USB configuration 1          OK
appletbdrm не загружен                 OK
F1..F12 default                        OK
hold Fn -> media/brightness            OK
release Fn -> F1..F12                  OK
xremap Apple Fn mode                   OK
ws-touchbar-fn service                 OK
tiny-dfr отсутствует                   OK
S3 в родном режиме                     20 циклов, 0 сбоев
```
