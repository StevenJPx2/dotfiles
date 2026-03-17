# NUC Homelab Setup Guide

Complete step-by-step guide for setting up your NUC homelab from bare metal.

**Estimated time:** ~20 minutes (5 minutes hands-on, 15 minutes waiting for builds)

---

## 📋 Prerequisites

### Option A: Automated Setup (Recommended)

Run the interactive setup wizard:

```bash
just init
```

This will:
1. Check or generate SSH keys
2. Guide you through getting Tailscale auth key
3. Guide you through getting Cloudflare API token
4. Save secrets to `secrets/` directory
5. Update `nixos/installer/configuration.nix` with your SSH key
6. Validate everything is ready

**You'll need to visit:**
- https://login.tailscale.com/admin/settings/keys (for auth key)
- https://dash.cloudflare.com/profile/api-tokens (for API token)

---

### Option B: Manual Setup

#### 1. SSH Public Key

```bash
cat ~/.ssh/id_ed25519.pub
```

If you don't have one:
```bash
ssh-keygen -t ed25519 -C "steven@macbook"
```

#### 2. Tailscale Auth Key

1. https://login.tailscale.com/admin/settings/keys
2. Click **"Generate auth key..."**
3. Settings:
   - **Reusable:** Yes
   - **Ephemeral:** No
   - **Expiry:** 90 days
4. Copy key (starts with `tskey-auth-`)
5. Save:

```bash
mkdir -p homelab/secrets
echo "tskey-auth-YOUR_KEY" > homelab/secrets/tailscale-authkey
```

#### 3. Cloudflare API Token

1. https://dash.cloudflare.com/profile/api-tokens
2. Click **"Create Token"**
3. Use **"Edit zone DNS"** template
4. Zone: `stevenjohn.co`
5. Copy token
6. Save:

```bash
echo "YOUR_TOKEN" > homelab/secrets/cloudflare-token
```

#### 4. Update Installer Config

Edit `homelab/nixos/installer/configuration.nix` and replace the placeholder SSH key with yours.

---

## 🚀 Installation

### Step 1: Build Custom Installer ISO

```bash
just nuc-build-iso
```

**Time:** ~5-10 minutes

### Step 2: Flash ISO to USB

Find your USB:
```bash
diskutil list
```

Flash it:
```bash
just nuc-flash-iso disk4  # Replace with your device
```

**Time:** ~2-5 minutes

### Step 3: Boot the NUC

1. Plug USB into NUC
2. Power on, press **F10** for boot menu
3. Select USB drive
4. Wait ~1-2 minutes for SSH

Find the NUC's IP:
```bash
nmap -p 22 192.168.1.0/24 | grep -B5 "open"
```

### Step 4: Install NixOS

```bash
just nuc-install 192.168.1.50
```

**What happens:**
1. SSH into installer
2. Disko partitions the disk (512MB EFI, 8GB swap, rest ext4)
3. Installs complete NixOS system
4. Reboots automatically

**Time:** ~10-15 minutes

**Note:** NUC will reboot when done (SSH disconnects — this is normal).

### Step 5: Post-Installation Setup

Wait ~2 minutes, then:

```bash
ssh steven@nuc
sudo -i

# Run setup with your secrets
export CF_API_TOKEN=$(cat /home/steven/homelab/secrets/cloudflare-token)
export TAILSCALE_AUTHKEY=$(cat /home/steven/homelab/secrets/tailscale-authkey)
./scripts/setup.sh
```

**What the setup does:**
1. Authenticates Tailscale
2. Creates Cloudflare DNS records
3. Downloads and sets up HAOS VM
4. Displays HAOS IP

**Time:** ~5 minutes

**Note the HAOS IP** from output (e.g., `192.168.1.55`).

### Step 6: Finalize Configuration

On your Mac, update configs:

```bash
vim homelab/nixos/services/caddy.nix
# Replace HAOS_VM_IP with actual IP

vim homelab/nixos/services/homepage.nix
# Update Home Assistant widget URL

just deploy
```

---

## ✅ Verify Installation

Check all services:

```bash
just nuc-status
```

Expected output:
```
=== NixOS Native Services ===
[RUNNING] caddy
[RUNNING] immich-server
[RUNNING] pihole-ftl
[RUNNING] uptime-kuma
[RUNNING] homepage-dashboard

=== Docker Containers ===
super-productivity  Up 5 minutes
watchtower          Up 5 minutes

=== Incus VMs ===
| haos | RUNNING | 192.168.1.55 (eth0) | VIRTUAL-MACHINE |
```

---

## 🌐 Access Your Services

| Service | URL | First-Time Setup |
|---------|-----|------------------|
| Dashboard | https://home.stevenjohn.co | Overview page |
| Home Assistant | https://ha.home.stevenjohn.co | Create account |
| Photos | https://photos.home.stevenjohn.co | Create admin |
| DNS | https://dns.home.stevenjohn.co | Set password |
| Monitoring | https://status.home.stevenjohn.co | Create account |
| Tasks | https://tasks.home.stevenjohn.co | Ready to use |

---

## 🔐 Add API Keys to Homepage

For dashboard widgets:

```bash
ssh steven@nuc
sudo -i

cat > /etc/homepage-secrets <<EOF
HOMEPAGE_VAR_HA_TOKEN=your_ha_token
HOMEPAGE_VAR_IMMICH_KEY=your_immich_key
EOF

chmod 600 /etc/homepage-secrets
systemctl restart homepage-dashboard
```

Get tokens from:
- **HA**: Profile → Long-Lived Access Tokens
- **Immich**: Administration → API Keys

---

## 🔄 Day-to-Day Operations

```bash
just deploy              # Push config changes
just deploy-dry          # Preview changes
just deploy-test         # Test (non-persistent)
just nuc-status          # Check services
just nuc-diff            # Show config diff
```

---

## 🧩 Modular Commands (Advanced)

The setup is now modular. You can run individual steps:

```bash
# On the NUC:
./scripts/cmd/setup-tailscale.sh   # Just Tailscale
./scripts/cmd/setup-dns.sh         # Just DNS records
./scripts/cmd/setup-haos.sh        # Just HAOS VM
./scripts/cmd/status.sh            # Just check status
```

Or use the dispatcher:
```bash
./scripts/setup.sh all        # All steps (default)
./scripts/setup.sh tailscale  # Tailscale only
./scripts/setup.sh dns        # DNS only
./scripts/setup.sh haos       # HAOS only
```

---

## 🆘 Recovery / Reinstall

If something goes wrong:

```bash
# Boot from USB again
just nuc-install <IP>

# SSH in and run setup
ssh steven@nuc
sudo /home/steven/homelab/scripts/setup.sh
```

**Data preserved:**
- Immich photos: `/var/lib/immich/media`
- Super Productivity: `/var/lib/super-productivity`
- HAOS VM: In Incus storage

---

## 🐛 Troubleshooting

### Quick Help
```bash
just nuc-help
```

### Common Issues

**Can't SSH to Installer**
```bash
nmap -p 22 192.168.1.0/24 | grep -B5 "open"
```

**nixos-anywhere Fails**
```bash
ssh root@<NUC_IP>  # Test connectivity
cd homelab && nix run .#install -- <IP> --debug
```

**DNS Not Resolving**
```bash
# Should return Tailscale IP (100.x.y.z), not LAN IP
dig home.stevenjohn.co
```

**HAOS VM Won't Start**
```bash
incus list
incus info haos
incus console haos --type=vga  # View console
journalctl -u incus -f          # Watch logs
```

**Caddy HTTPS Errors**
```bash
cat /etc/caddy-env
journalctl -u caddy -f
```

---

## 📁 New Project Structure

```
homelab/
├── nixos/                 # NixOS configurations
│   ├── installer/         # ⭐ Custom NixOS installer ISO
│   │   ├── configuration.nix
│   │   ├── disko.nix
│   │   └── flake.nix
│   ├── services/          # ⭐ All service modules
│   │   ├── caddy.nix
│   │   ├── immich.nix
│   │   ├── pihole.nix
│   │   └── [...]
│   ├── homelab.nix
│   └── tailscale.nix
├── scripts/               # Shell automation
│   ├── lib/
│   ├── cmd/
│   └── [main scripts]
└── [...other files]
```

**Benefits:**
- ✅ All shell scripts in one place (`scripts/`)
- ✅ NixOS configs separate (`nixos/`)
- ✅ Installer is part of NixOS (`nixos/installer/`)
- ✅ No code duplication (shared libraries)
- ✅ Can run individual setup steps
- ✅ Easy to extend and maintain

---

## 🎉 You're Done!

Your homelab now has:
- ✅ NixOS with declarative configuration
- ✅ 7 self-hosted services
- ✅ Real HTTPS certificates
- ✅ Tailscale-only secure access
- ✅ Automated 15-minute reinstall
- ✅ Modular, maintainable scripts

Enjoy your homelab! 🏠🖥️
