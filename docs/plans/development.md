title: ws-plan-dev
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

# DISTROBOX / PODMAN — MANAGED APPLICATION & DEVELOPMENT LAYER

## Статус

Слой завершён и проверен 2026-09-26.

Цель — держать containerized applications и toolchains вне Ubuntu host, при этом
сохранять понятный lifecycle, отдельный HOME для каждого managed box и
воспроизводимые desktop exports.

# 1. Host infrastructure

На host устанавливаются только integration packages из Ubuntu repository:

```console
sudo apt install --no-install-recommends -y \
    podman distrobox uidmap fuse-overlayfs slirp4netns passt
```

Проверка:

```console
podman info --format '{{.Host.Security.Rootless}}'
grep "^$USER:" /etc/subuid /etc/subgid
```

Ожидается rootless Podman.

# 2. Source of truth

```text
config/distrobox/containers.ini
config/distrobox/exports.ini
config/fish/completions/wsbox.fish
bin/wsbox
```

Managed containers:

```text
ubuntu
arch
wine
```

Каждый использует отдельный persistent HOME:

```text
~/.local/share/distrobox-homes/ubuntu
~/.local/share/distrobox-homes/arch
~/.local/share/distrobox-homes/wine
```

Rootfs контейнера считается disposable. Custom HOME считается persistent state.

# 3. wsbox

Runtime helper:

```text
~/.local/bin/wsbox -> ~/.local/share/workstation-config/bin/wsbox
```

Основные команды:

```text
wsbox list
wsbox status [NAME]
wsbox check
wsbox dry-run [NAME]
wsbox apply [NAME]
wsbox create NAME
wsbox enter NAME
wsbox run NAME COMMAND [ARG...]
wsbox stop NAME
wsbox remove --force NAME
wsbox recreate NAME
wsbox apps [NAME]
wsbox export NAME APP
wsbox unexport NAME APP
```

`apply` не заменяет существующий container и поэтому idempotent.
`recreate`/`remove --force` затрагивают rootfs, но не удаляют managed definition
и custom HOME.

# 4. Declarative desktop exports

Desired exports задаются только в:

```text
config/distrobox/exports.ini
```

Текущий managed export:

```text
arch / winbox3
    source: /usr/share/applications/winbox3.desktop
    host:   ~/.local/share/applications/arch-winbox3.desktop
```

`wsbox apply` восстанавливает отсутствующий launcher, если source desktop file
есть внутри контейнера.

Если после destructive rebuild приложение ещё не переустановлено, source
считается `missing-source`; это `WARN`, а не повреждение контейнера.

# 5. Назначение containers

## ubuntu

Чистый Ubuntu 26.04 base box для Ubuntu-specific tools и compatibility tests.

## arch

Rolling Arch box для приложений/пакетов, которые удобнее получать из Arch/AUR.
Текущий production use case — WinBox 3.x.

## wine

Чистый Ubuntu 26.04 base box, зарезервированный для будущего `plan-windows`.
Wine stack в нём пока намеренно не установлен.

WinBox сейчас остаётся в `arch`, потому что используется пакет `winbox3` из AUR.

# 6. Arch / WinBox 3.x

После чистого rebuild Arch сначала подготовить AUR tooling:

```console
wsbox enter arch
sudo pacman -Syu --needed base-devel git
```

Затем установить repo-managed NTSync provider из раздела 7 и только после этого
ставить Wine/WinBox.

Обычный `paru` можно собрать из AUR:

```fish
set tmp (mktemp -d)
git clone https://aur.archlinux.org/paru.git "$tmp/paru"
cd "$tmp/paru"
makepkg -si
cd
rm -rf "$tmp"
```

После этого:

```console
paru -S winbox3
```

Экспорт launcher выполняет не `paru`, а `wsbox`:

```console
wsbox apply arch
```

# 7. Host NTSync и Arch virtual provider

Wine использует NTSync из **host kernel**. Distrobox не имеет собственного
работающего kernel.

Host source of truth:

```text
config/distrobox/host/modules-load.d/ntsync.conf
```

Runtime:

```text
/etc/modules-load.d/ntsync.conf
```

Применение:

```console
sudo install -Dm644 \
    ~/.local/share/workstation-config/config/distrobox/host/modules-load.d/ntsync.conf \
    /etc/modules-load.d/ntsync.conf

sudo modprobe ntsync
ls -l /dev/ntsync
```

Arch `wine` зависит от `ntsync-autoload`, а тот требует virtual dependency:

```text
NTSYNC-MODULE
```

Если provider отсутствует, pacman/paru предлагает container-local Arch kernel,
что для Distrobox не нужно и приводит к лишним `linux`, `mkinitcpio`,
`vmlinuz-linux` и `initramfs-linux.img`.

Repo-managed provider:

```text
config/distrobox/arch/wsbox-host-ntsync/PKGBUILD
config/distrobox/arch/wsbox-host-ntsync/README.md
```

Сборка внутри `arch`:

```console
cd ~/.local/share/workstation-config/config/distrobox/arch/wsbox-host-ntsync
makepkg --clean --cleanbuild --force
sudo pacman -U ./wsbox-host-ntsync-1-1-any.pkg.tar.zst
```

Пакет намеренно не содержит kernel module и только объявляет:

```text
Provides: NTSYNC-MODULE
```

Реальный module/device предоставляет host.

Целевое состояние:

```text
wsbox-host-ntsync   installed
ntsync-autoload     installed
wine                installed

linux               absent
mkinitcpio          absent
mkinitcpio-busybox  absent

/dev/ntsync         present
```

Проверка package database:

```console
pacman -T NTSYNC-MODULE
pacman -Dk
```

`pacman -T` не должен ничего выводить, `pacman -Dk` должен сообщать, что ошибок
database нет.

Во время запуска WinBox `winbox.exe`, `wineserver` и `winedevice.exe` реально
держат `/dev/ntsync` открытым; это было проверено 2026-09-26.

# 8. WinBox persistent state и scale

Wrapper `winbox3` использует prefix:

```text
$HOME/.winbox/wine
```

Так как `$HOME` у `arch` — custom HOME Distrobox, prefix находится на host здесь:

```text
~/.local/share/distrobox-homes/arch/.winbox/wine
```

Prefix переживает `wsbox remove --force arch` и `wsbox recreate arch`.

Текущий DPI baseline:

```text
LogPixels = 192 decimal = 0xc0
scale     = 200%
```

Проверка:

```console
wsbox run arch bash -lc '
export WINEPREFIX="$HOME/.winbox/wine"
wine reg query "HKEY_CURRENT_USER\Control Panel\Desktop" /v LogPixels
'
```

Если prefix новый, baseline выставляется так:

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

# 9. GUI validation

Distrobox GUI integration проверена реальными desktop applications.

WinBox 3.x:

- exported launcher запускается из GNOME;
- persistent Wine prefix работает;
- 200% scale работает;
- NTSync используется фактически.

Krita использовалась как временный Qt6/Wayland diagnostic application.
Первый запуск был медленным из-за Btrfs writeback/fdatasync; последующие старты
были быстрыми. После проверки Krita удалена и не является managed app.

# 10. Recovery contract

Проверенный destructive recovery:

```text
containers.ini
    -> wsbox apply
    -> recreates disposable runtime container

custom HOME
    -> survives remove/recreate

exports.ini
    -> restores launcher when source app exists
```

Для `arch` после rootfs rebuild:

```text
winbox3 package       disappears
$HOME/.winbox/wine    survives
LogPixels 0xc0        survives
desktop export        removed with container
```

После `wsbox apply arch` до переустановки WinBox:

```text
arch/winbox3 -> missing-source
```

Это ожидаемый `WARN`.

После переустановки `wsbox-host-ntsync`, `paru`/`winbox3` и повторного
`wsbox apply arch` export восстанавливается.

# 11. Validation

Полная проверка managed layer:

```console
wsbox status
wsbox apps
wsbox check
```

Текущий ожидаемый managed result:

```text
FAIL=0
```

На этой машине дополнительно существуют unmanaged build containers:

```text
t2bce-build
touchbar-build
```

Поэтому `wsbox check` сейчас показывает два ожидаемых warning:

```text
FAIL=0 WARN=2
```

Они не принадлежат managed Distrobox application layer.

# 12. Host boundary

На Ubuntu host без необходимости не ставятся:

- project Python versions и `pipx`;
- Rust toolchains;
- Node version managers;
- random SDKs/compilers;
- Wine.

Исключения — infrastructure, kernel/hardware, desktop integration и
virtualization.

# DONE

Проверено:

- rootless Podman;
- Ubuntu и Arch lifecycle;
- отдельный custom HOME;
- idempotent `wsbox apply`;
- managed desktop export/unexport/restore;
- empty `wine` base box;
- destructive recovery `wine` и `arch`;
- persistent WinBox prefix;
- host NTSync + Arch virtual provider без container-local kernel;
- фактическое использование `/dev/ntsync` Wine;
- `wsbox check` без managed failures.
