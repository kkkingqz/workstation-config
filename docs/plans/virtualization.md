title: ws-plan-virt
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# PLAN — KVM / LIBVIRT

## Цель

Штатная виртуализация на host: KVM/QEMU, libvirt `qemu:///system`, удобный
GUI для управления VM. В отличие от toolchains, виртуализация остаётся на
host: она связана с ядром, устройствами и сетью. Как пользоваться —
`helpws virt`.

После плана — фаза 6 (`helpws history-nix`): первая VM этого плана —
чистая Ubuntu 26.04 для неё.

## Решения

```text
пакеты         nix/hosts/apt.txt (ставит bootstrap.sh, сверяет ws check apt)
подключение    qemu:///system; группа libvirt (bootstrap.sh), kvm не нужна
GUI            virt-manager: мастер создания, консоль SPICE (буфер обмена,
               подгонка экрана, USB redirect), snapshots, настройки VM
хранение       всё состояние VM на subvolume @vms (/var/lib/vms), вне snapshots
               @: images (пул default, без CoW), qemu (NVRAM, snapshots),
               swtpm, xml — bind-монтированиями в пути libvirt; ~/VMs — ссылка
backup         диски не входят в ws collect: backup @vms — plan-final
сеть           NAT default (virbr0); bridge нет: Wi-Fi не мостится
описания VM    состояние libvirt, не в репозитории; на @vms, ws collect
               сохраняет XML, NVRAM и TPM для переустановки
проверка       ws check virt
Windows        заложено на host (OVMF Secure Boot + ключи Microsoft, swtpm),
               сама VM вне плана
проброс GPU    нет (AMD не возвращается в D0 после выключения)
```

GUI выбран `virt-manager`: GNOME Boxes работает только с
`qemu:///session` (без NAT-сети libvirt и общего пула), Cockpit — веб-консоль
с отдельным сервисом. Если `virt-manager` окажется неудобен на масштабе 1.5
или Wayland — вернуться к выбору.

## Шаги

1. **Сделано (2026-09-28).** Репозиторий: пакеты в `nix/hosts/apt.txt`,
   шаг 3 `bootstrap.sh` (`@vms`, `chattr +C`, `root:libvirt 2775`, пул и
   сеть `default`), группа `libvirt`, `virt/virt.nix` (`~/VMs`),
   `ws check virt` в `ws check`, `virt/` в `ws collect`, проверка в
   `ws baseline`, `helpws virt`.
2. **Сделано (2026-09-28).** `bootstrap.sh`, logout/login, `ws check` без
   WARN. По ходу: проверка состояния `virsh` через `grep -q` ломалась от
   SIGPIPE при `pipefail`; `sg` в 26.04 — в `util-linux-extra` (добавлен в
   apt-список).
3. GUI: **сделано (2026-09-28)** — `virt-manager` подключается к
   `qemu:///system` сам, на масштабе 1.5 выглядит нормально. Остаётся с
   гостем: буфер обмена и подгонка разрешения (spice-vdagent). Настройки
   `virt-manager`, если понадобится закрепить, — в `virt/virt.nix`
   (`dconf.settings`).
4. Тестовая VM `ubuntu-test` создана (2026-09-28, `virt-install`, mini ISO
   26.04): q35, OVMF Secure Boot + TPM, 4 vCPU, 8 ГБ, 40 ГБ qcow2 без CoW,
   virtio, SPICE. Найдено: путь через `~/VMs` qemu не открывает — только
   пути пула; NVRAM лежит на `@` — добавлен в `ws collect`.
   **2026-09-29:** по замечанию пользователя всё постоянное состояние VM
   перенесено на `@vms`: `@vms` в `/var/lib/vms`, bind-монтирования
   `images`, `qemu` (NVRAM, snapshots), `swtpm`, `xml` (`/etc/libvirt/qemu`).
   Прежняя раскладка (`@vms` прямо в `images`) переносится `bootstrap.sh`
   при выключенных VM.

   Установка с mini ISO упала в debug shell («failed to determine size
   reservation for memmap») при 8 ГБ: образ целиком в RAM. С 18 ГБ пошла
   (пользователь, 2026-09-29).

   Перенос выполнен 2026-09-29: `ws check virt` без FAIL, `ubuntu-test`
   запускается с перенесёнными NVRAM и TPM; старые каталоги —
   `*.before-vms-20260929-*`, удалить после перезагрузки host.

   Проверено 2026-09-29: `ubuntu-test` (mini ISO 26.04) ставится и
   загружается, NAT (DHCP), SSH с host, qemu-guest-agent, буфер обмена и
   подгонка экрана (spice-vdagent).

   Snapshots: libvirt 12 не делает внутренний snapshot VM с UEFI, пока
   NVRAM в raw («internal snapshots of a VM with pflash based firmware
   require QCOW2 nvram format»), а сам переводить шаблон raw в qcow2 не
   умеет («conversion of the nvram template to another target format is
   not supported»); qcow2-сборок OVMF в Ubuntu нет. С NVRAM, заранее
   переведённой `qemu-img convert -O qcow2` (код прошивки остаётся raw),
   проверено на временной VM: snapshot работающей и выключенной VM, откат к
   обоим, snapshot ложится и в диск, и в NVRAM. Решение (пользователь,
   2026-09-29): новые VM сразу с NVRAM в qcow2 — шаблон на `@vms/firmware`
   (`bootstrap.sh`), описание прошивки в `/etc/qemu/firmware` (системный
   слой); `ubuntu-test` перевести вручную (`helpws virt`, «Snapshots»).
   Сделано 2026-09-29: новая VM (`virt-install --boot uefi`) получает
   `NAME_VARS.qcow2` сама; `ubuntu-test` переведена, snapshot работающей VM
   (с TPM) и откат: файл, созданный после snapshot, пропал, гость вернулся в
   память на момент snapshot (~5 с).

   Проверить:
   - после перезагрузки host bind-монтирования на месте до старта libvirt;
     откат `@` не трогает VM;
   - USB redirect (флешка), virtiofs-папка;
   - suspend host с запущенной VM и resume (T2: `helpws suspend`);
   - перезагрузка host: пул и сеть поднимаются сами.
5. Документация по итогам: `helpws virt` — проверенные настройки и
   ограничения; план — в `history/`.

## DONE WHEN

- `ws check virt` без FAIL и WARN;
- `virt-manager` открывается и управляет VM без ручной настройки;
- тестовая UEFI VM ставится, загружается, откатывается к snapshot;
- suspend host с работающей VM проходит;
- состояние VM целиком на `@vms` (`ws check virt`), `ws collect` сохраняет
  описания, NVRAM и TPM, для дисков есть backup (`plan-final`).
