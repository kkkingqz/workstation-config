title: ws-roadmap
section: 1
date: 2026-09-28
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
- Intel UHD 630 как primary GPU; AMD dGPU выключена при загрузке (rEFInd «Ubuntu», `helpws workstation`), offload в «Ubuntu (AMD)»;
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
- Nix + home-manager поверх Ubuntu (`helpws history-nix`, тег `nix-v1`):
  `bootstrap.sh` → `ws switch` → `ws system apply` → `ws apply`, проверка —
  `ws check`; задачи после миграции — там же, «После миграции»;
- development/toolchains не должны расползаться по host;
- не использовать `powertop --auto-tune`, TLP, auto-cpufreq и агрессивный USB runtime PM для Touch Bar.

## Что осталось

1. `helpws plan-t2`
   Touch ID, fan policy, battery audit, optional hibernate/suspend-then-hibernate.

2. Фаза 6 — второе железо (`helpws history-nix`, «ФАЗА 6»)
   Решение пользователя: после плана virt. Первая машина — VM: чистая
   Ubuntu 26.04 на generic-ядре, весь путь по `helpws rebuild`. Шаги 1–4
   (репозиторий под второй хост, VM `wsvm`, прогон с исправлениями, повтор
   с `clean`) сделаны 2026-09-30…10-01. Повтор потребовал одну правку
   (`bootstrap.sh` ждёт блокировку dpkg); осталось: ещё один откат на
   `clean` без правок — строгое подтверждение критерия фазы.

3. `helpws plan-final`
   Инвентаризация, backups, snapshots, restore checkpoints и финальный
   smoke-test. Уже есть: `ws collect` (состояние машины для rebuild),
   `ws checkpoint` (коммит ↔ рабочее состояние), `ws baseline`.
   Обязательно: backup `@vms` (диски VM не входят ни в snapshots `@`, ни в
   `ws collect`).

Отложено:

- фикс t2bce через DKMS — только если сборка в podman станет неудобной;
  `build-essential` на host противоречит правилу про toolchains.

`01` можно выполнять отдельно: базовый suspend и Touch Bar уже работают,
поэтому Touch ID/hibernate/fan tuning не блокируют остальное.

## Завершённые слои

Как строились — `docs/history/` (`helpws history-…`), как работают —
`docs/runbooks/`:

```text
GNOME host layer        2026-09-23   history-gnome     gnome
Flatpak                 2026-09-24   history-flatpak   flatpak
Distrobox / Podman      2026-09-26   history-distrobox distrobox
Windows / Wine / Steam  2026-09-28   history-windows   windows
VM: KVM / libvirt       2026-09-29   history-virt      virt
Nix + home-manager      2026-09-28   history-nix       rebuild, workstation
```

## Главное правило

Каждая категория должна завершаться рабочим checkpoint (`ws checkpoint create NAME`). Если изменение затрагивает kernel, boot, GNOME extensions, power или T2 hardware — перед ним делается Btrfs snapshot.
