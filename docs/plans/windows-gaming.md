title: ws-plan-windows
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# PLAN — WINDOWS APPS / WINE / STEAM / PROTON

## Статус

План пересмотрен 2026-09-28. Выполнено 2026-09-28: этапы 0–4, 6 (Steam
запускается), 5 — umu и Steam Runtime работают внутри `proton`, игра не проверялась.
WinBox из `wine` проверен пользователем; `winbox3` и export удалены из
`arch`, старый prefix `~/distrobox/arch/.winbox` ещё на месте. Steam
запустился (первый старт долгий: докачка клиента).
Решено при выполнении: запуск через `wswin` идёт из HOME контейнера
(distrobox с custom HOME отдаёт cwd как `/run/host/…`, это отвергает
pressure-vessel). Пользовательская справка — `helpws windows`.

Первая версия (один
Distrobox на каждое приложение, `~/.local/share/winapps`) заменена схемой
ниже.

## Цель

Windows-программы и игры живут в трёх managed Distrobox, а не на host и не в
development boxes. Каждая программа ставится либо в стандартный prefix
контейнера, либо в свой. Отдельный контейнер под одну программу схема
поддерживает, но сейчас такие контейнеры не создаются.

## 1. Контейнеры

Все три описаны в `distrobox/distrobox.nix` через профиль (`wine` или
`proton`): контейнер под одну программу позже — ещё одна запись с тем же
профилем, `wswin` не знает имён контейнеров.

```text
wine-wayland  Arch                 Wine из Arch, родной Wayland-драйвер;
                                   контейнер по умолчанию
wine          Ubuntu релиза host   Wine через XWayland: программы, которым
              (@HOST_VERSION_ID@)  Wayland-драйвер не подходит; WinBox
proton        Arch                 umu-launcher + Proton (UMU-/GE-Proton):
                                   игры и тяжёлое 3D (DXVK/VKD3D)
```

- `wine-wayland`: в реестре каждого prefix
  `HKCU\Software\Wine\Drivers Graphics=wayland`, поэтому драйвер не зависит
  от способа запуска (launcher, `wsbox enter`).
- `wine`: WineHQ stable (решения, ниже). Образ `ubuntu:26.04`
  заменяется на `@HOST_VERSION_ID@`, как у build-контейнеров; текущий `wine`
  пуст, пересоздание ничего не теряет.
- `proton`: multilib и 32-битные Vulkan-драйверы (`lib32-vulkan-radeon`,
  `lib32-vulkan-intel`) для DXVK; umu-launcher из [multilib].
  Proton и Steam Runtime umu скачивает в HOME контейнера.
- Хук `wsbox-host-ntsync` (NTSYNC-MODULE) есть в `wine-wayland` и `proton`
  и остаётся в `arch`: AUR-пакет, тянущий wine, не потянет ядро.
- `arch` остаётся коробкой для AUR без Wine: `winbox3` и export
  `arch/winbox3` убраны 2026-09-28 после проверки WinBox в `wine`.

## 2. GPU: AMD, если доступна

`proton` и Steam (flatpak) запускаются на AMD, если система загружена с ней
(rEFInd «Ubuntu (AMD)»), иначе — на Intel. Остальные контейнеры GPU не
выбирают (Intel по умолчанию).

`bin/ws-gpu`:

```text
ws-gpu status     какая GPU будет выбрана и почему
ws-gpu env        DRI_PRIME=pci-0000_03_00_0 или пусто
```

- AMD доступна, если на PCI есть видеоустройство с драйвером `amdgpu` и
  render node; не по одному `ws.dgpu=off` в cmdline (amdgpu может не
  подняться).
- `DRI_PRIME` передаётся явно только когда AMD есть: Mesa, не найдя
  указанную GPU, сама ушла бы на Intel, но предупреждение в логе вместо
  понятного выбора не нужно.
- `wsbox enter/run proton` и `wswin` для `proton` добавляют env на каждый
  запуск (`distrobox enter --additional-flags "--env …"`), а не при создании
  контейнера: одна и та же коробка работает в обеих загрузках.
- В `distrobox.nix` у контейнера признак `gpu = "amd"` (предпочтение, не
  требование); wsbox читает его из собранного файла рядом с
  `containers.ini`.

## 3. Prefixes

Внутри каждого контейнера:

```text
стандартный   $HOME/.wine             ~/distrobox/<box>/.wine
свой          $HOME/prefixes/<name>   ~/distrobox/<box>/prefixes/<name>
```

- Оба в HOME контейнера и переживают `wsbox recreate`.
- `wswin prefix … init` создаёт prefix и задаёт DPI (`LogPixels`, 192 =
  200%) и, в `wine-wayland`, драйвер Wayland. Настройки стандартного prefix
  общие для всех программ в нём.
- В `proton` тот же `WINEPREFIX` передаётся umu (`umu-run`).
- Пункты меню и ассоциации, которые создаёт сам Wine, остаются в HOME
  контейнера и в меню host не попадают.

## 4. Программы и launchers

Список программ — `windows/apps.nix`:

```text
name        ключ (launcher ws-win-<name>.desktop, wswin run <name>)
box         контейнер; по умолчанию wine-wayland
prefix      default | <имя своего prefix>; по умолчанию default
exe         путь внутри prefix (drive_c/…)
args, dpi   необязательно; title, icon — для launcher
```

`ws switch` собирает из него `~/.local/share/workstation/windows/apps.ini`
для `wswin` и launchers в `~/.local/share/applications/`.

## 5. wswin

```text
wswin list
wswin install [--box BOX] [--prefix NAME] SETUP.exe [ARGS]
wswin run APP [ARGS]
wswin exec [--box BOX] [--prefix NAME] PROGRAM.exe [ARGS]
wswin prefix [--box BOX] NAME init|winecfg|regedit|winetricks …|path|remove
wswin shell [--box BOX] [--prefix NAME]
```

- `install`: по умолчанию `--box wine-wayland` и стандартный prefix;
  `--prefix NAME` — свой prefix (создаётся, если нет).
- Для `proton` команды идут через `umu-run`, для остальных — через `wine`.
- После установки программа попадает в меню через запись в
  `windows/apps.nix` и `ws switch`.

## 6. Steam

- `com.valvesoftware.Steam` в `flatpak/flatpak.nix`; на host
  `steam-devices` (udev для контроллеров) в `apt.txt`.
- Launcher Steam заменяется своим `.desktop` (тот же id, поэтому и
  `steam://`): `ws-gpu run flatpak run …` — `DRI_PRIME`, если AMD доступна
  (flatpak передаёт его в sandbox).
- Proton в Steam — Valve Proton; GE-Proton только для конкретной
  совместимости, через `net.davidotek.pupgui2`.

## 7. Хранение

```text
~/distrobox/wine-wayland/{.wine,prefixes/}
~/distrobox/wine/{.wine,prefixes/}
~/distrobox/proton/{.wine,prefixes/,Games/}   umu, Proton, Steam Runtime — тоже здесь
~/.var/app/com.valvesoftware.Steam             библиотека Steam
```

Библиотеку игр можно позже вынести на отдельный filesystem, схема не
меняется.

## 8. Этапы

0. Проверить «Ubuntu (AMD)»: dGPU включена, `vulkaninfo`/offload, S3.
1. `ws-gpu`, признак `gpu` в `distrobox.nix`, env в `wsbox`.
2. Профили в `distrobox.nix`; пересоздать `wine`, создать `wine-wayland` и
   `proton`; хук NTSYNC в Arch-боксах.
3. `wswin`, `windows/apps.nix`, launchers.
4. WinBox → `wine`, свой prefix `winbox` (копия
   `~/distrobox/arch/.winbox/wine` с `LogPixels=192`; старый удаляется после
   проверки). Отдельно попробовать WinBox в `wine-wayland`. Убрать `winbox3`
   и export из `arch`.
5. `proton`: umu; проверить Steam Runtime (pressure-vessel, вложенные user
   namespaces) внутри rootless podman при ограничениях AppArmor Ubuntu 26.04
   — главный риск, запасной путь — Proton без runtime. Тестовая игра: DXVK
   HUD показывает AMD в «Ubuntu (AMD)» и Intel в «Ubuntu».
6. Steam flatpak, `steam-devices`, свой launcher; ProtonUp-Qt — только
   когда понадобится GE-Proton (не ставился).
7. Проверки в `ws check`; `helpws windows`; обновить `helpws plan-dev`,
   `helpws rebuild` (WinBox, arch).

## Решения

- Wine в контейнере `wine`: репозиторий WineHQ для релиза контейнера, stable
  (11.0; в Ubuntu 26.04 — 10.0 без NTSYNC). WineHQ не пакетирует Mono/Gecko:
  prefix создаётся с `WINEDLLOVERRIDES=mscoree,mshtml=` (без окна загрузки),
  нужные программе — через winetricks.

# DONE WHEN

- программа ставится `wswin install` в `wine-wayland` (стандартный prefix) и
  в свой prefix; запускается из меню GNOME;
- WinBox работает из `wine` со своим prefix и 200% scale; `arch` без Wine;
- prefix и контейнер удаляются без следов на host;
- Proton-игра запускается в `proton`: на AMD в «Ubuntu (AMD)», на Intel в
  «Ubuntu»;
- Steam запускается так же;
- Wine/Steam не загрязняют host и development boxes.
