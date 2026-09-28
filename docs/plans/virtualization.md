title: ws-plan-virt
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# PLAN — KVM / LIBVIRT

## Цель

Получить штатную host-level virtualization. В отличие от development SDK, KVM/libvirt остаются на host, потому что тесно связаны с kernel, devices и networking.

### 1. Установка

```bash
sudo apt install \
  qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients \
  virt-manager virt-viewer ovmf swtpm
```

Добавить пользователя:

```bash
sudo usermod -aG libvirt,kvm "$USER"
```

После logout/login:

```bash
ls -l /dev/kvm
sudo virt-host-validate
virsh -c qemu:///system list --all
```

### 2. Storage

Базовый каталог пользовательских VM:

```text
~/VMs
```

Перед созданием больших images определить:

- snapshot policy;
- backup policy;
- исключаются ли VM images из обычных root snapshots.

### 3. Firmware/security

Проверить:

- UEFI/OVMF;
- TPM через `swtpm`, если нужен Windows 11;
- NAT network;
- bridge — только если реально нужен L2 доступ.

### 4. GUI

Основной GUI:

```text
virt-manager
```

Проверить:

- create/start/stop VM;
- console;
- snapshots;
- USB passthrough;
- shared folders/network access по необходимости.

## DONE WHEN

- `virt-host-validate` без критических проблем;
- `virt-manager` подключается к `qemu:///system`;
- тестовая UEFI VM загружается;
- понятно, где хранятся и как backup'ятся VM.
