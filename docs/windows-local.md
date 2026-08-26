# Windows Local Setup

Run Gleiphnir on a local Windows machine and access it over localhost.

## Prerequisites

```powershell
winget install Microsoft.PowerShell
winget install jdx.mise
winget install Git.Git
winget install Python.Python.3.12
pip install pycdlib
```

QEMU for Windows — download from <https://qemu.weilnetz.de/> and add `qemu-system-x86_64` to `PATH`.

### Enable WHPX (recommended)

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# Reboot required
```

Or set `QEMU_ACCEL=tcg` for slow emulation without WHPX.

## Deploy

```powershell
cd Gleiphnir
mise install
mise run deps
mise run up
```

On Windows: user-mode NAT, zero host changes, no `sudo` needed.

## Connect (from same machine)

```powershell
ssh -p 2222 admin@127.0.0.1
```

## Create sandbox users

```powershell
mise run user:add USER=alice KEY=~/.ssh/id_ed25519.pub
ssh -p 2222 alice@127.0.0.1    # pwsh sandbox
```

## Observability (optional)

Set `OBSERVABILITY_ENABLED=true` in `config/sandbox.env`, then:

```powershell
mise run up
# Open http://localhost:3000 (admin / admin)
```

## Tear down

```powershell
mise run down
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| WHPX not available | Enable virtualization in BIOS, or set `QEMU_ACCEL=tcg` |
| SSH refused | `mise run vm:console` to watch boot |
| Port conflict | Change `HOST_SSH_FORWARD_PORT` in `config/sandbox.env` |
