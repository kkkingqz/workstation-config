title: ws-rebuild
section: 1
date: 2026-09-26
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
```

`pcie_aspm=force` и `pcie_aspm.policy=powersave` **не** добавлять: с ними
T2 отказывала в stateful suspend (`helpws suspend`).

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


# 6.0. Пользовательский слой одной командой

Когда есть Nix и выполнен `ws switch` (`helpws plan-nix`), владельцы слоёв
вызываются по порядку одной командой, без sudo:

```console
ws apply            # расширения → tiling → клавиатура → GNOME → Flatpak → Distrobox
# logout/login: новые расширения GNOME активируются только в новой сессии
ws apply            # шаг keyboard, не прошедший preflight в первый раз
ws check            # verify, wsflatpak, wsbox, ws-gnome, ws-suspend: итог FAIL/WARN
```

Шаг, чей preflight не прошёл (exit 69), выводится в конце как `PREFLIGHT`.
Отдельный шаг: `ws apply keyboard`. Разделы 6.1, 6.3, 6.4 и 10 ниже
описывают те же шаги вручную.

# 6.1. Managed GNOME appearance

После clone repository сначала проверить текущий desktop state:

```console
ws-gnome status
ws-gnome check
```

Source of truth:

```text
config/gnome/settings.conf
```

Если `ws-gnome check` показывает drift относительно зафиксированного baseline,
просмотреть изменения:

```console
ws-gnome dry-run
```

и только после этого применить:

```console
ws-gnome apply
```

(шаг `gnome` в `ws apply`)

`ws-gnome apply` не управляет display scale, `monitors.xml`, Mutter
experimental flags, keyboard/input sources, extension enablement, wallpaper,
Flatpak, Distrobox или Wine.

Display scale после reinstall выбирается штатно через `Settings -> Displays`;
текущий рабочий checkpoint — logical scale `1.5`.

Wine не устанавливать на host. Его application layer относится к
`plan-windows` и будет жить в отдельном Distrobox.



# 6.2. Host Qt integration

Для host Qt5/Qt6 applications установить:

```console
sudo apt install --no-install-recommends \
    qgnomeplatform-qt5 \
    qgnomeplatform-qt6 \
    qtwayland5 \
    qt6-wayland
```

Не добавлять глобальные Qt platform/theme/scale environment overrides.

Ожидаемый baseline:

```text
Qt5 -> native Wayland + QGnomePlatform automatically
Qt6 -> native Wayland + QGnomePlatform automatically
```

Qt внутри Distrobox относится к managed Distrobox layer.


# 6.3. Distrobox / Podman managed layer

Установить только host infrastructure:

```console
sudo apt install --no-install-recommends -y \
    podman distrobox uidmap fuse-overlayfs slirp4netns passt
```

Runtime helper и Fish completion — ссылки home-manager, их создаёт
`ws switch` (`modules/home/links.nix`, `helpws plan-nix`). Без Nix —
вручную:

```console
repo="$HOME/.local/share/workstation-config"

mkdir -p "$HOME/.local/bin" "$HOME/.config/fish/completions"

ln -sfn "$repo/bin/wsbox" "$HOME/.local/bin/wsbox"
ln -sfn \
    "$repo/config/fish/completions/wsbox.fish" \
    "$HOME/.config/fish/completions/wsbox.fish"
```

Host NTSync source of truth:

```text
config/distrobox/host/modules-load.d/ntsync.conf
```

Применить:

```console
sudo install -Dm644 \
    "$repo/config/distrobox/host/modules-load.d/ntsync.conf" \
    /etc/modules-load.d/ntsync.conf

sudo modprobe ntsync
ls -l /dev/ntsync
```

Создать/восстановить managed containers:

```console
wsbox apply
wsbox status
```

(шаг `distrobox` в `ws apply`)

Managed set:

```text
ubuntu
arch
wine
```

Custom HOME каждого box находится в `~/.local/share/distrobox-homes/` и не
удаляется `wsbox remove --force`/`recreate`.

Для Arch перед установкой Wine/WinBox обязательно установить virtual provider
host NTSync, чтобы pacman не тянул container-local kernel:

```console
wsbox enter arch

sudo pacman -Syu --needed base-devel git

cd ~/.local/share/workstation-config/config/distrobox/arch/wsbox-host-ntsync
makepkg --clean --cleanbuild --force
sudo pacman -U ./wsbox-host-ntsync-1-1-any.pkg.tar.zst
```

Если `paru` ещё не установлен:

```fish
set tmp (mktemp -d)
git clone https://aur.archlinux.org/paru.git "$tmp/paru"
cd "$tmp/paru"
makepkg -si
cd
rm -rf "$tmp"
```

Затем внутри `arch`:

```console
paru -S winbox3
exit
```

Восстановить managed export:

```console
wsbox apply arch
wsbox apps arch
```

Проверить, что Arch не содержит собственного kernel/initramfs stack:

```console
wsbox run arch bash -lc '
pacman -Q wsbox-host-ntsync wine ntsync-autoload
for p in linux mkinitcpio mkinitcpio-busybox
do
    pacman -Q "$p" 2>/dev/null || echo "$p: absent"
done
ls -l /dev/ntsync
pacman -Dk
'
```

Если WinBox prefix новый, выставить текущий baseline 200%:

```console
wsbox run arch bash -lc '
export WINEPREFIX="$HOME/.winbox/wine"
export WINEARCH=win64
wineboot -u
wine reg add \
    "HKEY_CURRENT_USER\Control Panel\Desktop" \
    /v LogPixels \
    /t REG_DWORD \
    /d 192 \
    /f
wineserver -k 2>/dev/null || true
'
```

Существующий prefix в custom HOME сохраняется вместе с `LogPixels=0xc0`.

Контейнер `wine` сейчас должен оставаться чистым Ubuntu 26.04 base; полный Wine
application layer относится к `plan-windows`.

Проверка:

```console
wsbox check
```

На этой машине два unmanaged build containers (`t2bce-build`,
`touchbar-build`) дают ожидаемые WARN, но managed baseline должен иметь
`FAIL=0`.

Подробности:

```console
helpws distrobox
```


# 6.4. Keyboard / shortcuts

После clone `workstation-config` восстановить system-level keyboard state:

```console
~/.local/share/workstation-config/bin/ws-keyboard-system-apply
```

Он устанавливает:

```text
/etc/udev/rules.d/99-workstation-uinput.rules
GDM/login layout = US only
/etc/udev/rules.d/90-touchbar-native.rules
/etc/modprobe.d/tb.conf
/etc/modprobe.d/touchbar-native.conf
/usr/local/libexec/ws-touchbar-fn + ws-touchbar-fn.service
```

При изменении modprobe-файлов он сам пересобирает initramfs.

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

Расширения, tiling и клавиатура — шаги `extensions`, `tiling`, `keyboard`
в `ws apply`; `ws-keyboard-system-apply` (sudo) в него не входит.

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

Восстановить suspend layer из repository:

```console
ws-suspend apply
ws-suspend t2bce-build
ws-suspend t2bce-install
sudo reboot
```

`t2bce-build` требует `podman` и `linux-headers` текущего ядра. Если для
установленного ядра нет строки в `kernel/t2bce/sources.conf`, сначала
проверить upstream (`helpws suspend`, раздел «Обновление ядра»).

Проверить:

```bash
cat /sys/power/mem_sleep
ws-suspend status
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

Baseline — родной режим Touch Bar: кнопки рисует T2, режимом управляет
`hid-appletb-kbd`, Fn за xremap пробрасывает `ws-touchbar-fn`. Отдельный
пакет не нужен; `tiny-dfr` **не устанавливать** (причины: `helpws touchbar`).

Всё ставит system-level workstation config из раздела 6.4:

```console
ws-keyboard-system-apply
sudo reboot
```

Целевое поведение:

```text
обычно          -> F1..F12
держим Fn       -> media / brightness
отпускаем Fn    -> F1..F12
```

Проверить:

```console
cat /sys/bus/usb/devices/7-6/bConfigurationValue
lsmod | grep appletbdrm
systemctl is-active ws-touchbar-fn.service
```

Ожидается `1`, пустой вывод `lsmod` и `active`.

Не устанавливать Touch Bar renderer/daemon, которые переводят Touch Bar в
режим дисплея (`tiny-dfr`, `react-drm`, `mac-touchbar-plus`).

---

# 10. GNOME extensions текущего baseline

Для keyboard/window/tiling layer используются:

```text
xremap@k0kubun.com
window-control@carlo9890.github.io
Tiling Assistant (Ubuntu UUID либо upstream fallback)
workstation-smart-popup@local
workstation-dock-spring@local
workstation-input-source@local
```

`workstation-*` sources находятся в `workstation-config` и устанавливаются
командой:

```console
ws-keyboard-install-extensions
```

(шаг `extensions` в `ws apply`). После изменения `extension.js` на Wayland
выполнить logout/login.

`Window Monitor Pro` не является зависимостью текущего keyboard baseline.

`workstation-dock-spring@local` schema не использует. Общий installer должен
установить его runtime copy так же, как остальные local extensions.

После logout/login проверить:

```text
running Dock app + external file drag + 1.3 s hover
    -> existing window comes forward

closed Dock app + external file drag + long hover
    -> nothing happens
```


---

# 10.1. GNOME final verification

After restoring the GNOME host layer:

```console
ws-gnome test
```

Expected automatic result:

```text
RESULT: AUTOMATED CHECKS PASSED
```

Then manually verify Dock Spring:

```text
running/minimized app + file hover ~1.3 s -> existing window appears
closed pinned app + long file hover       -> application stays closed
Nautilus -> application window drop       -> works
```

The Touch Bar is validated separately in the T2 layer and does not block the
GNOME plan.

---

# 11. Финальная проверка

Запустить:

```bash
ws check
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
- Touch Bar F1…F12 / hold-Fn media (родной режим);
- GNOME Overview / Dock / Quick Settings / Nautilus;
- keyboard profile: Caps/UA/GDM/lock behavior;
- Smart Popup / tiling / Window Control.
- Dock Spring: running app activates after ~1.3 s hover;
- Dock Spring: closed app remains closed on hover.

После этого установка считается восстановленной до текущего baseline.
