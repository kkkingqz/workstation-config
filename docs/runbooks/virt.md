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
bootstrap.sh, шаг 3         @vms, пул и сеть default, группа libvirt
virt/virt.nix               ~/VMs -> /var/lib/libvirt/images
bin/ws-check-virt           ws check virt
```

```text
/var/lib/libvirt/images     диски и ISO: subvolume @vms, без copy-on-write,
                            root:libvirt 2775, пул libvirt «default»
~/VMs                       ссылка туда же
/etc/libvirt/qemu/*.xml     описания VM (libvirt, на @)
/var/lib/libvirt/qemu/nvram переменные UEFI каждой VM (на @)
virbr0, 192.168.122.0/24    NAT-сеть «default»
```

`@vms` не входит в snapshots `@`: откат `@` не трогает диски, snapshots не
раздуваются. Без copy-on-write у образов нет контрольных сумм Btrfs и
сжатия — обычная цена за qcow2 без фрагментации. Описания VM лежат на `@`;
их и NVRAM сохраняет `ws collect` (`virt/domain-*.xml`, `virt/nvram/`),
вернуть — `virsh -c qemu:///system define FILE` и NVRAM на прежний путь.

`~/VMs` — только для рук: класть ISO, смотреть файлы. VM должна получать
пути пула (`/var/lib/libvirt/images/…`, в virt-manager — «Browse» → пул
`default`): путь через `~/VMs` qemu не откроет (у него нет доступа в HOME,
AppArmor разрешает пути пула).

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
`default` запущены с автозапуском, OVMF и swtpm на месте, список VM.
