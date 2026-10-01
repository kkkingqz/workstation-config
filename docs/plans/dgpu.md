title: ws-plan-dgpu
section: 1
date: 2026-10-01
source: Workstation
volume: User Commands

# PLAN — AMD dGPU ЧЕРЕЗ T2GMUX

## Цель

Выключать AMD (Navi 14) так же, как macOS, чтобы с выключенной картой пакет
CPU уходил в PC7, и включать её обратно без перезагрузки: offload
(`DRI_PRIME`) и внешние мониторы без пункта rEFInd «Ubuntu (AMD)».

Решение пользователя (2026-10-01): заменить `apple-gmux` на t2gmux проекта
KaiT2en (вариант «Б»), а не дописывать свой шаг в `ws-dgpu-off`.

## Почему

Разбор — `helpws plan-t2`, раздел 1. Коротко:

- `ws-dgpu-off` сейчас: switcheroo OFF (`apple-gmux` пишет в порт gmux
  `0x50` 1, затем 0) и удаление карты с шины PCI. Порт CPU `00:01.0`
  остаётся «без устройства», и пакет не уходит глубже PC3.
- macOS (AppleMuxControl2) перед снятием питания вызывает ACPI
  `\_SB.PCI0.PEG0.EGP0.EGP1.GFX0.PWRD(1)` (SSDT `PEG0GFX0`): линк в Gen1,
  L2, выключение PHY порта. Вручную повторено (`~/.cache/amd-park-test.sh`):
  с выключенной AMD пакет PC7 82 %, CPU −0,9 W.
- `apple-gmux` не умеет включать карту обратно (switcheroo ON → «PSP create
  ring failed», helpws suspend), поэтому карта убирается с шины и S3 с ней
  невозможен (MODE1 reset `amdgpu` в suspend_noirq).
- t2gmux (github.com/kaiT2en/KaiT2en-Fedora, `modules/t2gmux`, GPL-2.0, автор
  t2bce) для MacBookPro16,1/16,4 выключает через `PWRD(1)`, включает через
  `PWRD(0)` с восстановлением конфигурации карты и мостов; серия в ядро —
  v3, 2026-08-12. KaiT2en усыпляет машину так: перед сном switcheroo ON
  (`amdgpu` засыпает штатно), после пробуждения OFF.

## Шаги

1. **Сборка.** `ws-gmux build`: исходник t2gmux по закреплённому коммиту
   KaiT2en (`system/kernel/t2gmux/t2gmux.nix`), сборка в podman с
   заголовками ядра, как t2bce. Ничего не ставит. Пробная сборка коммита
   `398dd080` под `7.2.7-1-t2-resolute` прошла (2026-10-01).
2. **Загрузочная видеокарта.** EFI `gpu-power-prefs-fa4ce28d-…` сейчас
   `07 00 00 00 00 …` (AMD); панель на Intel переключает `force_igd=y`
   `apple-gmux`. У t2gmux такого параметра нет: прошивка должна сама
   отдавать панель Intel — переменная `07 00 00 00 01 00 00 00` (как
   `t2-dgpu-control` KaiT2en). Иначе 16,1 виснет при старте сеанса
   (omarchy#9609). Обычная загрузка с `apple-gmux` от этого не меняется.
3. **Установка без переключения.** t2gmux в
   `/lib/modules/KERNEL/updates/t2gmux`; по умолчанию по-прежнему
   `apple-gmux`. Оба модуля отвечают на `pnp:dAPP000B`, поэтому выбор —
   явный: t2gmux занесён в blacklist (по alias не грузится), тестовая
   загрузка — параметрами ядра (шаг 4).
4. **Тестовая загрузка с t2gmux** (параметры в rEFInd вручную):
   - switcheroo OFF без удаления с шины → PC7, `PG0R` ~0;
   - ON → `amdgpu` жив, `DRI_PRIME` работает; снова OFF;
   - сон по схеме KaiT2en (ON перед сном, OFF после), несколько циклов;
   - внешний монитор через Thunderbolt (если есть под рукой).
5. **Переход.** t2gmux по умолчанию (`apple-gmux` в blacklist),
   `ws-dgpu-off` — только switcheroo OFF, хук сна ON/OFF, решение о пункте
   «Ubuntu (AMD)», проверки (`ws-workstation-verify`, `ws-suspend check`),
   документация (`helpws suspend`, `helpws workstation`).
6. **Обновление ядра.** Пересборка t2gmux вместе с t2bce; `ws check`
   сообщает, если модуль не собран под текущее ядро.

## Риски и откат

- t2gmux развивается быстро (коммиты 2026-09-28 … 10-01): версию закрепляем
  коммитом, обновляем осознанно.
- Новая схема сна (карта включена во время S3) у нас не проверена; в истории
  (до 25.09) 16 циклов S3 с AMD на шине и родным Touch Bar прошли без сбоев.
- Без gmux-драйвера пропадает яркость экрана (`gmux_backlight`) и
  переключение панели. Откат до шага 5 — обычная загрузка (`apple-gmux`);
  после шага 5 — `ws-gmux rollback` и blacklist обратно.
- Обращения ядра к карте, когда линк в L2, вешают машину (опыты plan-t2):
  карту не трогать в обход t2gmux.
