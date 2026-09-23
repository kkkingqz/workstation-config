title: ws-rebuild
section: 1
date: 2026-09-23
source: Workstation
volume: User Commands

# UBUNTU T2 WORKSTATION — REBUILD TO CURRENT BASELINE

# 0. До удаления рабочей системы

С рабочей Ubuntu выполнить:

```bash
./scripts/collect-current-baseline.sh --with-firmware
```

Скопировать полученный архив за пределы ноутбука.

Также сохранить:

- user data;
- нужные Btrfs snapshots только как дополнительный rollback source;
- текущий rebuild kit;
- установочный T2-Ubuntu ISO и SHA256.

# 1. Подготовка macOS / T2

Если macOS остаётся:

- обновить firmware Mac;
- оставить Apple EFI;
- в Recovery разрешить загрузку альтернативной ОС;
- Apple Secure Boot для Linux отключён;
- не форматировать Apple EFI;
- сохранить возможность получить Apple Wi‑Fi/Bluetooth firmware из macOS.

# 2. Установка Ubuntu

Целевая система:

```text
Ubuntu 26.04.1 LTS
GNOME 50
Wayland
amd64
MacBookPro16,1 / T2
```

Использовать актуальный T2-Ubuntu image.

Разметка — только manual.

Apple EFI:

```text
mount: /boot/efi
format: NO
```

Linux root — Btrfs.

UUID и имя раздела **не переносить из старого архива вслепую**: после новой разметки они могут измениться.

# 3. Btrfs layout

Итоговая структура:

```text
@
@home
@root
@srv
@cache
@tmp
@log
.snapshots
```

Root должен загружаться с:

```text
rootflags=subvol=@
```

В архиве rebuild kit сохранены проверенные вспомогательные scripts:

```text
reference/t2-ubuntu-btrfs-live-migrate-v2.sh
reference/t2-ubuntu-btrfs-boot-repair.sh
```

Использовать их только после проверки актуальных disk/partition names.

После установки проверить:

```bash
findmnt /
sudo btrfs subvolume list /
cat /etc/fstab
```

# 4. T2 repository, kernel и firmware

Нужны:

```text
linux-t2
apple-t2-audio-config
Apple Wi‑Fi/Bluetooth firmware
```

Если installer уже подключил T2 repository, повторно его не добавлять.

Если нет — использовать актуальную T2Linux Ubuntu instruction для codename `resolute`.

После установки:

```bash
uname -r
lsmod | grep -E 't2bce|appletb|brcmfmac|hci_bcm'
wpctl status
bluetoothctl show
```

Machine-state archive содержит точный список текущих T2 packages и APT sources.

# 5. Boot / rEFInd

rEFInd остаётся основным boot menu.

В state archive сохраняются:

- rEFInd config;
- `refind_linux.conf`, если присутствует;
- текущий `/proc/cmdline`;
- `/etc/fstab`;
- boot inventory.

Текущий рабочий kernel cmdline должен содержать как минимум используемые сейчас параметры:

```text
intel_iommu=on
iommu=pt
pm_async=off
pcie_aspm=force
pcie_aspm.policy=powersave
```

Не добавлять параметры, которых нет в зафиксированном рабочем `/proc/cmdline`.

После восстановления boot config заменить старые UUID на UUID новой установки там, где это требуется.

Generic Ubuntu kernel оставить как fallback boot option.

# 6. GNOME baseline

Нужен штатный Ubuntu desktop:

```text
GDM3
GNOME Shell
Mutter
Wayland
Ubuntu Dock
Nautilus
GNOME Settings
NetworkManager
BlueZ
PipeWire/WirePlumber
XWayland
xdg-desktop-portal + GNOME backend
```

Проверить:

```bash
echo "$XDG_SESSION_TYPE"
echo "$XDG_CURRENT_DESKTOP"
systemctl status gdm3 --no-pager
systemctl --user is-active pipewire
systemctl --user is-active wireplumber
```

Не ставить SwayNC/SwayOSD/swaylock/swayidle и не заменять штатные GNOME components.

# 6.1. Keyboard / shortcuts

После clone `workstation-config` восстановить system-level keyboard state:

```console
~/.local/share/workstation-config/bin/ws-keyboard-system-apply
```

Он устанавливает:

```text
/etc/udev/rules.d/99-workstation-uinput.rules
GDM/login layout = US only
/etc/tiny-dfr/config.toml (если tiny-dfr уже установлен)
```

Затем установить наши GNOME extensions:

```console
~/.local/share/workstation-config/bin/ws-keyboard-install-extensions
```

После первой установки extensions на Wayland выполнить logout/login.

Затем:

```console
~/.local/share/workstation-config/bin/ws-tiling-apply
~/.local/share/workstation-config/bin/ws-keyboard-apply
```

Целевые input sources:

```text
us
ru
ua
```

Проверить:

```console
ws-input-source status
ws-workstation-verify
```

Ожидаемое поведение:

```text
CapsLock             EN <-> RU; UA -> EN
Fn+CapsLock          UA
Control+Space        EN -> RU -> UA -> EN
GDM/login            EN
GNOME lock screen    EN
```

# 7. Графика

Целевое состояние:

```text
Intel UHD 630  → primary desktop GPU
AMD dGPU       → render/offload
```

Не пытаться автоматически воспроизвести старые экспериментальные AMD power tweaks.

Machine-state archive содержит:

- текущий kernel cmdline;
- `lspci -nnk`;
- relevant `/etc/modprobe.d`;
- installed packages.

После восстановления проверить реальное распределение GPU, а не только наличие двух adapters.

# 8. Suspend / power

Целевой режим:

```text
deep / S3
```

Проверить:

```bash
cat /sys/power/mem_sleep
```

Затем ручной тест:

```bash
systemctl suspend
```

После resume проверить Wi‑Fi, Bluetooth, audio, camera, GPU и Touch Bar.

Не запускать:

```text
powertop --auto-tune
TLP
auto-cpufreq
```

Touch Bar USB runtime PM специально не оптимизировать.

# 9. Touch Bar

Текущий baseline — `tiny-dfr`, а не firmware-only `hid_appletb_kbd`.

Установить пакет из используемого T2 repository:

```console
sudo apt install tiny-dfr
```

Затем повторно применить system-level workstation config:

```console
ws-keyboard-system-apply
```

Source/runtime config:

```text
config/tiny-dfr/config.toml
/etc/tiny-dfr/config.toml
```

Целевое поведение:

```text
обычно          -> F1..F12
держим Fn       -> media / brightness
отпускаем Fn    -> F1..F12
double Fn       -> layer не фиксируется
```

Проверить:

```console
systemctl is-active tiny-dfr.service
grep -E '^(MediaLayerDefault|DoublePressSwitchLayers)'   /etc/tiny-dfr/config.toml
```

Не устанавливать одновременно другие Touch Bar renderer/daemon.

---

# 10. GNOME extensions текущего baseline

Для keyboard/window/tiling layer используются:

```text
xremap@k0kubun.com
window-control@carlo9890.github.io
Tiling Assistant (Ubuntu UUID либо upstream fallback)
workstation-smart-popup@local
workstation-input-source@local
```

`workstation-*` sources находятся в `workstation-config` и устанавливаются
командой:

```console
ws-keyboard-install-extensions
```

После изменения `extension.js` на Wayland выполнить logout/login.

`Window Monitor Pro` не является зависимостью текущего keyboard baseline.

---

# 11. Финальная проверка

Запустить:

```bash
ws-workstation-verify --strict
```

Затем вручную проверить:

- boot через rEFInd;
- generic-kernel fallback;
- Wi‑Fi;
- Bluetooth;
- speakers/mic;
- camera;
- Intel primary / AMD offload;
- `deep/S3` suspend;
- tiny-dfr F1…F12 / hold-Fn media;
- GNOME Overview / Dock / Quick Settings / Nautilus;
- keyboard profile: Caps/UA/GDM/lock behavior;
- Smart Popup / tiling / Window Control.

После этого установка считается восстановленной до текущего baseline.
