title: ws-touchbar
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# UBUNTU T2 TOUCH BAR — IMPLEMENTATION NOTES

## Цель этого файла

Этот файл нужен как точка продолжения работы с Touch Bar на MacBook Pro 16" 2019 (T2), чтобы при возврате к теме не повторять уже пройденные эксперименты и диагностику.

---

## Система

- MacBook Pro 16" 2019 / MacBookPro16,1.
- Ubuntu 26.04.1 LTS.
- T2 kernel: `7.2.6-1-t2-resolute`.
- GNOME Wayland.
- Базовый T2 стек Touch Bar:
  - `hid-appletb-kbd`
  - `hid-appletb-bl`
  - `appletbdrm`
  - `apple-bce` / `t2bce`
- Touch Bar в штатном keyboard/firmware режиме использует USB устройство Apple `05ac:8302`.

## Важное: GNOME extension

**GNOME extension `Window Monitor Pro` остался установленным.**

Он ставился для определения активного окна в GNOME Wayland при экспериментах с `react-drm`.

При возврате к теме учитывать, что extension уже присутствует в системе. Не ставить второй экземпляр и не считать, что active-window backend нужно настраивать с нуля.

---

# 1. Эксперимент с react-drm

Использовался репозиторий:

`dev-muhammad-adel/react-drm-for-touchbar`

Зафиксированная версия:

```text
commit 547be168c19b21702ca6671257e69072ad686263
short  547be16
date   2026-09-12
msg    fix arrow overflow
```

## Сборка

Сборка выполнялась **не на host**, а в отдельном Distrobox:

```text
react-drm-build
Ubuntu 26.04
```

Node:

```text
v22.22.1
npm 11.14.1
```

Native addon успешно собирался:

```text
build/Release/drm_backend.node
```

Config GUI тоже был успешно собран.

## Наш пакет

Был создан собственный Debian package:

```text
react-drm-touchbar
```

Последняя рабочая схема пакета:

- `/opt/react-drm` — immutable application tree.
- private Node runtime в `/opt/react-drm/runtime/bin/node`.
- user data: `~/.local/share/react-drm/linux-touchbar-control-center/`.
- systemd user service: `react-drm.service`.

Для T2 использовался hardware profile:

```text
REACT_DRM_TB_BACKLIGHT_NAMES=appletb_backlight,display-pipe
REACT_DRM_DISP_BACKLIGHT_NAMES=apple-panel-bl,gmux_backlight,intel_backlight,acpi_video0
REACT_DRM_DRM_DRIVER=appletbdrm
REACT_DRM_USB_VENDOR=05ac
REACT_DRM_USB_PRODUCT=8302
REACT_DRM_USB_BRIDGE=apple-bce,bce-vhci
```

## Найденный bug с public/logo.png

Pinned версия `react-drm` ожидала:

```text
public/logo.png
```

относительно current working directory.

Из-за этого первый запуск выдавал:

```text
ENOENT: no such file or directory, open 'public/logo.png'
```

Исправление:

```text
~/.local/share/react-drm/linux-touchbar-control-center/public
    -> /opt/react-drm/linux-touchbar-control-center/public
```

После этого runtime запускался нормально.

## Успешный запуск react-drm

Рабочий запуск подтверждал:

```text
DRM display ready: 2008×60 on /dev/dri/card0
renderer touch device ready
custom-layer bridge listening
logind sleep watcher active
```

USB Touch Bar при этом переходил в configuration 2.

## Почему от react-drm отказались

Главная причина — **нестабильная работа touch drag / slider UI**:

- video seek/progress bar реагировал один раз, после чего нормально не работал;
- brightness slider тоже работал некорректно;
- для планируемого интерфейса надёжнее использовать обычные кнопки, а не draggable sliders.

Поэтому дальнейшую доработку `react-drm` остановили.

---

# 2. mac-touchbar-plus / tiny-dfr

Ранее также исследовался `mac-touchbar-plus`.

Важно:

- это был не просто штатный `tiny-dfr`;
- использовался userspace helper для определения активного окна;
- рабочая идея была app-specific panels.

После решения вернуться к базовому состоянию Ubuntu T2 было принято удалить экспериментальные компоненты:

```text
mac-touchbar-plus
tiny-dfr
react-drm
```

и не трогать штатные kernel/T2 компоненты.

Если при следующем возврате к теме понадобится app-aware интерфейс, не начинать с предположения, что штатный `hid-appletb-kbd` умеет app profiles — он их не умеет.

---

# 3. Безопасность Touch Bar / runtime PM

Во время ранних экспериментов обнаружена важная проблема.

Нельзя без необходимости включать USB runtime autosuspend для Touch Bar Display / Backlight:

- Touch Bar Display: `05ac:8302`
- `hid-appletb-kbd`
- `hid-appletb-bl`

При `power/control=auto` устройство уже зависало в состоянии:

```text
suspending
```

а восстановление блокировалось в D-state.

Поэтому:

- **не запускать `powertop --auto-tune`;**
- не экспериментировать с runtime PM Touch Bar без необходимости;
- не запускать одновременно два Touch Bar renderer/daemon.

---

# 4. Штатный hid-appletb-kbd

После удаления кастомных renderer'ов решили использовать штатный `hid-appletb-kbd`.

Он работает в firmware keyboard mode и не требует DRM-renderer.

## Поддерживаемые режимы

Sysfs `mode`:

```text
0 = Escape only
1 = Function keys
2 = Media / brightness keys
3 = None
```

## Встроенный media keymap

В media-режиме слоты соответствуют примерно:

```text
F1  -> Brightness Down
F2  -> Brightness Up
F3  -> Reserved
F4  -> Reserved
F5  -> Keyboard Backlight Down
F6  -> Keyboard Backlight Up
F7  -> Previous Song
F8  -> Play/Pause
F9  -> Next Song
F10 -> Mute
F11 -> Volume Down
F12 -> Volume Up
```

## Поддерживаемые параметры модуля

Ожидаемый набор параметров:

```text
mode
fntoggle
autodim
dim_timeout
idle_timeout
double_press_switch_time
```

Точный список текущего установленного модуля всегда лучше проверить:

```bash
modinfo hid_appletb_kbd | grep '^parm:'
```

### Значение параметров

```text
mode=1
```

Основной слой F1..F12.

```text
fntoggle=1
```

При удержании Fn временно переключаться на media layer.

```text
autodim=1
```

Автоматически приглушать и выключать Touch Bar по idle timeout.

```text
dim_timeout=N
```

Через N секунд без активности уменьшить яркость.

```text
idle_timeout=N
```

Через N секунд после dim полностью погасить Touch Bar.

```text
double_press_switch_time=N
```

T2Linux patch: двойной Fn в пределах N миллисекунд фиксирует другой основной слой.

```text
double_press_switch_time=0
```

отключает эту функцию.

---

# 5. Текущая желаемая штатная конфигурация

Пользователь решил оставить простой штатный режим:

```text
обычно:
F1 ... F12

удержание Fn:
media / brightness

отпускание Fn:
F1 ... F12
```

Плюс быстрое выключение Touch Bar при бездействии.

Последний показанный `/etc/modprobe.d/tb.conf`:

```text
options hid-appletb-kbd mode=1 fntoggle=1 autodim=1 dim_timeout=30 idle_timeout=15 double_press_switch_time=300
```

То есть на тот момент:

- основной слой должен быть F1..F12;
- Fn — временный media layer;
- dim через 30 секунд;
- off ещё через 15 секунд;
- двойной Fn за 300 ms может фиксировать слой.

Если нужен **строго временный media layer только пока удерживается Fn**, изменить:

```text
double_press_switch_time=0
```

---

# 6. INITRAMFS / BOOT PARAMETERS

`hid_appletb_kbd` загружается достаточно рано, поэтому параметры из `/etc/modprobe.d/tb.conf` должны попадать в initramfs.

После выполнения:

```bash
sudo update-initramfs -u -k "$(uname -r)"
sudo reboot
```

штатный Touch Bar начал работать с текущей конфигурацией.

Следующий диагностический шаг при возврате к теме:

```bash
for p in mode fntoggle autodim dim_timeout idle_timeout double_press_switch_time; do
    printf '%-28s = ' "$p"
    cat "/sys/module/hid_appletb_kbd/parameters/$p" 2>/dev/null || echo "N/A"
done
```

Это покажет **реальные параметры уже загруженного kernel module**, а не содержимое конфигурационного файла.

Если runtime значения не соответствуют `/etc/modprobe.d/tb.conf`, следующий шаг:

```bash
sudo update-initramfs -u -k "$(uname -r)"
```

и проверить присутствие файла:

```bash
lsinitramfs "/boot/initrd.img-$(uname -r)" | grep 'modprobe.d/tb.conf'
```

после чего reboot.

Текущий baseline после `update-initramfs` подтверждён рабочим. При будущих изменениях параметров снова обновлять initramfs.

---

# 7. Идея отдельного будущего проекта

Обсуждалась возможность форкнуть/патчить `hid-appletb-kbd` и сделать три слоя:

```text
F1..F12
Media
Custom 12 buttons
```

с переключением Fn.

В custom layer можно было бы использовать F13..F24 как отдельные события, а userspace daemon назначал бы им действия в зависимости от активного приложения.

**Эту идею сознательно отложили как отдельный проект.**

Не смешивать её с текущей задачей настройки штатного `hid-appletb-kbd`.

---

# 8. Что не нужно повторять при следующем разговоре

Уже установлено/исследовано ранее:

- T2 kernel и Touch Bar kernel modules работают.
- `react-drm` удалось собрать и запустить.
- native DRM renderer работал на `2008×60`.
- проблема `public/logo.png` была найдена и исправлена.
- sliders/drag в react-drm для нашей задачи оказались ненадёжными.
- штатный `hid-appletb-kbd` не поддерживает произвольные app-specific панели.
- `hid-appletb-kbd` не позволяет userspace-конфигом добавлять/удалять произвольные клавиши.
- **GNOME extension `Window Monitor Pro` уже установлен и оставлен в системе.**
- custom three-layer `hid-appletb-kbd` — отдельный будущий проект.

Текущая точка продолжения:

> Штатный Touch Bar считается рабочим baseline. App-aware/custom layers — отдельный будущий проект.
