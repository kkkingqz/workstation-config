# Managed Flatpak overrides

This directory is the workstation source-of-truth for explicit per-app
overrides managed by `wsflatpak`.

Version 1 manages filesystem overrides. `wsflatpak host APP` records and
applies:

```ini
[Context]
filesystems=host;
```

A runtime `filesystem=host` override that is not represented here is a
policy failure in `wsflatpak check`.
