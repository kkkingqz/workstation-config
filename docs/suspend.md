title: ws-suspend
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

# UBUNTU T2 SUSPEND — CURRENT BASELINE

## Текущее состояние

```text
MacBookPro16,1
T2 kernel 7.2.7-1-t2-resolute
sleep        deep / S3 only
cmdline      intel_iommu=on iommu=pt pm_async=off   (без pcie_aspm=force)
t2bce        0.07-nostatefix1 (локальная сборка, updates/t2bce)
Touch Bar    родной режим (см. helpws touchbar)
```

Слой состоит из трёх частей:

```text
deep-only sleep        systemd никогда не откатывается на s2idle
Broadcom Wi-Fi guards  ASPM off на время сна, без D3cold
t2bce fix              no-state fallback не роняет ядро
```

Всё управляется командой `ws-suspend`:

```console
ws-suspend status
ws-suspend apply
ws-suspend t2bce-build [KERNEL]
ws-suspend t2bce-install [KERNEL]
ws-suspend t2bce-rollback [KERNEL]
```

## Deep-only sleep

```text
/etc/systemd/sleep.conf.d/80-deep-only.conf
  SuspendState=mem
  MemorySleepMode=deep
```

По умолчанию systemd после неудачного S3 пробует `freeze` (s2idle). На T2
s2idle виснет. 2026-09-25 12:00 так и было: brcmfmac не ушёл в D3, S3
прервался, systemd сразу перешёл в s2idle, система зависла. С этим файлом
неудачный suspend просто возвращает в рабочую сессию.

## Broadcom BCM4364

```text
/usr/lib/systemd/system-sleep/80-broadcom-aspm       hook systemd-sleep
/usr/local/sbin/broadcom-aspm-suspend-guard          disable / restore
/etc/systemd/system/broadcom-aspm-restore.service    restore после resume
/etc/udev/rules.d/70-bcm4364-no-d3cold.rules         d3cold_allowed=0
```

Перед сном guard сохраняет ASPM-биты Wi-Fi (`05:00.0`) и root port
(`00:1c.0`) и выключает ASPM; после resume `broadcom-aspm-restore.service`
ждёт стабильный `brcmfmac` и возвращает L1. Цель — избежать
`brcmf_pcie_pm_enter_D3: Timeout on response for entering D3 substate`.
После установки guard таймаутов D3 не было.

Hook лежит в `/usr/lib/systemd/system-sleep/`, потому что systemd-sleep
читает hooks оттуда.

## ASPM

`pcie_aspm=force pcie_aspm.policy=powersave` убраны из
`/boot/refind_linux.conf` 2026-09-25. Все три отказа T2 (ниже) случились при
forced ASPM и Touch Bar в режиме дисплея; без него отказов не было.
`ws-workstation-verify` предупреждает, если параметры вернутся.

## t2bce: отказ stateful suspend

Иногда bridgeOS отвечает на запрос сохранения состояния отказом:

```text
t2bce_core: remote rejected stateful suspend payload
```

Штатный `t2bce` 0.07 после этого уходит в no-state fallback: удаляет VHCI,
пока очереди событий и mailbox уже на паузе, поэтому команды разборки не
получают ответа (`Possible desync`, `command queue timeout`,
`SQ/CQ unregister failed`). После resume `CQ registration failed`, и IRQ-поток
`bce_dma` падает с NULL dereference в `t2bce_dma_reserve_submission`.
Система намертво зависает. Так закончились все три отказа
(2026-09-22 19:25, 09-23 17:31, 09-24 14:11).

Upstream:

```text
t2linux/T2-Debian-and-Ubuntu-Kernel#215   отчёт (автор t2bce: fallback будет удалён)
deqrocks/t2bce#9                          черновик исправления fallback
```

### Локальный патч

```text
kernel/t2bce/nostate-fix.patch   патч к drivers/staging/t2bce из linux-t2-patches 1001
kernel/t2bce/sources.conf        версия ядра -> коммит linux-t2-patches
```

Патч:

1. переносит оставшуюся часть deqrocks/t2bce#9: транспорт и очереди событий
   VHCI открываются на время no-state teardown, ошибки прерывают suspend;
2. добавляет проверку NULL в `t2bce_core_reserve_submission()`;
3. делает `t2bce_core.stateful_sleep` параметром модуля (по умолчанию `Y`),
   чтобы no-state путь можно было проверить по команде;
4. помечает версии `0.07-nostatefix1` / `0.02-nostatefix1`.

Пересобираются все пять модулей `t2bce_*`, чтобы совпадали версии символов.
Сборка идёт в одноразовом контейнере podman (`ubuntu:26.04`) с заголовками
`/usr/src/linux-headers-KERNEL`; результат — `~/.cache/ws-suspend/t2bce/KERNEL/`.
Модули ставятся в `/lib/modules/KERNEL/updates/t2bce`: depmod ищет в
`updates` раньше, чем в `kernel`. Пакеты ядра не меняются.

### Проверка no-state пути

Сохранить работу, затем:

```console
echo N | sudo tee /sys/module/t2bce_core/parameters/stateful_sleep
systemctl suspend
```

После выхода из сна клавиатура, трекпад и Touch Bar появляются через пару
секунд. В `journalctl -b -k` должны быть `no_state_fallback=1` и
`path=no-state` и не должно быть `desync`, `queue timeout`, `BUG`/`Oops`.
Затем обязательно вернуть:

```console
echo Y | sudo tee /sys/module/t2bce_core/parameters/stateful_sleep
```

Проверено 2026-09-25: no-state цикл прошёл чисто.

## Обновление ядра

`linux-t2` не заморожен. Модули в `updates/` привязаны к одной версии ядра,
поэтому новое ядро загрузит штатный `t2bce`. `ws-workstation-verify`
предупредит об этом. Порядок:

1. Проверить, вошло ли исправление в upstream (#215, deqrocks/t2bce#9,
   `linux-t2-patches`). Если да — локальный патч больше не нужен.
2. Если нет — найти коммит `linux-t2-patches`, из которого собрано новое
   ядро, и добавить строку в `kernel/t2bce/sources.conf`.
3. Собрать и поставить:

```console
ws-suspend t2bce-build NEW_KERNEL
ws-suspend t2bce-install NEW_KERNEL
```

Если патч не накладывается на новую версию `t2bce`, его нужно перенести
вручную. Предыдущее ядро с исправленными модулями остаётся в rEFInd.

## Откат

```console
ws-suspend t2bce-rollback
sudo reboot
```

## Проверка

```console
ws-suspend status
ws-workstation-verify --strict
```

Ожидается:

```text
mem_sleep                 s2idle [deep]
cmdline                   без pcie_aspm
t2bce_core                0.07-nostatefix1, stateful_sleep=Y
runtime files             OK
```

## Подтверждённый baseline

2026-09-25/26:

```text
stateful S3 cycle                          OK
forced no-state cycle                      OK
Touch Bar native mode S3 cycles            OK
модули из репозитория == установленные      srcversion совпадает
```

## Source of truth

```text
bin/ws-suspend
kernel/t2bce/nostate-fix.patch
kernel/t2bce/sources.conf
system/sleep.conf.d/80-deep-only.conf
system/udev/70-bcm4364-no-d3cold.rules
system/usr/local/sbin/broadcom-aspm-suspend-guard
system/usr/lib/systemd/system-sleep/80-broadcom-aspm
system/systemd/system/broadcom-aspm-restore.service
```

## Не использовать

```text
выгрузку t2bce/apple-bce перед сном (t2linux wiki: never unload t2bce)
T2Linux-Suspend-Fix / t2-suspend.service / t2-resume.service
s2idle
pcie_aspm=force, pcie_ports=compat, i915.enable_guc=3
Touch Bar display mode (appletbdrm, tiny-dfr) вместе с suspend
```
