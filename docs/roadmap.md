title: ws-roadmap
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

# UBUNTU T2 WORKSTATION — ROADMAP

Этот набор продолжает уже реализованный baseline и **не повторяет** законченные работы.

## Зафиксированный baseline

Считаем уже готовыми и не перенастраиваем без отдельной причины:

- Ubuntu 26.04.1 LTS;
- GNOME 50 / Wayland / GDM3;
- rEFInd + T2 kernel `7.2.7-1-t2-resolute`;
- Btrfs root с `@`, `@home`, `@root`, `@srv`, `@cache`, `@tmp`, `@log`, `.snapshots`;
- Wi-Fi, Bluetooth, T2 audio, microphone, camera;
- Intel UHD 630 как primary GPU + AMD dGPU offload;
- рабочий `deep/S3` suspend/resume;
- suspend layer: deep-only, Broadcom guard, patched `t2bce` (`helpws suspend`); ASPM не форсируется;
- Touch Bar в родном режиме (`hid-appletb-kbd` + `ws-touchbar-fn`):
  - F1…F12 по умолчанию;
  - media/brightness при удержании Fn;
  - без `tiny-dfr`/`appletbdrm`: режим дисплея Touch Bar ломал suspend;
- финальный macOS-style keyboard layer:
  - EN/RU/UA;
  - CapsLock EN/RU и Fn+CapsLock -> UA;
  - GDM/login EN и GNOME lock screen EN;
  - Tiling Assistant, Tile Editing Mode, Always on Top и Smart Popup;
- development/toolchains не должны расползаться по host;
- не использовать `powertop --auto-tune`, TLP, auto-cpufreq и агрессивный USB runtime PM для Touch Bar.

## Что осталось

Работы разбиты по независимым категориям:

1. `helpws plan-t2`
   Touch ID, fan policy, battery audit, optional hibernate/suspend-then-hibernate.

2. `helpws plan-gnome` — **DONE**
   GNOME host layer завершён 2026-09-23: Retina scale, managed Yaru/Dock profile, host Qt5/Qt6 native Wayland integration, extension policy, portals/PipeWire, Dock Spring и полный smoke-test зафиксированы.

3. `helpws plan-flatpak` — **DONE**
   Flatpak application layer завершён 2026-09-24: user-only Flathub,
   managed-by-default `wsflatpak`, tracked filesystem/environment/D-Bus
   overrides, GTK/Qt6 integration, portals/PipeWire, associations,
   install/remove lifecycle и maintenance проверены.

4. `helpws plan-dev` — **DONE**
   Managed Distrobox/Podman layer завершён 2026-09-26: rootless Podman,
   declarative `containers.ini`/`exports.ini`, `wsbox`, custom HOME,
   WinBox export, destructive recovery и host NTSync provider проверены.

5. `helpws plan-windows`
   Per-app Wine environments, launchers, Steam/Proton, optional GE-Proton.

6. `helpws plan-virt`
   KVM/libvirt/virt-manager и user-managed Unreal Engine.

7. `helpws plan-final`
   Инвентаризация, backups, snapshots, restore checkpoints и финальный smoke-test.

## Рекомендуемый порядок

```text
06 KVM / Unreal
        ↓
05 Wine / Steam
        ↓
07 backup + final inventory

01 T2 optional
```

`01` можно выполнять отдельно: базовый suspend и Touch Bar уже работают, поэтому Touch ID/hibernate/fan tuning не должны блокировать остальную workstation.

## Главное правило

Каждая категория должна завершаться рабочим checkpoint. Если изменение затрагивает kernel, boot, GNOME extensions, power или T2 hardware — перед ним делается Btrfs snapshot.
