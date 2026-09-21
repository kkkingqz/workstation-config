title: ws-plan-gnome
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# PLAN — GNOME VISUAL / INPUT / PORTALS

## Цель

Завершить desktop layer, оставаясь максимально близко к штатному Ubuntu GNOME.

Уже работают GNOME 50, Wayland, GDM3, Ubuntu Dock, Quick Settings, Nautilus и системные OSD. Этот план — не замена desktop environment, а финальная интеграция.

# 1. Appearance baseline

Через `Settings → Appearance` зафиксировать:

- Dark/Light;
- accent;
- Dock position;
- autohide;
- icon size;
- wallpaper.

Не использовать:

- custom GNOME Shell CSS;
- theme forks;
- замену Ubuntu Dock;
- отдельные notification/OSD daemons.

### Результат

Один штатный visual profile, который переживает GNOME updates.

---

# 2. Retina scaling

На встроенной 3072×1920 панели проверить:

- 200%;
- при необходимости 175%/150%.

Настраивать только через `Settings → Displays`.

Не использовать:

- `xrandr` scale hacks;
- глобальный `Xft.dpi`;
- ручные Mutter experimental flags без необходимости.

### Проверка

- GNOME Shell;
- Nautilus;
- Firefox;
- GTK3;
- GTK4/libadwaita;
- Qt;
- XWayland application.

---

# 3. Qt5/Qt6 integration

Если Qt apps выглядят заметно чужеродно, добавить штатную GNOME integration:

```bash
sudo apt install \
  qgnomeplatform-qt5 qgnomeplatform-qt6 \
  adwaita-qt adwaita-qt6
```

После logout/login проверить palette, fonts и file dialogs.

Не задавать глобально `QT_STYLE_OVERRIDE=kvantum`, если нет конкретной причины.

---

# 4. GNOME Tweaks — только при необходимости

Можно установить:

```bash
sudo apt install gnome-tweaks
```

Использовать только для:

- fonts;
- window behavior;
- startup applications;
- обычных GSettings options.

Не использовать Tweaks как повод поставить много Shell extensions.

---

# 5. Extensions policy

Текущий известный non-default extension:

```text
Window Monitor Pro
```

Его оставить.

Новые extensions добавлять по одному:

1. snapshot;
2. установить extension;
3. logout/login или reload session;
4. проверить Overview, Dock, Quick Settings и idle responsiveness;
5. оставить только если функция действительно нужна.

---

# 6. Keyboard / shortcuts

Через `Settings → Keyboard → Keyboard Shortcuts` настроить только реальные пользовательские shortcuts.

Возможные кандидаты:

- terminal;
- screenshot;
- lock;
- workspace navigation;
- application launcher.

Не дублировать shortcuts через `xdotool`/`xbindkeys`, пока GNOME умеет сделать это штатно.

Touch Bar здесь не менять: текущий F1–F12 + Fn media baseline уже готов.

---

# 7. Toolkit smoke-test

Проверить матрицу:

```text
GTK4/libadwaita  → Settings / Files / system apps
GTK3             → pavucontrol или другая GTK3 utility
Qt5/Qt6          → выбранное Qt app
Flatpak          → после плана 03
XWayland         → legacy test app
```

Отдельно проверить:

- file chooser;
- clipboard;
- drag-and-drop;
- HiDPI;
- dark preference.

---

# 8. Portals / screen sharing

После появления основных Flatpak apps проверить:

- screenshot portal;
- file chooser portal;
- browser screen sharing;
- PipeWire screen capture.

Не создавать собственный `portals.conf`, пока нет доказанной проблемы.

---

# DONE WHEN

Этап завершён, когда:

- GNOME выглядит цельно без Shell hacks;
- Retina scale выбран;
- GTK/Qt/XWayland apps имеют приемлемый DPI;
- Overview/Dock/Quick Settings не тормозят;
- screen sharing и portal dialogs работают;
- список extensions короткий и осознанный.
