title: ws-plan-t2
section: 1
date: 2026-09-21
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

Инструменты:

```bash
BAT=$(upower -e | grep battery | head -1)
upower -i "$BAT"
cat /sys/power/mem_sleep
```

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

- не пытаемся любой ценой добиться runtime power-off AMD dGPU;
- не меняем работающий `deep/S3`;
- не трогаем runtime PM Touch Bar;
- не запускаем `powertop --auto-tune`;
- не ставим одновременно TLP/auto-cpufreq поверх штатного GNOME power stack.
