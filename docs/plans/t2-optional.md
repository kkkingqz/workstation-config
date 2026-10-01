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

Не решено: держать ли Thunderbolt выключенным, пока в USB-C ничего нет
(без драйвера — нет Thunderbolt-устройств, USB 3 при подключении — см.
`71-tb-xhci-awake.rules`; S3 в таком состоянии не проверен), и что ещё
держит пакет в PC3.

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
