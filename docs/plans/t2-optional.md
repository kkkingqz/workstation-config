title: ws-plan-t2
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# PLAN — T2 OPTIONAL / POWER / AUTH

## Цель

Добавить только действительно полезные T2-функции, не ломая уже рабочие:

- `deep/S3`;
- Intel primary + AMD offload;
- штатный Touch Bar;
- Wi-Fi/Bluetooth/audio/camera.

Этот этап **не является обязательным** для завершения workstation.

# 1. Battery audit

Нужно получить реальную базовую цифру расхода:

- idle на батарее;
- suspend `deep/S3` на 30–60 минут;
- повторить несколько раз;
- сравнить процент и энергию до/после.

Инструмент — `ws-battery` (сам перезапускается через sudo: ключи SMC и
счётчики RAPL читает только root):

```console
ws-battery now [SECONDS]      мощность по линиям питания, среднее за SECONDS (10)
ws-battery devices [SECONDS]  каждое устройство выключить (или включить) на SECONDS: его мощность
ws-battery idle MINUTES       среднее за MINUTES, лог
ws-battery sleep              уснуть сейчас; после пробуждения — энергия за сон, пробуждения
```

Логи — `~/.local/state/workstation/battery/` (`idle-*.tsv`, `sleep.tsv`).

Откуда цифры (MacBookPro16,1, разведка 2026-10-01):

- SMC меряет мощность по линиям питания: `PSTR` — вся система, `PPBR` —
  батарея (совпадает с ток × напряжение `BAT0`), линии `PC0R` (CPU),
  `PM0C` (память), `PG0R` (AMD dGPU, при `ws.dgpu=off` ~0,09 W), `POLR`
  (на ней видно Wi-Fi и Bluetooth), `PO5R` (5 V, на ней подсветка
  клавиатуры), `PORR`, `PSLC`, `PH0R`, `PH1R` — назначение последних не
  установлено; `PHPC` — CPU на входе регулятора.
- RAPL делит пакет CPU: ядра, iGPU (`uncore`), память (`dram`).
- Подсветка экрана ни на одной линии: её и радио `ws-battery devices`
  меряет выключением на несколько секунд (разница `PSTR`, среднее до и
  после). Линии вместе считают на ~2 W больше, чем `PSTR` без подсветки,
  поэтому «rest» в `ws-battery now` — подсветка минус ~2 W (−2,1 W с
  выключенным экраном, 0 при 28 %, 5,4 W при 100 %). Какая линия
  пересекается с другими, не установлено; `PORR` с яркостью не меняется.

Замеры 2026-10-01 (на батарее, сеанс не в простое: GNOME и Claude,
PSTR 12,5 W при яркости 28 %), `ws-battery devices`:

```text
подсветка экрана 28 %       2,08 W    100 % — ещё +5,6 W (PSTR 18,5 W)
Wi-Fi (power save on)       1,21 W    POLR
подсветка клавиатуры 100 %  0,50 W    PO5R
Bluetooth (ничего не подключено) 0,21–0,34 W  POLR
подсветка Touch Bar         0,11 W
CPU (PC0R)                  4,4 W     RAPL: ядра 0,3, iGPU 0,2, пакет 3,2
```

Claude Desktop (окно на экране, свёрнуто, закрыто) на мощность не влияет:
14,68 / 14,75 / 14,80 W.

### Пакет CPU не глубже PC3 (2026-10-01)

Ядра в простое — C10, но пакет — только PC2/PC3 (`package_cstate_show`:
PC6–PC10 нулевые с загрузки; `ws-battery now` показывает долю каждого).
Из 3,1 W пакета ядра и iGPU — 0,5 W, остальное — пакет сам по себе.

- FADT: `the system doesn't support PCIe ASPM` — ядро ASPM не управляет,
  остаётся то, что включила прошивка: T2/NVMe (`00:1b.0`) — L1 + L1.1, Wi-Fi
  (`00:1c.0`) — L1 + L1.1 + L1.2; порты CPU для Thunderbolt (`00:01.1`,
  `00:01.2`) и всё дерево Titan Ridge — ASPM выключен.
- Thunderbolt не засыпает никогда: у корневых роутеров `0-0`/`1-0` runtime
  PM нет (`unsupported`), домен держит NHI (`08:00.0`, `7e:00.0`), NHI —
  мосты и порты CPU. `71-tb-xhci-awake.rules` тут ни при чём: xHCI,
  отпущенные в runtime suspend, мощность не меняют (14,64 → 14,58 W).
- Опыт `~/.cache/tb-idle-test3.sh` (драйвер `thunderbolt` отвязан от обоих
  NHI на минуту, xHCI — `auto`): всё дерево и порты CPU в D3hot, **PSTR
  14,70 → 13,28 W (−1,4 W)**, пакет RAPL 3,11 → 1,75 W. Пакет при этом всё
  равно PC3 — есть второй ограничитель.
- Экран: PSR панель не поддерживает (`i915_edp_psr_status: No such
  device`), DMC загружен, DC5 — 1 раз с загрузки, DC6 — 0. Без PSR при
  включённом экране PC8+ недостижимы.
- LTR: Wi-Fi (`SOUTHPORT_A`, `00:1c.0`) — 61 мкс, T2 (`SOUTHPORT_E`) — 2 мс.

Что ещё проверено (2026-10-01, `~/.cache/*-test.sh`, `ws-battery now` по
10 с на шаг, шаги накопительные):

```text
                                  обычная загрузка   pcie_aspm=force
экран включён (59 %)                  15,27 W           13,94 W
экран погашен (mutter, как GNOME)      8,36 W            6,11 W
+ Thunderbolt спит                     7,48 W            6,02 W
+ PCH xHCI/SRAM/LPC/SEP runtime PM     7,26 W            6,33 W
+ Wi-Fi выключен                       5,84 W            4,96 W
```

Пакет при этом везде PC2/PC3. Не держат PC6 (каждое проверено отдельно):
`pkg-cstate-limit` (MSR `0xE2` = 0x8: unlimited, не заперт), экран (при
погашенном DC5 работает), Thunderbolt, PCH xHCI, Wi-Fi, Bluetooth, LTR (с
`ltr_ignore` всех IP — то же), Link Disable на порту AMD `00:01.0`, обмен с T2
(при погашенном экране `bce_dma` — 0 прерываний/с). `pcie_aspm=force
pcie_aspm.policy=powersave` даёт L1 на Thunderbolt и L0s на Wi-Fi (−1,3 W
с экраном, −2,25 W без), но выключает L1.1/L1.2, которые прошивка включала
на T2 и Wi-Fi. Блоки PCH без power gating в простое: OPI-DMI, SPA, SPE,
LPSS (UART Bluetooth — и при выключенном Bluetooth), NPK (Trace Hub).

Причина PC3 — выключенная AMD. Загрузка без `ws.dgpu=off` с
`pcie_aspm=force` (весь путь `00:01.0 → 01:00.0 → 02:00.0 → 03:00.0` в
L1/L0s): пакет PC7 65–82 % времени. Так же было в переписке с ChatGPT (до
25.09: AMD на шине, forced ASPM, `powersave` → PC7 ~70 %). После
`ws-dgpu-off` (gmux снимает питание, пакет AMD убран с шины) порт
`00:01.0` остаётся без устройства, и пакет — только PC2/PC3; `Link
Disable` на порту не помогает.

Экран погашен, `ws-battery now` по 10 с (2026-10-01):

```text
                                       PSTR      CPU PC0R   AMD PG0R   пакет
AMD выключена, обычная загрузка        8,36 W    3,63 W     0,09 W     PC3
AMD выключена, force + powersave       6,0 W     2,3 W      0,09 W     PC3
AMD выключена, force + powersupersave  6,3 W     2,7 W      0,09 W     PC3
AMD на шине, force + powersave         9,75–10,0 W  2,2–2,8 W  3,2–3,7 W  PC7
AMD на шине, force + powersupersave    8,5–9,25 W   1,6–1,8 W  —          PC7
```

Разбор `powersave` (загрузка с `pcie_aspm=force`, политика меняется на ходу,
экран погашен; `~/.cache/aspm-ab-test.sh`):

```text
                                   PSTR    POLR    PORR    пакет RAPL
ASPM прошивки (policy default)     8,04 W  2,71 W  2,08 W  2,62 W
+ L1 на Thunderbolt (setpci)       6,89 W  2,53 W  1,91 W  1,35 W
+ L0s на Wi-Fi (setpci)            7,76 W  2,51 W  1,94 W  1,89 W   шум/хуже
policy powersave                   6,26 W  2,20 W  1,57 W  1,34 W
policy powersupersave              6,41 W  2,19 W  1,57 W  1,41 W
```

L1 на Thunderbolt — ~1,15 W (пакет CPU), остальные ~0,6 W `powersave` даёт
на `POLR`/`PORR` — вероятно, Clock PM (CLKREQ#), которую ядро включает
вместе с политикой; L0s на Wi-Fi сам по себе ничего не дал.
`powersupersave` ≈ `powersave`. С `pcie_aspm=force` и политикой `default`
переключатели `link/l1_aspm` L1 на Thunderbolt не включают (ядро держит
состояние прошивки).

PC7 экономит на CPU ~0,6–1 W, но AMD на шине стоит 3,2–4,7 W: выключенная
AMD выгоднее. Лучшее из проверенного — AMD выключена + `pcie_aspm=force
pcie_aspm.policy=powersave`: −2,3 W с погашенным экраном, −1,3 W с
включённым. PC7 при выключенной AMD дал бы ещё ~0,6–1 W, если порт
`00:01.0` уводить в сон правильно.

Решение пользователя (2026-10-01): `pcie_aspm=force
pcie_aspm.policy=powersave` — да; проверки сна (циклы `ws-battery sleep`)
и перенос в `facts.nix` — позже. Power Mode GNOME (power-profiles-daemon
0.30: EPP `intel_pstate`, `trickle_charge`) ASPM не трогает и работает
как раньше. Отключать Thunderbolt без устройств не нужно: L1 на его
линках даёт тот же выигрыш.

Дальше: выключать AMD так, чтобы порт `00:01.0` не держал пакет в PC3.

Выключение AMD (2026-10-01). У `PEG0` нет power resources; выключать умеет
SSDT Apple `PEG0GFX0`: `\_SB.PCI0.PEG0.EGP0.EGP1.GFX0.PWRD(1)` →
`PUPD(0)`: линк в Gen1, LTR порта выкл., запрос L2 (`Q0L2`, 0x248 бит 7)
и только после L2 — PHY порта выкл. (`RC20` 0xC20[5:4]=3, `RC38` 0xC38
бит 3, `BND0..3` бит 31 0x91C/0x93C/0x95C/0x97C); питание снимает gmux
(порт `0x50`: 1, затем 0; `MBWR` в ACPI — тот же mailbox gmux). Так
делает macOS (AppleMuxControl2) и t2gmux проекта KaiT2en (замена
`apple_gmux`, для MacBookPro16,1/16,4 — `PWRD`; включение — `PWRD(0)`,
карта возвращается без перезагрузки): github.com/kaiT2en/KaiT2en-Fedora
`modules/t2gmux`, серия в ядро v3 — 2026-08-12. `ws-dgpu-off`
(switcheroo OFF → `apple-gmux` пишет только 1, 0) этого не делает.

Опыты (`~/.cache/amd-l2-test.sh`, `peg-*-test.sh`, `amd-park-test.sh`):
карта под питанием без драйвера (`modprobe.blacklist=amdgpu`, 9,6 W!),
D3hot, затем `Q0L2` → пакет PC7 83 %, пакет RAPL 2,8 → 0,9 W. После
снятия питания без этой последовательности порт в «нет устройства», PC3;
`Link Disable`, PHY или `Q0L2` на порту без карты не помогают. Повторный
«паркинг» в той же загрузке не работает: порт остаётся в L2-состоянии
(`LTSS` 0x165) и не тренируется. Обращения ядра к карте за линком в L2
вешают машину — карту сначала убирать из PCI. Отладочный интерфейс
apple-gmux: `/sys/kernel/debug/apple_gmux/selected_port{,_data}`.

**Работает (2026-10-01, `amd-park-test.sh`, свежая загрузка с `ws.dgpu=off`
и forced ASPM, от сети, экран погашен):** после `ws-dgpu-off` — питание
карты через gmux (`0x50` ← 1, 3), линк поднялся (`LTSS` 0x1e0 → 0x1e3),
Gen1, LTR выкл., `Q0L2` сбросился за 20 мс (`LTSS` 0x165), PHY выкл.,
`0x50` ← 1, 10 мс, 0. Пакет PC3 → **PC7 82 %**, PSTR 8,74 → 7,97 W, CPU
`PC0R` 3,43 → 2,52 W, пакет RAPL 2,09 → 1,05 W; switcheroo по-прежнему
`DIS Off`. Не проверено: состояние порта после S3 и повтор после пробуждения.

Не применять автоматические Powertop tweaks. Использовать Powertop только как инструмент наблюдения.

### Готово, если

- понятен реальный расход в idle;
- понятен расход в `deep/S3`;
- нет неожиданного wake source;
- текущий режим признан достаточным либо есть конкретная измеримая проблема.

---

# 2. Fan policy

Сначала оставить штатное управление.

Проверить:

```bash
sensors
```

и поведение вентиляторов:

- idle;
- браузер/video;
- CPU load;
- AMD offload load.

`t2fanrd` ставить только если штатное поведение реально неудовлетворительно.

### Если нужен t2fanrd

1. Сделать snapshot.
2. Установить daemon.
3. Сначала использовать консервативную кривую.
4. Проверить температуры и sleep/resume.
5. Не держать два fan controller одновременно.

### Готово, если

Либо штатное управление признано нормальным, либо `t2fanrd` даёт предсказуемое улучшение без побочных эффектов.

---

# 3. Touch ID

Touch ID — отдельная optional feature.

План:

1. Сохранить парольный login/PAM как обязательный fallback.
2. Проверить актуальную поддержку `t2-touchid`.
3. Сделать snapshot.
4. Установить и настроить только после проверки текущей документации T2Linux.
5. Проверить:
   - login;
   - `sudo`;
   - lock/unlock;
   - поведение после reboot;
   - поведение после suspend/resume.

Учитывать, что T2 Touch ID может зависеть от состояния Secure Enclave/macOS после некоторых hard power-off/kernel failure сценариев.

### Готово, если

Touch ID является удобным дополнительным методом, но пароль всегда остаётся рабочим.

---

# 4. Hibernate — только если нужен

Сейчас `deep/S3` уже работает, поэтому hibernate не нужен для исправления suspend.

Перед настройкой решить, есть ли практическая цель:

- очень долгий сон;
- сохранение батареи на сутки/несколько суток;
- suspend-then-hibernate.

План:

1. Проверить swap:
   ```bash
   swapon --show
   ```
2. Убедиться, что swap достаточен для hibernate.
3. Настроить resume.
4. Выполнить минимум 3–5 ручных циклов:
   ```bash
   systemctl hibernate
   ```
5. Каждый раз проверить graphics, T2 audio, Wi-Fi, Bluetooth, Touch Bar.

### Stop condition

При нестабильном resume не автоматизировать hibernate.

---

# 5. Suspend-then-hibernate

Только после полностью стабильного ручного hibernate.

Пример целевой политики:

```ini
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateDelaySec=30min
```

Сначала тестировать вручную:

```bash
systemctl suspend-then-hibernate
```

Только потом связывать с обычной desktop policy.

---

## Что специально не делаем

- не пытаемся добиться runtime PM AMD dGPU (его нет); AMD выключается только при загрузке, пунктом rEFInd «Ubuntu» (`helpws workstation`, GRAPHICS);
- не меняем работающий `deep/S3`;
- не трогаем runtime PM Touch Bar;
- не запускаем `powertop --auto-tune`;
- не ставим одновременно TLP/auto-cpufreq поверх штатного GNOME power stack.
