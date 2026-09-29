title: ws-virt
section: 1
date: 2026-09-28
source: Workstation
volume: User Commands

# VIRTUAL MACHINES — KVM / LIBVIRT / VIRT-MANAGER

VM работают на host: KVM, QEMU и libvirt связаны с ядром, устройствами и
сетью, в контейнер их не унести. Управление — `virt-manager`, подключение —
`qemu:///system`. План и что ещё не проверено: `helpws plan-virt`.

## Что где

```text
nix/hosts/apt.txt           qemu, libvirt, virt-manager, SPICE, OVMF, swtpm, virtiofsd
bootstrap.sh, шаг 3         @vms и bind-монтирования, пул и сеть default, группа libvirt
virt/virt.nix               ~/VMs -> /var/lib/libvirt/images
bin/ws-check-virt           ws check virt
```

Всё состояние VM — на subvolume `@vms` (смонтирован в `/var/lib/vms`),
libvirt видит его на своих путях через bind-монтирования (fstab):

```text
@vms/images  /var/lib/libvirt/images  диски и ISO: без copy-on-write,
                                      root:libvirt 2775, пул «default»
@vms/qemu    /var/lib/libvirt/qemu    переменные UEFI (nvram/), метаданные
                                      snapshots, сохранённые состояния
@vms/swtpm   /var/lib/libvirt/swtpm   состояние TPM каждой VM
@vms/xml     /etc/libvirt/qemu        описания VM и сетей, autostart
@vms/firmware                         шаблон переменных UEFI в qcow2
~/VMs                                 ссылка на /var/lib/libvirt/images
virbr0, 192.168.122.0/24              NAT-сеть «default»
```

`@vms` не входит в snapshots `@`: откат `@` не трогает ни диски, ни
описания, ни UEFI и TPM, а snapshots не раздуваются. Если откатить `@` на
состояние до `@vms` (без его строк в fstab), libvirt увидит старые пустые
каталоги `@` — VM не пропадут, вернутся с `bootstrap.sh`. Без
copy-on-write у образов нет контрольных сумм Btrfs и сжатия — обычная цена
за qcow2 без фрагментации.

Переустановка `@vms` не сохраняет: диски — backup `@vms`
(`helpws plan-final`), описания, NVRAM и TPM — ещё и `ws collect`
(`virt/`), вернуть — `virsh -c qemu:///system define FILE`, NVRAM и
`swtpm/` на прежние пути. Кэш DHCP (`/var/lib/libvirt/dnsmasq`) остаётся на
`@`: он пересоздаётся.

`~/VMs` — только для рук: класть ISO, смотреть файлы. VM должна получать
пути пула (`/var/lib/libvirt/images/…`, в virt-manager — «Browse» → пул
`default`): путь через `~/VMs` qemu не откроет (у него нет доступа в HOME,
AppArmor разрешает пути пула). virt-manager заводит пул на каждый каталог,
открытый через «Browse Local»; пул в HOME `ws check virt` отмечает WARN —
убрать: `virsh -c qemu:///system pool-destroy NAME` и `pool-undefine NAME`
(файлы остаются).

## Сеть

Только NAT (`default`, virbr0): host ходит к гостю по его IP, гость — в сеть
через host. Мост (bridge) не используется: Wi-Fi не мостится на L2, а
проводной сети у машины нет.

## Создать VM

`virt-manager` → «Create a new virtual machine»: ISO из пула `default`
(`iso/`, кладётся через `~/VMs/iso/`), диск — в пуле `default`. То же
командой (так создана `ubuntu-test`):

```console
virt-install --connect qemu:///system --name NAME --osinfo ubuntu25.10 \
  --memory 8192 --vcpus 4 --cpu host-passthrough --boot uefi \
  --disk size=40,format=qcow2,bus=virtio,pool=default \
  --network network=default,model=virtio --graphics spice --video virtio \
  --cdrom /var/lib/libvirt/images/iso/FILE.iso --noautoconsole
```

Получается:

```text
машина      q35, host-passthrough
прошивка    OVMF Secure Boot с ключами Microsoft (OVMF_CODE_4M.ms.fd) и TPM
            (tpm-crb, swtpm): osinfo Ubuntu выбирает их сам
диск        qcow2 virtio, разреженный, без CoW (атрибут C от каталога)
сеть        default (NAT), virtio
экран       SPICE, virtio-gpu, канал spice-vdagent
```

В osinfo Ubuntu 26.04 пока нет — ближайший `ubuntu25.10`. Размеры (4 vCPU,
8 ГБ, 40 ГБ) — наши; host: 12 потоков, 32 ГБ.

Mini ISO (`*-mini-iso-*`) скачивает полный образ и держит его в RAM: с 8 ГБ
установка падает в debug shell («failed to determine size reservation for
memmap»). На время установки — 16 ГБ и больше (`ubuntu-test` ставилась с
18 ГБ), потом память можно вернуть. Полный ISO этого не требует.

## Snapshots

Внутренние snapshots qcow2 (virt-manager → «Manage VM snapshots», `virsh
snapshot-create-as`) — и работающей VM (с памятью), и выключенной; откат —
`snapshot-revert`. Для VM с UEFI libvirt требует переменные UEFI (NVRAM) в
qcow2, а шаблон пакета `ovmf` — raw, и переводить его libvirt не умеет.
Поэтому:

```text
/var/lib/vms/firmware/OVMF_VARS_4M.ms.qcow2      шаблон в qcow2 (bootstrap.sh)
/etc/qemu/firmware/30-...-qcow2-vars.json        описание прошивки: код пакета
                                                 raw, шаблон qcow2; приоритет
                                                 выше пакетных (ws system apply)
```

Новая VM с `--boot uefi` (virt-manager — тоже) получает NVRAM
`NAME_VARS.qcow2` сама. VM, созданная раньше, — перевести один раз
(выключенной):

```console
n=/var/lib/libvirt/qemu/nvram/NAME_VARS
sudo qemu-img convert -f raw -O qcow2 $n.fd $n.qcow2
virsh -c qemu:///system dumpxml --inactive NAME > /tmp/NAME.xml
# строка <nvram>: template=/var/lib/vms/firmware/OVMF_VARS_4M.ms.qcow2,
# templateFormat='qcow2', format='qcow2', путь $n.qcow2
virsh -c qemu:///system define /tmp/NAME.xml
```

`ws check virt` отмечает WARN у VM с NVRAM в raw и проверяет, что шаблон
совпадает с пакетным (после обновления `ovmf` — снова `bootstrap.sh`).

## Устройства

Общая папка с host — virtiofs («Add Hardware → Filesystem», в госте
`mount -t virtiofs TAG /mnt`); нужна «Shared memory» в памяти VM.

USB-устройство в гостя — «Redirect USB device» в консоли (SPICE).

## Windows (заложено, не сделано)

Для Windows 11 есть всё на стороне host: OVMF с Secure Boot и ключами
Microsoft (`OVMF_CODE_4M.secboot.fd`, `OVMF_VARS_4M.ms.fd`) и эмуляция TPM
(`swtpm`). Понадобятся ещё ISO драйверов virtio-win (в Ubuntu его нет,
скачивается с fedorapeople) и 8 ГБ+ памяти. Сама VM в план не входит.

## Проброс GPU

Не делается: в «Ubuntu» AMD снята с шины, после выключения она не
возвращается в D0 (`helpws suspend`), а Intel — единственный экран host.

## Команды

```console
virt-manager
virsh -c qemu:///system list --all
virsh -c qemu:///system start|shutdown|destroy NAME
ws check virt
```

## Проверка

`ws check virt`: KVM, `virt-host-validate` без FAIL, пользователь в
`libvirt`, `qemu:///system` доступен, `@vms` смонтирован без CoW, пул и сеть
`default` запущены с автозапуском, OVMF и swtpm на месте, шаблон NVRAM в
qcow2 совпадает с пакетным, у каждой VM NVRAM в qcow2.
