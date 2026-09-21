title: ws-plan-final
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# PLAN — BACKUP / INVENTORY / FINALIZATION

## Цель

После завершения application layer превратить workstation из «настроенной системы» в воспроизводимую и восстанавливаемую.

# 1. System inventory

Создать:

```bash
mkdir -p ~/system-state

apt-mark showmanual | sort \
  > ~/system-state/apt-manual-final.txt

snap list \
  > ~/system-state/snap-final.txt

flatpak list --app --columns=application \
  > ~/system-state/flatpak-apps.txt

distrobox list \
  > ~/system-state/distroboxes.txt

podman images \
  > ~/system-state/podman-images.txt

gnome-extensions list --enabled \
  > ~/system-state/gnome-extensions-final.txt
```

Дополнительно сохранить:

```text
uname -r
/proc/cmdline
/etc/modprobe.d/tb.conf
rEFInd relevant config
```

---

# 2. Что backup'ить отдельно от Btrfs snapshots

Snapshots root не являются backup.

Отдельно сохранять:

```text
~/Projects
~/VMs
~/Games / saves
Wine HOME/prefixes
important ~/.var/app
~/.config — выборочно
~/.local/bin
~/.local/share/applications
~/system-state
T2-specific config files
```

Не backup'ить автоматически огромные caches/runtimes, если они восстанавливаются установкой.

---

# 3. Snapshot policy

Snapshot делать перед:

- kernel/T2 changes;
- boot/rEFInd changes;
- GNOME extensions;
- power/sleep changes;
- large application infrastructure changes;
- virtualization config changes.

Не создавать snapshot перед каждым обычным Flatpak update.

---

# 4. Restore test

Хотя бы один раз проверить реальный сценарий:

1. создать snapshot;
2. внести безопасное тестовое изменение;
3. убедиться, что snapshot виден;
4. выполнить документированный rollback;
5. убедиться, что root возвращён корректно.

Отдельно помнить: rollback root не восстанавливает внешний backup HOME/VM/projects.

---

# 5. Финальный smoke-test

### Desktop

- GNOME login;
- Overview;
- Ubuntu Dock;
- Quick Settings;
- Settings;
- Nautilus;
- notifications;
- lock/unlock.

### Hardware

- keyboard/trackpad;
- F1–F12 Touch Bar;
- Fn media;
- Touch Bar autodim/off;
- Wi-Fi;
- Bluetooth;
- audio/mic;
- camera;
- Intel desktop;
- AMD offload.

### Power

- `deep/S3`;
- resume;
- lid behavior;
- battery status.

### App layer

- Flatpak file chooser;
- Flatpak screen sharing;
- dev Distrobox;
- Python/uv;
- IDE export;
- Wine app;
- Steam/Proton;
- virt-manager.

Optional features проверяются только если были реально включены:

- Touch ID;
- t2fanrd;
- hibernate;
- suspend-then-hibernate.

---

# 6. Maintenance routine

### Ubuntu

```bash
sudo apt update
sudo apt full-upgrade
```

После T2 kernel update отдельно проверить:

- boot;
- graphics;
- audio;
- Touch Bar;
- suspend/resume.

### Flatpak

```bash
flatpak update --user
flatpak uninstall --user --unused
```

### Distrobox / Podman

```bash
distrobox-upgrade --all
podman images
podman ps -a
```

Не запускать destructive prune автоматически без просмотра данных.

---

# DONE WHEN

Система считается завершённой как workstation, когда:

- весь используемый software имеет понятный installation boundary;
- host inventory сохранён;
- user data backup определён;
- Btrfs rollback документирован и проверен;
- final smoke-test проходит;
- восстановление не зависит от памяти о старых чатах.
