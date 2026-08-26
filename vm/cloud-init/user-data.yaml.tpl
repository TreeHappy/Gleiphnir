#cloud-config
hostname: __VM_HOSTNAME__
manage_etc_hosts: true

users:
  - name: __ADMIN_USER__
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [adm, sudo]
    shell: /bin/bash
    ssh_authorized_keys:
      - __ADMIN_SSH_PUB__

package_update: true
packages:
  - podman
  - ufw
  - uidmap
  - slirp4netns
  - fuse-overlayfs
  - openssh-server
  - qemu-guest-agent
  - cloud-guest-utils
  - ca-certificates
  - curl
  - unzip
  - git
  - jq
  - prometheus-node-exporter
  - mitmproxy

# ── storage: dedicated data disk at /srv/sandbox ──────────────────────────
disk_setup:
  /dev/vdb:
    table_type: gpt
    layout: true
    overwrite: false

fs_setup:
  - label: sandbox_data
    filesystem: ext4
    device: /dev/vdb
    partition: auto

mounts:
  - [/dev/vdb, /srv/sandbox, ext4, "defaults", "0", "2"]

write_files:
  # sandbox-shell (login shell → podman container)
  - path: /usr/local/bin/sandbox-shell
    permissions: '0755'
    content: |
__SANDBOX_SHELL_CONTENT__

  # sandbox-user
  - path: /usr/local/bin/sandbox-user
    permissions: '0755'
    content: |
__SANDBOX_USER_CONTENT__

  # sandbox-firewall (with ingress/egress)
  - path: /usr/local/bin/sandbox-firewall
    permissions: '0755'
    content: |
__SANDBOX_FIREWALL_CONTENT__

  # sandbox-policy (sbx parity: presets + domain/IP allow/deny, via proxy + ufw)
  - path: /usr/local/bin/sandbox-policy
    permissions: '0755'
    content: |
__SANDBOX_POLICY_CONTENT__

  # policy presets (balanced/open/locked)
  - path: /etc/sandbox/policy-presets/balanced.txt
    permissions: '0644'
    content: |
__POLICY_BALANCED_CONTENT__

  - path: /etc/sandbox/policy-presets/open.txt
    permissions: '0644'
    content: |
__POLICY_OPEN_CONTENT__

  - path: /etc/sandbox/policy-presets/locked.txt
    permissions: '0644'
    content: |
__POLICY_LOCKED_CONTENT__

  # build-container helper
  - path: /usr/local/lib/sandbox/build-container.sh
    permissions: '0755'
    content: |
__BUILD_CONTAINER_CONTENT__

  # container sources (used to build localhost/sandbox:latest)
  - path: /opt/sandbox/container/Containerfile
    permissions: '0644'
    content: |
__CONTAINERFILE_CONTENT__

  - path: /opt/sandbox/container/entrypoint.sh
    permissions: '0755'
    content: |
__ENTRYPOINT_CONTENT__

  - path: /opt/sandbox/container/files/mise.toml
    permissions: '0644'
    content: |
__MISE_TOML_CONTENT__

  # container dotfiles (deployed by the mise `dotfiles` task inside containers)
  - path: /opt/sandbox/container/files/dotfiles/bashrc
    permissions: '0644'
    content: |
__BASHRC_CONTENT__

  - path: /opt/sandbox/container/files/dotfiles/profile.ps1
    permissions: '0644'
    content: |
__PROFILE_PS1_CONTENT__

  - path: /opt/sandbox/container/files/dotfiles/gitconfig
    permissions: '0644'
    content: |
__GITCONFIG_CONTENT__

  - path: /opt/sandbox/container/files/dotfiles/gitignore_global
    permissions: '0644'
    content: |
__GITIGNORE_GLOBAL_CONTENT__

  - path: /opt/sandbox/container/files/dotfiles/inputrc
    permissions: '0644'
    content: |
__INPUTRC_CONTENT__

  - path: /opt/sandbox/container/files/dotfiles/editorconfig
    permissions: '0644'
    content: |
__EDITORCONFIG_CONTENT__

  # pwsh launcher (bash script that resolves the mise-installed pwsh)
  - path: /opt/sandbox/container/files/start-pwsh.sh
    permissions: '0755'
    content: |
__START_PWSH_CONTENT__

  # fenrir CLI (in-container, delegates to gdu/yazi)
  - path: /opt/sandbox/container/files/fenrir
    permissions: '0755'
    content: |
__FENRIR_CONTENT__

  # gleiphnir CLI (wraps mise tasks, alias gle)
  - path: /opt/sandbox/container/files/gleiphnir
    permissions: '0755'
    content: |
__GLEIPHNIR_CONTENT__

  # carapace spec for fenrir (fen) — gleiphnir spec is host-only (vm/files/...), not in container
  - path: /opt/sandbox/container/files/carapace/specs/fenrir.yaml
    permissions: '0644'
    content: |
__FENRIR_SPEC_CONTENT__

  # ── observability: session logger, HTTP proxy, OTel config ─────────────
  # session-logger (PTY wrapper for keystroke capture)
  - path: /usr/local/bin/sandbox-session-logger
    permissions: '0755'
    content: |
__SESSION_LOGGER_CONTENT__

  # HTTP proxy (mitmproxy wrapper for traffic capture)
  - path: /usr/local/bin/sandbox-proxy
    permissions: '0755'
    content: |
__SANDBOX_PROXY_CONTENT__

  # secrets management (admin-only CLI for listing/setting secrets)
  - path: /usr/local/bin/sandbox-secrets
    permissions: '0755'
    content: |
__SANDBOX_SECRETS_CONTENT__

  # journal query tool (journalctl-style for agent command history)
  - path: /usr/local/bin/sandbox-journal
    permissions: '0755'
    content: |
__SANDBOX_JOURNAL_CONTENT__

  # SBOM generator (container image + mise tools + VM apt packages)
  - path: /usr/local/bin/sandbox-sbom
    permissions: '0755'
    content: |
__SANDBOX_SBOM_CONTENT__

  # Volume inspection tool (mise tool installs + disk usage)
  - path: /usr/local/bin/sandbox-tools
    permissions: '0755'
    content: |
__SANDBOX_TOOLS_CONTENT__

  # Fenrir CLI on VM (and alias fen)
  - path: /usr/local/bin/fenrir
    permissions: '0755'
    content: |
__FENRIR_CONTENT__

  # Gleiphnir CLI on VM/host (and alias gle) — wraps mise tasks
  - path: /usr/local/bin/gleiphnir
    permissions: '0755'
    content: |
__GLEIPHNIR_CONTENT__

  # OTel Collector config (deployed by deploy-observability.ps1 at runtime)
  # Placeholder — actual config is deployed via SSH after VM boot

  # sshd hardening — ForceCommand for sandbox users via Match blocks (appended later)
  - path: /etc/ssh/sshd_config.d/99-gleiphnir.conf
    permissions: '0644'
    content: |
      # Gleiphnir: restrict sandbox users to container shell
      # Admin user keeps normal shell; sandbox users are forced via their login shell + this Match.
      # Note: sandbox-shell is already their shell; this just hardens tunneling/port forwarding.
      Match User *,!__ADMIN_USER__,!root
        AllowTcpForwarding no
        X11Forwarding no
        PermitTunnel no
        # ForceCommand not set globally here — login shell already enforces container.
        # If you need absolute lockdown, uncomment:
        # ForceCommand /usr/local/bin/sandbox-shell

  # systemd unit to build container image on first boot (and on demand)
  - path: /etc/systemd/system/sandbox-container-build.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Build Gleiphnir sandbox container image (podman)
      After=network-online.target
      Wants=network-online.target
      ConditionPathExists=!/var/lib/sandbox/container-built

      [Service]
      Type=oneshot
      ExecStart=/usr/local/lib/sandbox/build-container.sh
      ExecStartPost=/bin/touch /var/lib/sandbox/container-built
      RemainAfterExit=yes
      TimeoutStartSec=600

      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir -p /srv/sandbox
  - chmod 755 /srv/sandbox
  - mkdir -p /var/lib/sandbox
  - mkdir -p /var/log/sandbox
  - chmod 1777 /var/log/sandbox
  - mkdir -p /etc/sandbox/policy-presets
  - chmod 755 /etc/sandbox/policy-presets
  - echo "Initializing balanced policy preset..." && (sudo /usr/local/bin/sandbox-policy init balanced 2>&1 | tail -5 || true)
  # Ensure subuid/subgid exist for admin (needed for rootless podman even for admin itself)
  - grep -q "^__ADMIN_USER__:" /etc/subuid 2>/dev/null || echo "__ADMIN_USER__:100000:165536" >> /etc/subuid
  - grep -q "^__ADMIN_USER__:" /etc/subgid 2>/dev/null || echo "__ADMIN_USER__:100000:165536" >> /etc/subgid
  # Enable and apply the guest firewall (ufw).
  # Posture: default-deny incoming, tcp/22 open via a bootstrap rule so the
  # admin is never locked out. Tighten later with `sandbox-firewall enforce`.
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow from any to any port 22 proto tcp comment gleiphnir-bootstrap
  - systemctl enable ufw 2>/dev/null || true
  - ufw --force enable
  # Workaround: ensure podman storage is initialized for admin
  - sudo -u __ADMIN_USER__ podman info 2>&1 | head -20 || true
  # Build container image (also via systemd unit; do it now in cloud-init for faster readiness)
  - systemctl daemon-reload
  - systemctl enable sandbox-container-build.service
  - systemctl start sandbox-container-build.service 2>&1 | tail -50 || echo "container build (systemd) failed, will retry on next boot"
  # Fallback: if systemd condition prevented build (file exists but image missing), rebuild
  - podman image exists __CONTAINER_IMAGE__ || /usr/local/lib/sandbox/build-container.sh 2>&1 | tail -100 || true
  # Aliases fen → fenrir, gle → gleiphnir
  - ln -sfn /usr/local/bin/fenrir /usr/local/bin/fen
  - ln -sfn /usr/local/bin/gleiphnir /usr/local/bin/gle
  - ln -sfn /opt/sandbox/container/files/fenrir /usr/local/bin/container-fenrir 2>/dev/null || true
  # SSH: ensure password auth off, pubkey on
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || true
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null || true
  - systemctl restart sshd 2>&1 | tail -5 || systemctl restart ssh 2>&1 | tail -5 || true
  # Mark cloud-init done
  - echo "Gleiphnir VM ready at $(date)" > /var/lib/sandbox/ready
  - podman images 2>&1 | tee /var/log/sandbox-images.log || true
  - ufw status verbose 2>&1 | tee /var/log/ufw-status.log || true

  final_message: "Gleiphnir VM ready — SSH as __ADMIN_USER__, then: fenrir user add <name> (or gleiphnir user add); tighten with fenrir firewall allow <ip> + fenrir firewall enforce"
