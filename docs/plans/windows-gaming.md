title: ws-plan-windows
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# PLAN — WINDOWS APPS / WINE / STEAM / PROTON

## Цель

Разделить Windows desktop apps и gaming, не превращая host в общий Wine prefix.

## A. Windows desktop applications

### 1. Правило

```text
одно Windows desktop app
        ↓
отдельный Distrobox
        ↓
отдельный HOME
        ↓
отдельный Wine prefix/state
```

Это даёт понятное удаление и разные версии/configs для разных приложений.

### 2. Шаблон environment

```bash
mkdir -p ~/.local/share/winapps/foo/home

distrobox create \
  --name win-foo \
  --image docker.io/library/ubuntu:26.04 \
  --home "$HOME/.local/share/winapps/foo/home"
```

Внутри:

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install wine wine64 wine32:i386 winetricks cabextract
wineboot
winecfg
```

### 3. Scaling

DPI задавать per-prefix, а не глобально для GNOME.

Пример 150%:

```bash
wine reg add 'HKCU\Control Panel\Desktop' \
  /v LogPixels /t REG_DWORD /d 144 /f
```

### 4. Host launcher

Для каждого приложения сделать отдельный launcher в `~/.local/bin` и `.desktop` entry.

### 5. Wayland

Сначала использовать рабочий Wine/XWayland путь.

Native Wine Wayland тестировать отдельно per-app; не мигрировать working prefix только ради архитектурной чистоты.

---

## B. Steam / gaming

### 1. Steam

Предпочтительный desktop-layer вариант:

```bash
flatpak install --user flathub com.valvesoftware.Steam
sudo apt install steam-devices
```

### 2. Proton

Сначала:

```text
Valve Proton
```

GE-Proton добавлять только для конкретной совместимости.

При необходимости:

```bash
flatpak install --user flathub net.davidotek.pupgui2
```

### 3. GPU

Игры/тяжёлые 3D приложения — основной кандидат для AMD offload.

Для каждой игры проверить:

- какой GPU реально используется;
- Vulkan;
- fullscreen;
- frame pacing;
- suspend/resume после выхода из игры.

---

## C. Storage

Разнести данные логически:

```text
~/Games
~/.local/share/winapps/<app>
```

Game library при необходимости можно вынести на отдельный filesystem/storage позже, не меняя Wine architecture.

---

# DONE WHEN

- хотя бы один Windows desktop app работает в отдельном box;
- его можно удалить вместе с HOME/prefix;
- Steam запускается;
- Proton game запускается;
- AMD offload реально используется там, где требуется;
- Wine/Steam не загрязняют development box.
