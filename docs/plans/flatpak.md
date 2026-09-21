title: ws-plan-flatpak
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# PLAN — FLATPAK DESKTOP APPS

## Цель

Сделать Flatpak стандартным способом установки обычных сторонних GUI-приложений, сохраняя host чистым.

# 1. Базовая инфраструктура

Проверить/установить:

```bash
sudo apt install flatpak flatseal
```

Добавить Flathub для пользователя:

```bash
flatpak remote-add --user --if-not-exists \
  flathub https://flathub.org/repo/flathub.flatpakrepo
```

Проверить:

```bash
flatpak remotes --user
```

---

# 2. Правило размещения

```text
kernel / driver / GNOME / service → apt host
обычный GUI app                   → Flatpak
Ubuntu system app                 → deb/Snap как поставляет Ubuntu
development / SDK                 → Distrobox
Windows app                       → отдельный Wine environment
```

Не переносить системные компоненты GNOME в Flatpak.

---

# 3. Начальный набор GUI

Устанавливать приложения по одному, а не огромным batch.

Типичные категории:

- browser;
- graphics;
- communications;
- utilities;
- media.

Для каждого приложения проверить:

- Wayland;
- HiDPI;
- file chooser;
- clipboard;
- drag-and-drop;
- notifications;
- audio/video;
- hardware access, если нужен.

---

# 4. Permissions

Использовать Flatseal как GUI для просмотра permissions.

Принцип:

- не выдавать `filesystem=host` по умолчанию;
- давать доступ только к нужным каталогам;
- Projects/media folders добавлять точечно.

Пример:

```bash
flatpak override --user \
  --filesystem="$HOME/Projects/Graphics" \
  org.gimp.GIMP
```

---

# 5. Portals

Обязательно проверить с реальными Flatpak apps:

- open/save dialog;
- screenshots;
- screen sharing;
- notifications;
- URI links;
- default app handling.

При проблеме сначала проверять portals/runtimes, а не расширять filesystem permissions вслепую.

---

# 6. File associations / links

После установки основных apps проверить:

```bash
xdg-mime query default <mime-type>
```

и реальные сценарии:

- HTTP/HTTPS;
- mailto;
- magnet/torrent при необходимости;
- изображения;
- PDF;
- видео.

Цель — чтобы Flatpak не ломал обычный desktop workflow.

---

# 7. Maintenance

Регулярно:

```bash
flatpak update --user
flatpak uninstall --user --unused
flatpak list --app
```

Не использовать несколько независимых способов установки одной и той же GUI-программы без причины.

---

# DONE WHEN

- основные сторонние GUI apps работают через Flatpak;
- permissions минимальны и понятны;
- portals корректны;
- file associations работают;
- host не обрастает сторонними GUI repositories.
