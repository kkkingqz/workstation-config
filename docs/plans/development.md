title: ws-plan-dev
section: 1
date: 2026-09-21
source: Workstation
volume: User Commands

# PLAN — DISTROBOX DEVELOPMENT

## Цель

Создать постоянный development слой без Python/Node/Rust/SDK clutter на Ubuntu host.

Distrobox/Podman уже доказали работоспособность во время сборки `react-drm`; теперь нужно оформить это как постоянную архитектуру.

# 1. Host infrastructure

На host допускаются только container integration packages:

```bash
sudo apt install podman distrobox uidmap fuse-overlayfs slirp4netns passt
```

Проверить rootless setup:

```bash
podman info --format '{{.Host.Security.Rootless}}'
grep "^$USER:" /etc/subuid /etc/subgid
```

---

# 2. Основной dev box

Создать отдельный HOME:

```bash
mkdir -p ~/.local/share/distrobox-homes/dev
```

Создать box:

```bash
distrobox create \
  --name dev \
  --image docker.io/library/ubuntu:26.04 \
  --home "$HOME/.local/share/distrobox-homes/dev"
```

Назначение:

- Git;
- compilers;
- CMake/Ninja;
- Python/uv;
- Node;
- Rust;
- debugger/toolchain utilities.

---

# 3. Базовые packages внутри dev

Внутри box:

```bash
sudo apt update
sudo apt install \
  build-essential git curl wget ca-certificates \
  pkg-config cmake ninja-build clang lldb gdb \
  python3 python3-venv fish
```

Node/Rust добавлять только если реально нужны проектам.

---

# 4. Python / uv

`uv` ставить **в dev box**, не в host.

Принцип:

```text
dev box
  └── project
      └── .venv / uv-managed Python
```

Для каждого Python проекта:

- собственный Python pin;
- project-local dependencies;
- никаких глобальных `pip install --user` на host.

---

# 5. VS Code

Если выбираем VS Code как основной IDE:

1. установить его внутри `dev`;
2. проверить Wayland;
3. экспортировать desktop entry:
   ```bash
   distrobox-export --app code
   ```
4. проекты хранить на host, например:
   ```text
   ~/Projects
   ```
5. toolchain остаётся внутри box.

---

# 6. Specialized boxes

Не создавать заранее всё возможное.

Создавать по потребности:

```text
dev        → generic development
python-ai  → AI / PyTorch / ComfyUI tooling
legacy     → старый userspace
net-tools  → специальные network utilities
```

Для тяжёлых boxes использовать отдельный custom HOME.

---

# 7. Lifecycle

Для каждого box должно быть понятно:

- зачем он нужен;
- где его HOME;
- какие projects он использует;
- можно ли его удалить целиком без повреждения host.

Периодически:

```bash
distrobox list
podman ps -a
podman images
```

Удалять abandoned boxes и unused images осознанно.

---

# 8. Host boundary

На host **не ставить без необходимости**:

- project Python versions;
- pipx;
- Rust toolchains;
- Node version managers;
- random SDKs;
- project compilers.

Исключения — только tools, тесно связанные с kernel/hardware/desktop/virtualization.

---

# DONE WHEN

- есть один рабочий `dev` box;
- Python/uv project работает внутри него;
- compiler stack работает;
- IDE запускается как desktop app;
- Projects доступны без копирования;
- удаление box не ломает Ubuntu host.
