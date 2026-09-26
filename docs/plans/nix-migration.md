title: ws-plan-nix
section: 1
date: 2026-09-26
source: Workstation
volume: User Commands

# PLAN — NIX + HOME-MANAGER (UBUNTU ОСТАЁТСЯ)

**Версия 3, 2026-09-26.** Сверена с репозиторием на `0b50385` (managed
Flatpak, Distrobox, suspend/T2 layer) и с живой системой. Главное отличие от
версии 2: Nix только доставляет, владельцы слоёв не меняются.

## Цель

Одна flake-конфигурация в этом репозитории поднимает все workstation.
Ubuntu остаётся основой системы. Nix ставит CLI, раскладывает ссылки на
checkout, закрепляет бинарники и собирает системные файлы для каждого хоста.
Различия железа описаны в `hosts/<name>/facts.nix`.

## Принцип: Nix доставляет, владельцы не меняются

Каждый слой уже имеет инструмент-владельца с `apply` и `check`. Миграция их
не заменяет:

```text
Слой                     Владелец (остаётся)                   Что делает Nix
Терминал                 config/fish, config/ghostty           ссылки, CLI-пакеты
Команды ws-*             bin/                                  ссылки в ~/.local/bin
Внешний вид GNOME        ws-gnome + config/gnome/settings.conf ссылка на команду
Flatpak                  wsflatpak + config/flatpak/           ссылка на команду
Distrobox                wsbox + config/distrobox/             ссылка на команду
Клавиатура               ws-keyboard*, ws-tiling-apply,        бинарник xremap
                         ws-keyboard-install-extensions
Suspend / t2bce          ws-suspend status|t2bce-*             —
Системные файлы          system/ (источник)                    сборка дерева хоста,
                                                               ws system diff|check|apply
Проверка                 ws-workstation-verify                 —
```

Замена владельцев модулями home-manager (dconf, nix-flatpak, systemd-модули,
DKMS) — не часть миграции. Это отдельные задачи после неё, см. «После
миграции».

## Критерии завершения

- Новая машина поднимается так: Ubuntu (для Mac — T2-репозиторий и rEFInd)
  → `bootstrap.sh` → `ws switch` → `ws system apply` → `ws apply` →
  logout/login → `ws apply`. После этого `ws check` зелёный.
- `ws system diff` пуст: системные файлы совпадают со сборкой байт в байт.
- На текущей машине `ws baseline diff pre-nix now` не показывает регрессий.
- Recovery через GRUB проверен на каждой машине.
- CI собирает конфигурации всех хостов.

---

# КЛЮЧЕВЫЕ РЕШЕНИЯ

```text
Nix              официальный multi-user installer, flakes в /etc/nix/nix.conf
/nix             отдельный subvolume @nix: откат @ и recovery не ломают
                 ссылки пользовательского слоя в /nix/store
Каналы           nixos-26.05 + home-manager release-26.05, версии в flake.lock
Пользователь     home-manager standalone: homeConfigurations."<user>@<host>"
bin/             ссылки на checkout через mkOutOfStoreSymlink; shebang и код
                 скриптов не меняются (Python-хелперам нужен python3-gi из apt)
Система          Nix собирает дерево файлов хоста из system/; ws system
                 раскладывает копии с бэкапом и выполняет те же действия после
                 установки, что сейчас делают apply-скрипты
ESP              rEFInd и GRUB EFI: только захват и check
Остаётся в apt   ядро и T2, rEFInd, GRUB, dracut, GDM, GNOME Shell, fish,
                 ghostty, python3-gi, podman, distrobox, flatpak, glib/dconf
Из Nix           fzf, zoxide, eza, lowdown, micro, nvd; бинарник xremap
Фикс t2bce       как сейчас: ws-suspend, podman-сборка, kernel/t2bce/
```

Почему не system-manager: он работает только с `/etc` и systemd, а здесь
файлы лежат ещё и в `/boot`, `/usr/lib/systemd/system-sleep` и `/usr/local`;
кроме того, он ставит ссылки в `/nix/store`, а modprobe-файлы читаются из
initramfs.

Почему `gsettings`, `gdbus`, `busctl`, `python3` берутся с хоста: версии из
Nix не видят схем GSettings хоста и PyGObject/Atspi из apt. Скрипты не
упаковываются через `writeShellApplication` и не проходят `patchShebangs`.

## Формат конфигов: только отличия, но целыми файлами

В репозитории хранится только то, чем машина отличается от стандартной
Ubuntu, GNOME и приложений. Как именно — зависит от того, кому принадлежит
место, куда пишется настройка:

```text
Место                           Как храним                      Примеры
Хранилище с дефолтами схемы     только изменённые ключи          dconf (settings.conf,
                                                                 shortcuts, Tiling),
                                                                 Flatpak overrides
Каталог drop-in у пакета        свой файл целиком; сам файл —    sleep.conf.d, modprobe.d,
                                дельта, пакетный не трогаем      udev rules.d, modules-load.d,
                                                                 NetworkManager/conf.d,
                                                                 default/grub.d
Файл пакета без drop-in         правка своих ключей на месте,    /etc/default/keyboard,
                                не копия всего файла             /etc/fstab
Файл, целиком наш               полный файл                      config/fish, config/ghostty,
(пакету не принадлежит)                                          xremap.yml, refind_linux.conf,
                                                                 unit'ы и скрипты system/
Различия между машинами         только отличающиеся факты        hosts/<name>/facts.nix
```

Полный файл пакета (как `/etc/default/grub`) в репозиторий не копируется:
при обновлении пакета ucf будет спрашивать про конфликт, а новые
дефолты пакета перестанут доходить до машины.

Цена дельт:

- **Удаление ключа из дельты не возвращает значение по умолчанию.** Его надо
  сбросить явно: `wsflatpak` делает `--reset` приложения перед применением,
  `ws-gnome` — `rollback`, для dconf-ключей — явное значение по умолчанию.
- **Дефолт дистрибутива может измениться при обновлении.** Если конкретное
  значение важно, оно пишется в дельту явно, даже если сейчас совпадает с
  дефолтом.
- **`check` сравнивает только наши файлы и ключи.** Целостность пакетных
  файлов проверяют `dpkg --verify` и `ucfq`.

Ghostty и fish — тот же принцип на уровне приложения: в
`config/ghostty/*.ghostty` только отличия от дефолтов Ghostty, но хранятся
они целыми файлами, потому что весь файл наш.

## Правила на всю миграцию

- **Один владелец.** Перенос части и удаление старого механизма — в одном
  коммите.
- **Перенос ≠ улучшение.** Механизмы, пути, содержимое файлов и поведение
  не меняются. Особенно всё, что касается suspend, загрузки и клавиатуры.
- **verify вместе с переносом.** `ws-workstation-verify` проверяет конкретные
  пути и содержимое. Если перенос меняет то, что он проверяет, verify
  правится в том же коммите. verify не удаляется.
- **Регрессионный контроль.** Каждая фаза заканчивается
  `ws baseline capture phase-N` и `ws baseline diff pre-nix phase-N` без
  регрессий (раздел «Эталон функционала»).

---

# ЗАГРУЗКА И ОТКАТ

## Схема

```text
Обычная загрузка  rEFInd — Boot0080, \EFI\BOOT\BOOTX64.EFI (раздел 3)
                    ядро T2 из /boot, параметры из /boot/refind_linux.conf
Recovery          rEFInd → GRUB — \EFI\ubuntu\shimx64.efi (раздел 1)
                    другие ядра (7.2.6-1 T2, generic)
                    «Ubuntu — Backup snapshot» → .snapshots/recovery
```

## Что найдено при проверке 2026-09-26

Recovery в нынешнем виде, скорее всего, не поднимется:

- snapshot `recovery` сделан 2026-09-18, в нём только generic-ядра
  7.0.0-30/31: без t2bce (встроенная клавиатура и трекпад не работают после
  старта ядра) и без модуля `apfs`;
- в его `/etc/fstab` (и в текущем) строка `/mnt/apple` (apfs) записана как
  `defaults 0 1`, без `nofail`: без модуля apfs монтирование упадёт и
  система уйдёт в emergency mode, а при заблокированном root shell там не
  дадут;
- `system-backup-snapshot` копирует в пункт GRUB весь `/proc/cmdline`,
  включая `initrd=boot\initrd.img-…` от rEFInd;
- ядро для recovery выбирается как самое новое по `sort -V`, без
  предпочтения T2;
- в `/etc/default/grub.d/` лежит `90-pcie-aspm.cfg` (2026-09-18): он
  добавляет `pcie_aspm=force pcie_aspm.policy=powersave` ко всем пунктам
  GRUB, то есть к ядрам, которые грузятся через recovery. С этими
  параметрами T2 отказывала в stateful suspend (`docs/suspend.md`), из
  rEFInd они убраны 2026-09-25, а здесь остались.

Меню GRUB уже видно: `99-recovery-menu.cfg` в том же каталоге ставит
`GRUB_TIMEOUT_STYLE=menu` и `GRUB_TIMEOUT=5` поверх `hidden`/`0` из
`/etc/default/grub`. В версиях 2 и 3 до 2026-09-26 это было описано
неверно — смотрелся только `/etc/default/grub`.

Всё это исправляется в фазе −1.

## `/nix` на отдельном subvolume

Пользовательский слой в `@home` после фазы 1 состоит из ссылок в
`/nix/store`. Если бы `/nix` лежал внутри `@`, возврат `@` из snapshot'а или
загрузка recovery, сделанного до последнего switch, оставили бы эти ссылки
висящими: fish без конфигурации, пустой `~/.local/bin`. Поэтому `/nix` — это
subvolume `@nix`, который не откатывается вместе с `@`:

- откат `@` возвращает систему (`/etc/nix`, unit'ы nix-daemon, системные
  файлы), а store и ссылки в `@home` остаются согласованными;
- recovery-snapshot, сделанный после фазы 0, монтирует `@nix` по своему
  fstab;
- `@nix` snapshot'ится отдельно перед фазами (`pre-phaseN-nix`).

## Уровни отката

```text
1. Пользовательский слой (фазы 1–3)
   home-manager generations → activate предыдущего поколения
   ссылки *.hm-bak от первого switch; копии из /.snapshots/pre-nix-home

2. Системные файлы (фаза 4)
   заменённые файлы лежат в /var/backups/workstation/<время>/
   вернуть их или выполнить ws system apply из предыдущего коммита

3. Не грузится или не просыпается
   rEFInd → GRUB → предыдущее ядро T2 или «Backup snapshot»
   из recovery — вернуть @ из именованного snapshot'а (ниже)
```

## Возврат `@` из recovery

Загрузиться в «Backup snapshot», открыть TTY (Ctrl+Alt+F3):

```console
sudo mkdir -p /run/btrfs-top
sudo mount -o subvolid=5 UUID=0cfd2add-849f-47b9-865d-2ac821ca529c /run/btrfs-top
sudo mv /run/btrfs-top/@ /run/btrfs-top/@.broken
sudo btrfs subvolume snapshot /run/btrfs-top/.snapshots/pre-nix-root /run/btrfs-top/@
sudo btrfs subvolume get-default /run/btrfs-top
```

Если `get-default` показывает `@.broken`, перенести default на новый `@`:
default-subvolume хранится по ID, и rEFInd иначе возьмёт ядро и initrd из
старого корня.

```console
sudo btrfs subvolume list /run/btrfs-top
sudo btrfs subvolume set-default <ID нового @> /run/btrfs-top
```

Затем `sudo umount /run/btrfs-top`, перезагрузка через rEFInd и новый
`sudo system-backup-snapshot`. `@.broken` удалить, когда всё проверено.

Если `@` вернули в состояние до фазы 0, в fstab нет строки `@nix`: store не
смонтирован, ссылки home-manager в `@home` висят. Тогда либо вернуть строку
`@nix` в fstab (Nix-слой снова работает без переустановки), либо откатить и
пользовательский слой — `~/.local/state/workstation/baseline/pre-nix/`
содержит прежние ссылки на checkout.

`@home` возвращается из `pre-nix-home` только вне пользовательской сессии и
с потерей всех пользовательских данных после snapshot'а — последнее
средство.

---

# ЭТАЛОН ФУНКЦИОНАЛА

Эталон — это состояние на теге `pre-nix`. Регрессия — любое отличие от него,
которого нет в списке ожидаемых изменений фазы.

`bin/ws-baseline` (новый, фаза −1):

```text
ws-baseline capture NAME   → ~/.local/state/workstation/baseline/NAME/
ws-baseline diff A B       → различия, без изменчивых строк
```

Что снимает `capture`:

```text
Проверки владельцев   ws-workstation-verify --strict, wsflatpak check,
                      wsbox check, ws-gnome check, ws-gnome test (автоматическая
                      часть), ws-suspend status, ws-keyboard-status,
                      ws-input-source status
                      (сравниваются множества PASS/WARN/FAIL-строк)
GNOME                 dconf dump /, gnome-extensions list --enabled
Flatpak               flatpak list --user --app, remotes, override --show
                      по каждому приложению, ссылки в ~/.local/share/applications
Distrobox             podman ps -a (имя, образ, ID), distrobox list
Пользователь          ~/.local/bin, ~/.config/{fish,ghostty,systemd/user},
                      ~/.local/share/gnome-shell/extensions: путь → readlink -f,
                      sha256 содержимого; systemctl --user list-unit-files
                      --state=enabled; systemctl --user show-environment;
                      *xdg-terminals.list (без ~/.config/autostart/)
Система               sha256 файлов из описи системного слоя, включённые
                      system unit'ы, /proc/cmdline, lsmod (t2bce, appletb,
                      ntsync, apple-gmux), /sys/power/mem_sleep
Инструменты           command -v и --version: xremap, fzf, zoxide, eza,
                      lowdown, micro, fish, ghostty
```

`wsbox check` запускает контейнеры (distrobox enter), поэтому `capture` не
полностью read-only. Он пишет только в свой каталог.

`diff` сравнивает по смыслу, а не по байтам. Например, смена
`~/.local/bin/wsbox → checkout` на `~/.local/bin/wsbox → /nix/store/… →
checkout` не регрессия, если `readlink -f` и sha256 совпадают.

Ручная матрица (после reboot и после suspend) — как в `keyboard.md` и в
разделе 11 `rebuild.md`: CapsLock EN↔RU, Fn+CapsLock → UA, Ctrl+Space по
кругу, Super+C/V в Ghostty и Nautilus, Cmd+Q/H/M, Finder-шорткаты,
Shift+Super+3/4/5, Ctrl+←/→, Fn+Ctrl+стрелки, Tile Editing Mode, Always on
Top, Smart Popup, Dock Spring, EN на экране блокировки и в GDM, Touch Bar
F1…F12 / Fn → media, Wi-Fi после resume, WinBox из arch, Claude с
масштабом 1.5.

---

# ЦЕЛЕВАЯ СТРУКТУРА

```text
flake.nix, flake.lock
bootstrap.sh              Ubuntu → apt → @nix → Nix → первый switch
hosts/mbp16/
  facts.nix               чем машина отличается от других
  home.nix                пользовательский слой хоста
  system.nix              опись системных файлов хоста
  apt.txt                 пакеты apt хоста
modules/home/             cli.nix, links.nix, xremap.nix
modules/system/
  common/                 uinput, NTSync modules-load
  boot/refind-grub-recovery/
  hardware/t2-mbp16/      udev, modprobe, sleep, NCM, Touch Bar, ASPM,
                          modules-load t2, get-apple-firmware
pkgs/xremap.nix           тот же zip v0.15.13 с GitHub, по hash
bin/, config/, system/, kernel/, gnome/, docs/, man/, state/   — как сейчас
```

```nix
# hosts/mbp16/facts.nix
{
  user = "king";
  hardware = "t2-mbp16";           # t2-mbp16 | generic-pc
  boot = "refind-grub-recovery";   # refind-grub-recovery | grub
  kernelParams = [ "quiet" "splash" "intel_iommu=on" "iommu=pt" "pm_async=off" ];
}
```

Новые факты добавляются, когда второй машине действительно нужно другое
значение (фаза 6), а не заранее.

---

# ФАЗЫ

```text
 #   Фаза                                   Риск      sudo       ≈ вечеров
−1   Стабилизация, recovery, пробелы        средний   да         2–3
 0   @nix, Nix, скелет flake, ws, CI        низкий    да         2
 1   Терминал и доставка команд             низкий    нет        1–2
 2   Оркестратор ws apply / ws check        низкий    нет        1
 3   Бинарник xremap                        средний   нет        1
 4   Системный слой                         высокий   да         2–3
 5   Переключение и уборка                  низкий    частично   1
 6   Второе железо: VM, потом машина        средний   да         1–2
```

После любой фазы можно остановиться и жить в смешанном режиме. Шаги с sudo
выполняются в своём терминале: sudo спрашивает пароль.

---

# ФАЗА −1 — СТАБИЛИЗАЦИЯ, RECOVERY, ПРОБЕЛЫ

**Вход:** suspend в текущей конфигурации подтверждён — не меньше 20 чистых
циклов в native-режиме Touch Bar. Счёт по `/var/log/kern.log` записать в
эталон.

1. **Удержать ядро.** Фикс t2bce собран только для 7.2.7-1:

   ```console
   sudo apt-mark hold linux-t2
   ```

   В том же коммите поправить `docs/suspend.md`, раздел «Обновление ядра»:
   обновление — это снять hold, собрать модули, вернуть hold.
   `ws-suspend status` уже показывает `held`.

2. **fstab.** Строку `/mnt/apple` (APFS macOS) удалить: раздел больше не
   используется. Отмонтировать, удалить строку и комментарий установщика
   перед ней, `sudo findmnt --verify`, пустой каталог `/mnt/apple` удалить.
   Делается до обновления recovery, чтобы исправленный fstab попал в
   snapshot.

3. **GRUB: только drop-in'ы.** Меню уже включено `99-recovery-menu.cfg`.
   - удалить `/etc/default/grub.d/90-pcie-aspm.cfg`: forced ASPM не
     используется (`docs/suspend.md`), recovery-ядра должны грузиться с теми
     же параметрами, что и обычные;
   - свои параметры ядра вынести из `/etc/default/grub` в
     `/etc/default/grub.d/10-workstation-cmdline.cfg`
     (`GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt
     pm_async=off"`), а сам `/etc/default/grub` вернуть к шаблону пакета
     (`/usr/share/grub/default/grub`). Итоговый `grub.cfg` не меняется, кроме
     ушедшего `pcie_aspm` — сверить до и после `update-grub`;
   - `kdump-tools.cfg` принадлежит пакету `kdump-tools`, не трогать.

   Затем `sudo update-grub`. Обычную загрузку это не затрагивает: она идёт
   через rEFInd.

4. **`system-backup-snapshot`.** Сначала захватить как есть в
   `system/usr/local/sbin/system-backup-snapshot` (отдельный коммит), затем
   исправить:
   - добавить `initrd=*` к аргументам, которые не копируются из
     `/proc/cmdline`;
   - выбирать для recovery ядро T2 (`vmlinuz-*-t2-*`), generic — только если
     T2 нет.

   Установить: `sudo install -m0755 … /usr/local/sbin/system-backup-snapshot`.

5. **Root и emergency mode.** Пароль root не задаётся (решение
   2026-09-26): emergency mode shell не даст. Поэтому recovery не должен
   зависеть от необязательных дисков (шаг 2), а запасной путь, если и он не
   поднимется, — флешка с T2-ISO.

6. **Захватить остальной системный слой** — байт в байт, без установки:

   ```text
   /etc/udev/rules.d/30-amdgpu-pm.rules              → system/udev/
   /etc/udev/rules.d/99-network-t2-ncm.rules         → system/udev/
   /etc/NetworkManager/conf.d/99-network-t2-ncm.conf → system/NetworkManager/conf.d/
   /etc/modprobe.d/apple-gmux.conf                   → system/modprobe/
   /etc/modules-load.d/t2.conf                       → system/modules-load.d/
   /etc/systemd/system/get-apple-firmware.service    → system/systemd/system/
   /boot/refind_linux.conf                           → system/boot/
   /etc/default/grub.d/10-workstation-cmdline.cfg    → system/default/grub.d/  (после шага 3)
   /etc/default/grub.d/99-recovery-menu.cfg          → system/default/grub.d/
   refind.conf с раздела rEFInd                      → system/esp/  (только check)
   ```

   Уже в репозитории: suspend layer (`ws-suspend`), Touch Bar и uinput
   (`ws-keyboard-system-apply`), `ntsync.conf`
   (`config/distrobox/host/modules-load.d/`), патч t2bce (`kernel/t2bce/`).
   `get-apple-firmware.service` пришёл из T2-установщика, его `ExecStart`
   принадлежит пакету `apple-firmware-script`: захватывается только unit.
   `/usr/local/sbin/pm-processors-test` — отладочный скрипт, не переносится.

   verify: добавить эти файлы в список tracked и `compare_file` с runtime.

7. **Закрыть пробелы, которые миграция иначе закрепила бы:**
   - **Tiling Assistant.** Биндинги `<Shift><Control><Alt><Super>` +
     Left/Right/Up/Down/f/c/r (tile-*, center, restore), `e`
     (tile-edit-mode) и `t` (toggle-always-on-top) живут только в dconf: ни
     один скрипт их не ставит, verify их только проверяет. Добавить их в
     `ws-tiling-apply` рядом с F13–F19, тем же способом (дописать в массив,
     не заменять), и проверить на текущей машине, что повторный запуск
     ничего не меняет.
   - **`man ws-*`.** Сейчас не находится: `~/.local/share/man/man1` пуст.
     Решается в фазе 1 ссылкой на `man/man1` checkout'а; до этого не
     обещать `man ws-…` в документах.
   - **Терминал по умолчанию.** GNOME на Ubuntu открывает терминал через
     `xdg-terminal-exec` («Открыть в терминале» в Nautilus, `.desktop` с
     `Terminal=true`). Выбор Ghostty задают три файла вне репозитория:

     ```text
     ~/.config/ubuntu-xdg-terminals.list                   → ghostty-open-here.desktop
     ~/.config/xdg-terminals.list                          → ghostty-open-here.desktop
     ~/.local/share/applications/ghostty-open-here.desktop   --gtk-single-instance=false
     ```

     Захватить как есть в `config/xdg-terminals/` и разложить ссылками, как
     fish и ghostty (с фазы 1 — home-manager). verify: оба `.list`
     указывают на `ghostty-open-here.desktop`, ссылки ведут в репозиторий.
     Отсутствие `NoDisplay` (второй пункт в сетке приложений) и `ssh-env`
     не исправлять — это улучшение после миграции.
   - **`~/.config/autostart/remmina-applet.desktop`** — служебный файл
     Remmina (`Hidden=true`, автозапуск выключен; системного автозапуска
     нет). Не захватывать; `ws-baseline` не сравнивает `~/.config/autostart/`,
     кроме файлов, которые положит сам репозиторий.
   - **Ссылки в `~/.local/bin`.** Их создаёт не один скрипт: часть делает
     `ws-keyboard-apply`, `wsbox` — `rebuild.md`, а `ws-suspend`,
     `wsflatpak`, `helpws`, `dotgit`, `ws-gnome*` не создаёт никто. Записать
     полный список в эталон; с фазы 1 их создаёт home-manager.

8. **`bin/ws-baseline`** (раздел «Эталон функционала»), с проверкой
   `bash -n` и shellcheck в verify.

9. **Коммит и тег.** `ws-workstation-verify --strict` зелёный, тег
   `pre-nix`. Во время миграции репозиторий не правится параллельно в других
   сессиях.

10. **Эталон, recovery, snapshot'ы:**

    ```console
    ws-baseline capture pre-nix
    sudo system-backup-snapshot
    sudo btrfs subvolume snapshot -r / /.snapshots/pre-nix-root
    sudo btrfs subvolume snapshot -r /home /.snapshots/pre-nix-home
    sudo btrfs subvolume get-default /
    ```

    Скрипт хранит два поколения `recovery`/`backup-ro`; именованные
    snapshot'ы он не трогает. Вывод `get-default` записать в эталон.

11. **Проверить recovery на деле.** rEFInd → GRUB → «Ubuntu — Backup
    snapshot»: система поднимается, встроенная клавиатура работает,
    `findmnt /` показывает `.snapshots/recovery`. Затем пункт предыдущего
    ядра T2 (7.2.6-1): грузится (suspend на нём не проверять — там нет
    фикса). Вернуться через rEFInd.

**Готово:** hold стоит; recovery грузится с ядром T2 и встроенной
клавиатурой; эталон `pre-nix` снят; `pre-nix-root`, `pre-nix-home` и тег
`pre-nix` существуют.

---

# ФАЗА 0 — @NIX, NIX, СКЕЛЕТ FLAKE, WS, CI

1. **Эталон с sudo** — до установки Nix, потому что установщик меняет
   `/etc/bash.bashrc` и другие файлы: `dpkg --verify`,
   `lsinitrd /boot/initrd.img-$(uname -r)` → в `baseline/pre-nix/`.

2. **Subvolume `@nix`:**

   ```console
   sudo mkdir -p /run/btrfs-top
   sudo mount -o subvolid=5 UUID=0cfd2add-849f-47b9-865d-2ac821ca529c /run/btrfs-top
   sudo btrfs subvolume create /run/btrfs-top/@nix
   sudo umount /run/btrfs-top
   sudo mkdir /nix
   ```

   В `/etc/fstab`:

   ```text
   UUID=0cfd2add-849f-47b9-865d-2ac821ca529c  /nix  btrfs  subvol=@nix,noatime,compress=zstd:1  0 0
   ```

   `sudo systemctl daemon-reload && sudo mount /nix && findmnt /nix`.

3. **Установить Nix:**

   ```console
   curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install -o /tmp/nix-install
   sh /tmp/nix-install --daemon
   ```

   Затем в `/etc/nix/nix.conf` строка
   `experimental-features = nix-command flakes` и
   `sudo systemctl restart nix-daemon`.

4. **Nix в login shell.** GNOME-сессия строит окружение через `fish -l`, а
   `/etc/fish/conf.d` пуст. Добавить `config/fish/conf.d/00-nix.fish` и
   ссылку на него в `~/.config/fish/conf.d/`, как у остальных файлов:

   ```fish
   # Nix для login shell. GNOME строит окружение сессии через `fish -l`,
   # поэтому файл должен быть быстрым, без сети и безопасным без Nix.
   if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
       source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
   else if test -d /nix/var/nix/profiles/default/bin
       fish_add_path --global --path $HOME/.nix-profile/bin /nix/var/nix/profiles/default/bin
   end
   ```

   `user-bin.fish` идёт после и оставляет `~/.local/bin` первым в PATH, как
   сейчас. Переменные окружения задаются только в fish:
   `home.sessionVariables` до fish не доходят. После перелогина проверить
   `systemctl --user show-environment` и `fish -l -c 'command -v nix'`.

5. **Скелет flake.** Inputs: `nixpkgs` (`nixos-26.05`), `home-manager`
   (`release-26.05`, follows nixpkgs). Минимальный home для `king@mbp16`:
   `targets.genericLinux.enable = true`, `programs.home-manager.enable = true`.
   - Новые файлы — `git add` до сборки: flake видит только файлы из git.
   - В `.gitignore` добавить `result` и `result-*`, сборки — с
     `--no-link`: висящая ссылка `result` — FAIL в verify («broken symlink
     in repo tree»).

   Первый запуск:

   ```console
   nix run home-manager/release-26.05 -- switch --flake ~/.local/share/workstation-config#king@mbp16
   ```

6. **`bin/ws`** — bash, как остальные `bin/`: `ws switch` (home-manager
   switch), `ws diff` (сборка и `nvd diff`), `ws baseline` (обёртка
   `ws-baseline`). `ws` запускается от пользователя и сам вызывает sudo там,
   где нужно: `sudo ws` не сработает, secure_path не видит профиль Nix.

7. **CI** (GitHub Actions): `nix flake check`, сборка всех
   `homeConfigurations`, `bash -n`/`fish -n`/`python3 -m py_compile` по
   `bin/` и `system/`. С фазы 4 — сборка системных деревьев хостов.

8. **verify:** раздел Nix — `/nix` смонтирован из `@nix`, nix-daemon
   активен, `00-nix.fish` отслеживается и подключён.

**Готово:** пустой switch проходит; после перелогина Nix есть в PATH
GNOME-сессии; `ws baseline diff pre-nix phase-0` — только ожидаемое (новые
файлы Nix, строка fstab); CI зелёный; тег `nix-phase-0`.

**Откат:** удалить Nix по официальной инструкции для multi-user, убрать
строку `@nix` из fstab, удалить subvolume. `00-nix.fish` без Nix ничего не
делает.

---

# ФАЗА 1 — ТЕРМИНАЛ И ДОСТАВКА КОМАНД

Home-manager начинает владеть ссылками, которые сейчас созданы вручную или
разными скриптами. Цели ссылок не меняются: всё указывает в checkout.

- **Ссылки** (`mkOutOfStoreSymlink` на checkout, по одному файлу, как
  сейчас):
  - `~/.config/fish/config.fish`, `conf.d/*`, `functions/*`,
    `completions/*`. Новое — только `ws-gnome-test.fish`: он есть в
    репозитории, но не подключён;
  - `~/.config/ghostty/*.ghostty`;
  - `~/.config/{ubuntu-,}xdg-terminals.list` и
    `~/.local/share/applications/ghostty-open-here.desktop`
    (`config/xdg-terminals/`, захвачены в фазе −1);
  - `~/.local/bin/`: `dotgit`, `helpws`, `ws`, `ws-baseline`,
    `ws-doc-build`, `ws-gnome`, `ws-gnome-apply`, `ws-gnome-status`,
    `ws-gnome-test`, `ws-input-source`, `ws-keyboard`, `ws-keyboard-apply`,
    `ws-keyboard-install-extensions`, `ws-keyboard-status`,
    `ws-keyboard-system-apply`, `ws-nautilus-current`, `ws-suspend`,
    `ws-tiling-apply`, `ws-window`, `ws-workstation-verify`, `ws-xremap`,
    `wsbox`, `wsflatpak`;
  - `~/.local/share/man/man1` → `man/man1` checkout'а: начинает работать
    `man ws-…`.
- **Не трогаются:** `~/.local/bin/xremap` (фаза 3),
  `~/.config/systemd/user/xremap.service` и его wants-ссылка (владелец —
  `ws-keyboard-apply`), `.desktop` Claude (владелец — `wsflatpak`),
  расширения GNOME (владелец — `ws-keyboard-install-extensions`),
  `bin/ws-caps-led` (вызывается расширением по абсолютному пути, в PATH его
  нет).
- **Совместимость с владельцами.** `ws-keyboard-apply` проверяет свои ссылки
  через `readlink -f` и цепочку `→ /nix/store → checkout` принимает; verify
  тоже сравнивает `readlink -f`. `wsflatpak` ищет репозиторий через
  `WORKSTATION_CONFIG` или свой путь: ссылка ведёт в checkout, путь
  разрешается туда же.
- **CLI в `home.packages`:** fzf, zoxide, eza, lowdown, micro, nvd. apt-версии
  остаются до фазы 5, профиль Nix стоит в PATH раньше `/usr/bin`. Перед
  переключением сравнить версии (`fzf --fish`, флаги eza в
  `config/fish/conf.d/eza.fish`, вывод `lowdown -s -t man` для
  `ws-doc-build`). Если lowdown из Nix даёт другой man, verify покажет WARN
  «generated man page differs»: тогда либо перегенерировать `man/` одним
  коммитом, либо оставить lowdown из apt.
- **Completions CLI из Nix:** добавить
  `~/.nix-profile/share/fish/vendor_completions.d` в `fish_complete_path`.
  `XDG_DATA_DIRS` не трогать, иначе в сетке приложений появятся дубли
  `.desktop`.
- **Удалить** битую `~/.local/bin/ws-nautilus-go`.

Порядок:

1. `ws switch -b hm-bak`: существующие ссылки станут `*.hm-bak`,
   переименовываются сами ссылки, а не файлы репозитория.
2. Новый терминал, проверки, `ws baseline capture phase-1`,
   `ws baseline diff pre-nix phase-1`.
3. Удалить `*.hm-bak`.

**Готово:** diff без регрессий (ожидаемо: ссылки через store, версии CLI,
новые `ws`, `ws-baseline`, `ws-gnome-test.fish`, `man`); prompt, Alt+C,
zoxide, алиасы eza, заголовки вкладок как раньше; клавиатурная матрица без
изменений; тег `nix-phase-1`.

**Откат:** `home-manager generations` → `activate` предыдущего поколения;
ссылки `*.hm-bak`.

---

# ФАЗА 2 — ОРКЕСТРАТОР WS APPLY / WS CHECK

Ценность для нескольких машин — один порядок подъёма. Владельцы не
меняются, `ws` только вызывает их по очереди:

```text
ws apply    ws-keyboard-install-extensions → ws-tiling-apply →
            ws-keyboard-apply → ws-gnome apply → wsflatpak apply →
            wsbox apply
            (шаги, чей preflight не прошёл, выводятся в конце; на новой
            машине: ws apply → logout/login → ws apply)
ws check    ws-workstation-verify, wsflatpak check, wsbox check,
            ws-gnome check, ws-suspend status; общий итог FAIL/WARN
```

- `ws apply` не выполняет sudo-шагов: системный слой — `ws system apply`
  (фаза 4).
- Каждый вызов владельца — как вручную сейчас, с тем же окружением.
- В `rebuild.md` разделы 6.1, 6.3, 6.4 и 10 ссылаются на `ws apply`, ручные
  команды остаются как пояснение.

**Готово:** `ws apply` на текущей машине ничего не меняет (`ws baseline diff`
пуст, кроме отметок времени бэкапов `ws-gnome`); `ws check` зелёный; тег
`nix-phase-2`.

---

# ФАЗА 3 — БИНАРНИК XREMAP

- `pkgs/xremap.nix`: тот же `xremap-linux-x86_64-gnome.zip` v0.15.13 с
  GitHub, по hash. Бинарник статический, patchelf не нужен.
- Критерий подмены: sha256 бинарника из store равен sha256
  `runtime/xremap/v0.15.13/xremap`.
- `~/.local/bin/xremap` → store (home-manager) вместо
  `runtime/xremap/current/xremap`. `ws-xremap` находит его через PATH
  unit'а, как сейчас.
- Не меняются: `xremap.yml` (включая абсолютный путь к `ws-input-source`),
  `ws-xremap` (`--watch=config,device` из `settings.conf`,
  `--ignore "Dynamic Function Row Virtual Input Device"`,
  `--output-device-name workstation-xremap`), `xremap.service`,
  расширения `xremap@k0kubun.com` и `window-control@carlo9890.github.io`.
- Порядок: switch → `ws-keyboard restart` → матрица → reboot → матрица →
  suspend → матрица.
- `runtime/` удалить после reboot-проверки. Проверка verify «.gitignore
  covers runtime/probe» остаётся до фазы 5.

**Готово:** `ws baseline diff` — только путь `xremap`; вся ручная матрица,
включая после suspend; тег `nix-phase-3`.

**Откат:** предыдущее поколение home-manager; `runtime/` до удаления
остаётся рядом.

---

# ФАЗА 4 — СИСТЕМНЫЙ СЛОЙ

Перед фазой: `sudo system-backup-snapshot`, `pre-phase4-root` и
`pre-phase4-nix`.

## 4a. Сборка и `ws system diff|check`

Nix собирает дерево файлов хоста из `system/` и `config/distrobox/host/`,
байт в байт. Опись (`hosts/mbp16/system.nix`) — все файлы, которыми сейчас
владеют `ws-keyboard-system-apply`, `ws-suspend apply`, ручная установка
`ntsync.conf` и захваченные в фазе −1:

```text
common           99-workstation-uinput.rules, modules-load.d/ntsync.conf
boot             /boot/refind_linux.conf, grub.d/10-workstation-cmdline.cfg,
                 grub.d/99-recovery-menu.cfg,
                 /usr/local/sbin/system-backup-snapshot, refind.conf (check)
t2-mbp16         90-touchbar-native.rules, 70-bcm4364-no-d3cold.rules,
                 30-amdgpu-pm.rules, 99-network-t2-ncm.rules + NM conf,
                 modprobe tb.conf, touchbar-native.conf, apple-gmux.conf,
                 modules-load.d/t2.conf, sleep.conf.d/80-deep-only.conf,
                 80-broadcom-aspm (system-sleep), broadcom-aspm-suspend-guard,
                 broadcom-aspm-restore.service, ws-touchbar-fn + unit,
                 get-apple-firmware.service
```

`refind_linux.conf` и `10-workstation-cmdline.cfg` собираются из
`facts.kernelParams`. Сборка должна дать ровно нынешние файлы.

Сначала работают только `diff` и `check`. **Критерий 4a — первый
`ws system diff` пуст.** Непустой diff означает ошибку описи, а не повод
что-то менять.

`ws system check` проверяет и включённость: `ws-touchbar-fn.service` и
`get-apple-firmware.service` enabled (multi-user.target),
`broadcom-aspm-restore.service` static.

## 4b. `ws system apply` — те же действия, что сейчас

`apply` повторяет всё, что делают `ws-keyboard-system-apply` и
`ws-suspend apply`, а не только копирует файлы:

```text
до копирования   бэкап заменяемых файлов в /var/backups/workstation/<время>/
копирование      install -D с нынешними режимами (0644 / 0755)
/etc/default/keyboard
                 правка, как в ws-keyboard-system-apply: XKBLAYOUT=us,
                 без grp:/grp_led: (файл принадлежит keyboard-configuration,
                 целиком не заменяется)
удаление         известные устаревшие: /etc/tiny-dfr/config.toml (если
                 tiny-dfr не установлен), 70-workstation-uinput.rules (только
                 если совпадает со старым содержимым)
unit'ы           daemon-reload; enable ws-touchbar-fn,
                 get-apple-firmware; restart ws-touchbar-fn
udev             control --reload-rules; trigger --subsystem-match=input
                 --action=change; settle
initramfs        update-initramfs -u -k $(uname -r) только если изменились
                 modprobe-файлы (опции hid-appletb-kbd читаются из initramfs)
grub             update-grub только если изменились файлы grub.d
проверка         cmp всех файлов; ws-touchbar-fn active; предупреждения
                 про Touch Bar config и tiny-dfr, как сейчас
```

ESP не трогает, сам не перезагружает.

Один владелец — в том же коммите:

- `ws-keyboard-system-apply` → обёртка над `ws system apply` (имя остаётся:
  на него ссылаются `rebuild.md` и verify);
- `ws-suspend apply` → то же; `ws-suspend status`, `t2bce-build`,
  `t2bce-install`, `t2bce-rollback` не меняются;
- verify: проверки «apply installs …» указывают на новое место логики.

Перед первым suspend после любого `apply`:

- `systemd-analyze cat-config systemd/sleep.conf` показывает
  `MemorySleepMode=deep`;
- `sudo lsinitrd | grep -E 't2bce|appletb|modprobe.d'` совпадает с эталоном.

**Готово:** `ws system diff` пуст; `ws system apply` на текущей машине
меняет только отметки времени; не меньше 10 чистых циклов suspend; recovery
обновлён и грузится; тег `nix-phase-4`.

**Откат:** файлы из `/var/backups/workstation/`; если не грузится — GRUB →
recovery → `pre-phase4-root`.

---

# ФАЗА 5 — ПЕРЕКЛЮЧЕНИЕ И УБОРКА

- `bootstrap.sh`: apt из общего списка и `hosts/<name>/apt.txt` → `@nix` →
  Nix → первый switch. `ws check apt` сравнивает с `apt-mark showmanual` и
  только сообщает о различиях.
- Удалить apt-версии fzf, zoxide, eza, micro, lowdown, если в фазах 1–4 не
  понадобились.
- `ws check` — основной вход; `ws-workstation-verify` остаётся его частью.
- Документы: `rebuild.md` — под bootstrap, `ws apply` и recovery;
  `workstation.md` — где что лежит; `roadmap.md` — ссылка на этот план.
- `state/` остаётся: `ws-keyboard restore` читает
  `state/keyboard/gsettings-backup.tsv`.
- Тег `nix-v1`.

---

# ФАЗА 6 — ВТОРОЕ ЖЕЛЕЗО

- Сначала VM (KVM из `plan-virt`): чистая Ubuntu 26.04 на generic-ядре,
  `boot = "grub"`, `hardware = "generic-pc"`, весь путь по `rebuild.md`.
- На generic-ядре есть ограничение AppArmor на user namespaces, в T2-ядре
  его нет. Всё, что зависит от sandbox, проверять там.
- Что станет фактами хоста, только когда понадобится другое значение:
  - масштаб 1.5 в `.desktop` Claude (`config/flatpak/desktop/`) — каталог
    данных хоста для `wsflatpak`;
  - абсолютные пути `/home/king/…` в `xremap.yml` и в `LED_HELPER`
    расширения input-source — если имя пользователя другое;
  - `keyboard.physical = "pc"` — своя клавиша для UA вместо Fn+CapsLock;
  - verify: проверки T2 и Touch Bar — только для `hardware = "t2-mbp16"`.
- Реальная машина: новый `hosts/<name>/` и при необходимости
  hardware-профиль; recovery проверить, как в фазе −1.

**Готово:** вторая машина поднимается без правок в репозитории, кроме её
каталога в `hosts/` и явно добавленных фактов.

---

# ПОСЛЕ МИГРАЦИИ

Отдельные задачи, каждая — со своим эталоном и критерием «check владельца
PASS, `ws baseline diff` пуст»:

- GNOME через `dconf.settings` вместо `ws-gnome apply`. Учесть: home-manager
  применяет значения при каждом switch, ручные правки будут откатываться.
- Flatpak через nix-flatpak или генерацию `apps.conf`. Учесть: `wsflatpak`
  пишет в `config/flatpak/`, а его `check` требует ссылку `.desktop` на
  репозиторий.
- xremap как `systemd.user.services` и `xremap.yml` со store-путями.
- Расширения с EGO по версии и hash.
- Скрипты в store (`writeShellApplication`) вместо ссылок на checkout.
- `man/` собирать при сборке, а не хранить в git.
- Фикс t2bce через DKMS — только если сборка в podman станет неудобной;
  `build-essential` на хосте противоречит правилу roadmap про toolchains.
- Закрепить образ `arch` по digest (сейчас `wsbox check` сравнивает с
  `archlinux:latest`).
- Удалить `state/` после переноса `gsettings-backup.tsv`.
- Убрать `t2bce-build` и `touchbar-build`: сборку t2bce делает
  `ws-suspend` в одноразовом контейнере.

---

# ОБЩИЕ ПРАВИЛА

- Перед фазами −1, 0 и 4 — `system-backup-snapshot` и именованные snapshot'ы
  (`@` и `@nix`); после каждой фазы — `ws baseline capture phase-N` и тег
  `nix-phase-N`. Recovery обновлять только из проверенного состояния.
- Фазы 3 и 4 — с запасом времени на logout и reboot, не перед важной
  работой.
- `git add` перед сборкой; сборки с `--no-link`.
- sudo-шаги выполняются в своём терминале.
- Во время фазы репозиторий не правится в других сессиях.
- `nix flake update` — раз в месяц отдельным коммитом, после зелёного CI.
- Сборка мусора Nix — по таймеру (`nix.gc` в home-manager), поколения
  хранить 30 дней.
- Секреты в репозиторий не класть.

# СВЯЗЬ С ROADMAP

- `plan-gnome`, `plan-flatpak`, `plan-dev` — DONE; миграция их слои только
  доставляет.
- `plan-t2` — после фазы 4.
- `plan-virt` — до фазы 6: нужна VM.
- `plan-windows` — независимо; контейнеры `wine`/`arch` остаются за `wsbox`.
- `plan-final` в основном закрывают фазы −1, 0 и 5.

# ИЗМЕНЕНИЯ ОТНОСИТЕЛЬНО ВЕРСИИ 2

- Принцип «Nix доставляет, владельцы не меняются»: `wsflatpak`, `wsbox`,
  `ws-gnome`, `ws-keyboard*`, `ws-suspend` и verify остаются; nix-flatpak,
  генерация `distrobox.ini`, `dconf.settings`, xremap как модуль и DKMS
  перенесены в «После миграции».
- `bin/` — ссылками на checkout, без `writeShellApplication` и
  `patchShebangs`.
- `/nix` — на subvolume `@nix`.
- Раздел «Эталон функционала» и `ws-baseline`; verify правится в том же
  коммите, что и перенос.
- Фаза −1: опись системного слоя обновлена под коммит `0b50385`; добавлены
  `t2.conf` и `get-apple-firmware.service`; закрываются пробелы (биндинги
  Tiling Assistant, `man`, выбор терминала через
  `xdg-terminal-exec`).
- `ws system apply` повторяет все действия нынешних apply-скриптов
  (enable/restart, udev trigger, правка `/etc/default/keyboard`, уборка
  устаревшего), а не только копирует.
- `window-monitor-pro` остаётся включённым: он установлен и обязателен по
  verify.
- `--watch=config,device` и `--ignore` Dynamic Function Row в `ws-xremap`
  не меняются.
- Фазы: убраны «Внешний вид GNOME», «Flatpak и Distrobox» и «Клавиатурный
  слой»; добавлены «Оркестратор» и «Бинарник xremap».
- Добавлен раздел «Формат конфигов»: в репозитории только отличия от
  стандартной системы; `/etc/default/grub` заменён drop-in'ами `grub.d`.
- Исправлено: меню GRUB уже включено `99-recovery-menu.cfg`; найден
  устаревший `90-pcie-aspm.cfg`, он удаляется в фазе −1.
