# Linux Local Setup

Run Gleiphnir on a local Linux machine and access it over localhost.

## Prerequisites

```bash
sudo apt-get install -y qemu-system-x86 qemu-utils cloud-utils \
  genisoimage iproute2 iptables libicu-dev

curl https://mise.run | sh && mise install
pip install pycdlib   # only if cloud-localds / genisoimage unavailable
```

### KVM acceleration

`/dev/kvm` must exist and be accessible:

```bash
ls -la /dev/kvm
```

If missing, enable VT-x/AMD-V in BIOS. Without KVM, set `QEMU_ACCEL=tcg` (slow).

## Deploy

```bash
cd Gleiphnir
mise run deps        # verify all dependencies
mise run up          # creates bridge+TAP, downloads image, starts VM, waits for SSH
```

On first run, `sudo` is needed for bridge/TAP creation (`network:up`).

## Connect (from same machine)

```bash
ssh -p 2222 admin@127.0.0.1        # via iptables DNAT
ssh admin@192.168.100.10            # direct via bridge (preserves real source IP)
```

## Create sandbox users

```bash
mise run user:add USER=alice KEY=~/.ssh/id_ed25519.pub
ssh -p 2222 alice@127.0.0.1    # pwsh sandbox
ssh alice@192.168.100.10        # same, via bridge
```

## Firewall (ufw inside the VM)

```bash
mise run fw:allow IP=127.0.0.1
mise run fw:enforce    # lock down to allow-list only
mise run fw:list
```

## Observability (optional)

Set `OBSERVABILITY_ENABLED=true` in `config/sandbox.env`, then:

```bash
mise run up
# Open http://localhost:3000 (admin / admin)
```

## Tear down

```bash
mise run down    # stops VM, removes bridge+TAP, stops observability
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `/dev/kvm` missing | Enable VT-x/AMD-V in BIOS, or set `QEMU_ACCEL=tcg` |
| Bridge fails | `sudo` required; check `/dev/net/tun` exists |
| SSH refused | `mise run vm:console` to watch boot |
| DNAT not working | `sudo iptables -t nat -L -n \| grep 2222` |
