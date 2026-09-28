title: ws-rebuild
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# UBUNTU T2 WORKSTATION — REBUILD

# 0. До удаления рабочей системы

Собрать то, чего нет в репозитории, и унести архив с ноутбука:

```console
ws collect                      # ./ws-collect-HOST-DATE.tar.gz, спрашивает sudo
ws checkpoint create before-reinstall
```

`ws collect` (`ws collect --help`) кладёт в архив:

- `baseline/` — `ws baseline capture --with-sudo`: проверки, GNOME,
  Flatpak, Distrobox, ссылки, системные файлы, пакеты — эталон, с которым
  сравнивается новая установка (`ws baseline diff`);
- `boot/` — `/proc/cmdline`, fstab, `refind_linux.conf`, `lsblk`, `blkid`,
  `efibootmgr -v`, subvolumes Btrfs;
- `apt/` — sources, ручные и held пакеты, `dpkg -l`;
- `firmware/` — файлы `/lib/firmware/brcm` без пакета: Wi-Fi/Bluetooth
  Apple, взятые из macOS (без macOS их больше не получить);
- `state/` — `~/.local/state/workstation` (backup сочетаний, checkpoints);
- `meta/` — коммит и незакоммиченные изменения.

Отдельно: пользовательские данные, нужные Btrfs snapshots, установочный
T2-Ubuntu ISO и его SHA256. Незапушенные коммиты — `git push`.

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

Актуальный T2-Ubuntu image (t2linux). Разметка — только manual:

```text
Apple EFI     /boot/efi, не форматировать
ESP rEFInd    отдельный раздел (сейчас nvme0n1p3), не монтируется
Linux root    Btrfs
```

UUID и PARTUUID новой установки другие: их записать в
`nix/hosts/<host>/facts.nix` (`rootUuid`, `refindEspPartuuid`) до `ws system
apply` — из них собираются `refind_linux.conf`, `refind.conf` и manifest.
Старые значения — в `boot/blkid.txt` архива.

# 3. Btrfs layout

Целевая структура:

```text
@  @home  @root  @srv  @cache  @tmp  @log  .snapshots
@nix       создаёт bootstrap.sh (раздел 6.0)
```

Root грузится с `rootflags=subvol=@`. Проверенного скрипта раскладки нет:
если installer создал не все subvolumes, их создают из live-системы
(`btrfs subvolume create`, перенос каталогов, строки в fstab) — прежняя
раскладка и fstab есть в `boot/` архива.

```bash
findmnt /
sudo btrfs subvolume list /
cat /etc/fstab
```

# 4. T2 repository, kernel и firmware

```text
linux-t2                  held (патч t2bce под версию ядра, helpws suspend)
apple-t2-audio-config
Apple Wi‑Fi/Bluetooth firmware
```

T2 repository (t2linux, codename `resolute`) — если installer его не
подключил. Пакеты — `nix/hosts/mbp16/apt.txt` (ставит `bootstrap.sh`).

Firmware: `get-apple-firmware.service` (`ws system apply`) берёт её из macOS
при загрузке. Без macOS — из архива:

```console
sudo cp -a firmware/* /lib/firmware/brcm/
```

Проверка:

```bash
uname -r
lsmod | grep -E 't2bce|appletb|brcmfmac|hci_bcm'
wpctl status
bluetoothctl show
```

Патченые модули t2bce — `ws-suspend t2bce-build && ws-suspend t2bce-install`
(раздел 8).

# 5. Boot / rEFInd

rEFInd — основное меню. Всё, что ему нужно, собирается из репозитория
(`facts.nix`: `kernelParams`, `refindDefaultParams`, `rootUuid`):

```text
/boot/refind_linux.conf      ставит ws system apply
EFI/BOOT/refind.conf (ESP)   копируется вручную (helpws workstation, GRAPHICS)
grub.d drop-ins              ставит ws system apply (GRUB — recovery)
```

Параметры ядра: `intel_iommu=on iommu=pt pm_async=off`.
`pcie_aspm=force` и `pcie_aspm.policy=powersave` не добавлять: с ними T2
отказывала в stateful suspend (`helpws suspend`). Пункт «Ubuntu» добавляет
`ws.dgpu=off` (AMD выключена), ручной «Ubuntu (AMD)» грузит `/boot/ws` без
него. Generic Ubuntu kernel остаётся запасным пунктом.

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


# 6.0. Bootstrap и слои

После разделов 2–5 (Ubuntu, Btrfs, T2, rEFInd) и штатного GNOME вся
конфигурация ставится так (`helpws layers`):

```console
sudo apt install git
git clone https://github.com/kkkingqz/wsconfig.git ~/wsconfig
~/wsconfig/bootstrap.sh
# logout/login: группа nix-users, PATH из 00-nix.fish, fish как login shell
ws system apply     # системные файлы (sudo); затем reboot, если менялись modprobe/udev/cmdline
ws apply            # расширения → tiling → клавиатура → Flatpak → Distrobox
# logout/login: новые расширения GNOME активируются только в новой сессии
ws apply            # шаг keyboard, не прошедший preflight в первый раз
ws check            # проверки всех владельцев и verify (связи между слоями)
```

`bootstrap.sh` (от пользователя, sudo вызывает сам; `--dry-run` только
показывает шаги): subvolume `@nix` и строка `/nix` в fstab → пакеты из
`nix/hosts/apt.txt` и `nix/hosts/<host>/apt.txt` (с PPA fish) → `nix-users` → fish
как login shell → первый `ws switch` (заменяемые файлы сохраняются как
`*.pre-hm`). Хост определяется по hostname (`ws host`); для новой машины —
`WS_HOST=<name>` и каталог `nix/hosts/<name>/`. Повторный запуск ничего не
меняет.

Шаг `ws apply`, чей preflight не прошёл (exit 69), выводится в конце как
`PREFLIGHT`; отдельный шаг — `ws apply keyboard`.

`ws system diff` сравнивает системные файлы (`/etc`, `/boot`, `/usr/local`,
`/usr/lib/systemd/system-sleep`), собранные Nix из `system/`, с
установленными; ничего не меняет. Пустой вывод — система совпадает с repo.
`ws check apt` сравнивает списки apt с установленными пакетами и только
сообщает о различиях. `ws check` запускает проверки владельцев: `ws check
repo` (checkout), `ws check home` (home-manager, Nix, man), `ws-keyboard
check`, `ws-gnome check`, `wsflatpak check`, `wsbox check`, `wswin check`,
`ws-suspend check`, `ws system check`, `ws check apt` и последним
`ws-workstation-verify` — только связи между слоями (GNOME ↔ клавиатура,
ядро ↔ t2bce, загрузка ↔ dGPU, Distrobox ↔ NTSync). Каждая проверка с
`--json` печатает один объект `{"status","passes","warnings","failures",
"messages"}` (`lib/check.bash`); `ws check` читает только его, текст для
людей можно менять.
`ws update` обновляет всё, что не закреплено, до последних версий: apt
(`sudo apt full-upgrade`, `linux-t2` остаётся held), Nix (`nix flake update`,
разница пакетов, switch; изменившийся `flake.lock` закоммитить), Flatpak,
пакеты внутри контейнеров (`wsbox update`) и расширения с
extensions.gnome.org (GNOME Shell скачивает обновления, как Extension
Manager; ставятся после logout/login). Отдельный шаг — `ws update nix`.
Закреплены намеренно: ядро (`linux-t2`, `system/kernel/t2bce/t2bce.nix`),
xremap (`nix/pkgs/xremap.nix`), расширения с `pin`, образы по digest.
Новости home-manager (изменения опций после обновления `flake.lock`) — `ws
news`; `ws switch` о них не уведомляет (`news.display = "silent"`), а
`home-manager news` без `--flake` конфигурацию не находит.

Checkpoint — какой коммит соответствовал какому рабочему состоянию.
`bin/`, fish и Ghostty — ссылки в checkout (`nix/home/links.nix`), поэтому
откат поколения home-manager не откатывает пользовательский слой: ключ —
коммит, поколение и системное дерево — то, что из него собрано.

```console
ws checkpoint create before-update   # тег checkpoint/before-update (локальный)
ws checkpoint list
ws checkpoint diff before-update     # коммиты, пакеты (nvd), системное дерево, ядро
ws checkpoint diff before-update --baseline
ws checkpoint show before-update     # что записано и команды возврата
ws checkpoint remove before-update
```

`create` без sudo и только для согласованного состояния: checkout без
изменений, активное поколение собрано из этого коммита (иначе `ws switch`),
`ws system check` без различий (иначе `ws system apply`). Записывает в
`~/.local/state/workstation/checkpoints/NAME/` коммит, поколение, системное
дерево, ядро, установленные ядра и held-пакеты, держит поколение и дерево
GC roots и снимает `ws baseline capture checkpoint-NAME --no-boxes`.
Сам ничего не откатывает; `show` печатает шаги: `git switch --detach
checkpoint/NAME`, `ws switch`, `ws system apply`, загрузка записанного ядра.
`ws system apply` дополнительно пишет в `~/.local/state/workstation/system/`
ссылку `applied` на поставленное дерево и строку в `history` (дата, коммит,
дерево, результат).

Flatpak: remotes и overrides объявлены в `flatpak/flatpak.nix`, приложения —
в `flatpak/apps.txt` (`wsflatpak install` дописывает туда сам, `ws switch` коммитит); `ws switch` собирает из них
`~/.local/share/workstation/flatpak/` и ставит `.desktop` Claude, шаг `flatpak`
в `ws apply` (`wsflatpak apply`) добавляет remotes, ставит приложения и
применяет overrides (`helpws flatpak`).

Разделы 6.1–10 ниже описывают те же шаги по отдельности.

# 6.1. Managed GNOME appearance

После clone repository сначала проверить текущий desktop state:

```console
ws-gnome status
ws-gnome check
```

Source of truth:

```text
gnome/gnome.nix
```

Профиль записывает `ws switch` (home-manager `dconf.settings`); отдельного
шага в `ws apply` нет. Drift в `ws-gnome check` значит, что ключ изменили
вручную: следующий `ws switch` запишет значение из `gnome.nix` снова.

Профиль не управляет display scale, `monitors.xml`, Mutter
experimental flags, keyboard/input sources, extension enablement, wallpaper,
Flatpak, Distrobox или Wine.

Display scale после reinstall выбирается штатно через `Settings -> Displays`;
текущий рабочий checkpoint — logical scale `1.5`.

Wine не устанавливать на host: Windows-программы живут в контейнерах
`wine-wayland`, `wine`, `proton` (`helpws windows`).



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
`ws switch` (`nix/home/links.nix`, `helpws layers`). Без Nix —
вручную:

```console
repo="$HOME/wsconfig"

mkdir -p "$HOME/.local/bin" "$HOME/.config/fish/completions"

ln -sfn "$repo/bin/wsbox" "$HOME/.local/bin/wsbox"
ln -sfn \
    "$repo/terminal/fish/completions/wsbox.fish" \
    "$HOME/.config/fish/completions/wsbox.fish"
```

Host NTSync source of truth:

```text
system/files/modules-load.d/ntsync.conf
```

Ставит его `ws system apply` (раздел 6.0); вручную:

```console
sudo install -Dm644 \
    "$repo/system/files/modules-load.d/ntsync.conf" \
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
wine-wayland
wine
proton
t2bce-build
touchbar-build
```

Custom HOME каждого box находится в `~/distrobox/<имя>/` и не
удаляется `wsbox remove`/`recreate`.
`distrobox rm` (его вызывают `remove` и `recreate`) удаляет
экспортированные ярлыки контейнера; `recreate` экспортирует их заново, а
если приложения ещё нет (AUR в `arch`), пишет WARN — после установки
`wsbox apply NAME`.

Virtual provider host NTSync (`wsbox-host-ntsync`, `NTSYNC-MODULE`) Arch
ставит сам при создании: `base-devel` и `git` — пакеты контейнера, init hook
`distrobox/arch/wsbox-host-ntsync/install-hook` собирает пакет от имени
пользователя и ставит его (при каждом старте контейнера, если его нет). Без
него pacman/paru тянут в контейнер ядро `linux` для `ntsync-autoload`.
Проверка:

```console
wsbox run arch pacman -Qi wsbox-host-ntsync
```

AUR-пакеты в `arch` — через `paru`; если он ещё не установлен:

```fish
set tmp (mktemp -d)
git clone https://aur.archlinux.org/paru.git "$tmp/paru"
cd "$tmp/paru"
makepkg -si
cd
rm -rf "$tmp"
```

Проверить, что Arch-контейнеры (`arch`, `wine-wayland`, `proton`) не
содержат собственного kernel/initramfs stack:

```console
wsbox run wine-wayland bash -lc '
pacman -Q wsbox-host-ntsync wine ntsync-autoload
for p in linux mkinitcpio mkinitcpio-busybox
do
    pacman -Q "$p" 2>/dev/null || echo "$p: absent"
done
ls -l /dev/ntsync
pacman -Dk
'
```

Windows-контейнеры (`wine-wayland`, `wine`, `proton`) ставят Wine, WineHQ
и umu сами при создании (хуки в `distrobox.nix`, `helpws windows`).
Prefixes лежат в их HOME и переживают recreate. WinBox — prefix
`~/distrobox/wine-wayland/prefixes/winbox` (`LogPixels=144`), launcher
`ws-win-winbox.desktop` из `windows/apps.nix`. Если prefix потерян:

```console
wswin prefix --box wine-wayland winbox init
```

и положить `winbox.exe` (WinBox 3.x, mikrotik.com) в
`~/distrobox/wine-wayland/prefixes/winbox/drive_c/Program Files/WinBox/`.

Steam — flatpak (`wsflatpak apply`), udev-правила контроллеров — `steam-devices`
из `nix/hosts/apt.txt` (`sudo apt install steam-devices`; `ws check apt` сверяет список).

Проверка:

```console
wsbox check
```

Ожидаемо `FAIL=0 WARN=0`. Контейнеры объявлены в
`distrobox/distrobox.nix` (`containers.ini` собирает `ws switch`);
build-контейнеры `t2bce-build` и `touchbar-build` тоже там; Rust в `touchbar-build` —
rustup в его HOME (`~/distrobox/touchbar-build/.rustup`, `.cargo`), на новой
машине ставится вручную (`helpws workstation`, Managed Distrobox layer).

Подробности:

```console
helpws distrobox
```


# 6.4. Keyboard / shortcuts

После clone `wsconfig` восстановить system-level keyboard state:

```console
~/wsconfig/bin/ws-keyboard-system-apply
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

Это обёртка над `ws system apply` (нужен Nix, раздел 6.0): он ставит все
системные файлы из `system` — и suspend layer из раздела 8, и T2
base из разделов 4–5, — только отличающиеся, с бэкапом в
`/var/backups/workstation/system-<время>/`. Без изменений:
`ws system diff`.

Затем установить наши GNOME extensions:

```console
~/wsconfig/bin/ws-keyboard-install-extensions
```

После первой установки extensions на Wayland выполнить logout/login.

Затем:

```console
~/wsconfig/bin/ws-tiling-apply
~/wsconfig/bin/ws-keyboard-apply
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
ws-keyboard check
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
AMD dGPU       → выключена в rEFInd «Ubuntu» (ws.dgpu=off), render/offload в «Ubuntu (AMD)»
```

Выключение AMD ставит `ws system apply` (`ws-dgpu-off`, `helpws workstation`,
GRAPHICS). Других AMD power tweaks не воспроизводить.

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
установленного ядра нет записи в `system/kernel/t2bce/t2bce.nix`, сначала
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

Список всех расширений и источник каждого — `gnome/gnome-extensions.nix`;
`enabled-extensions` из него пишет `ws switch`.

`workstation-*` sources находятся в `wsconfig` и устанавливаются
командой:

```console
ws-keyboard-install-extensions
```

(шаг `extensions` в `ws apply`). После изменения `extension.js` на Wayland
выполнить logout/login.

Расширения с extensions.gnome.org (`xremap@k0kubun.com`,
`window-control@carlo9890.github.io`,
`window-monitor-pro@muhammed.hussien2030.gmail.com`) ставит тот же шаг
`extensions`, если их нет: последнюю версию для текущего GNOME Shell
(`gnome-extensions install`). Дальше их обновляет Extension Manager (или
`ws update extensions`). Включает их `ws switch` (`enabled-extensions`); на
новой машине — logout/login после первого `ws switch` и `ws apply`.

Закрепить версию: `pin = { version = N; hash = "sha256-…"; }` у расширения
в `gnome/gnome-extensions.nix` (N — номер из ссылки на zip EGO), `ws
switch`. Такое расширение ставит Nix ссылками, и обновлять его в Extension
Manager нельзя: verify покажет FAIL «files not from Nix», `ws update
extensions` при закреплённых расширениях отказывается.

`Window Monitor Pro` используется и входит в baseline расширений; keyboard
baseline от него не зависит.

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

# 12. Recovery

Из проверенного состояния (после раздела 11) обновить recovery:

```console
sudo system-backup-snapshot
```

Он делает `/.snapshots/backup-ro` и загружаемый `/.snapshots/recovery`
(предыдущее поколение — `*.previous`) и пункт в меню GRUB. Проверить один
раз: загрузиться в recovery через GRUB и вернуться.

`/nix` лежит в отдельном `@nix`: откат `@` не ломает ссылки home-manager в
`/nix/store`. Возврат `@` из recovery — `helpws history-nix`, раздел
«Возврат `@` из recovery».
