#!/usr/bin/env python3
"""Homelab management CLI."""

import argparse
import re
import socket
import subprocess
import sys
import time
from pathlib import Path


def get_lan_ip() -> str | None:
    """Get the Mac's LAN IP address."""
    # Method 1: Try ipconfig (macOS specific)
    for interface in ["en0", "en1"]:
        try:
            result = subprocess.run(
                ["ipconfig", "getifaddr", interface],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except FileNotFoundError:
            pass

    # Method 2: Socket connection trick (cross-platform)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        pass

    return None


def get_homelab_dir() -> Path:
    """Get the homelab directory path."""
    return Path(__file__).parent.parent


def cmd_ip(args: argparse.Namespace) -> int:
    """Print LAN IP address."""
    ip = get_lan_ip()
    if ip:
        print(ip)
        return 0
    else:
        print("Error: Could not detect LAN IP", file=sys.stderr)
        return 1


def cmd_dns(args: argparse.Namespace) -> int:
    """Show Pi-hole Local DNS setup instructions."""
    ip = get_lan_ip()
    if not ip:
        print("Error: Could not detect LAN IP", file=sys.stderr)
        return 1

    domains = [
        "ha.home.local",
        "pihole.home.local",
        "portainer.home.local",
        "uptime.home.local",
        "home.home.local",
    ]

    print()
    print("=" * 66)
    print("                   Pi-hole Local DNS Setup")
    print("=" * 66)
    print()
    print(f"  Your LAN IP: {ip}")
    print()
    print("  1. Open Pi-hole Admin: http://localhost:8080/admin")
    print()
    print("  2. Go to: Local DNS -> DNS Records")
    print()
    print("  3. Add these entries:")
    print()
    print(f"     {'Domain':<28} IP")
    print("     " + "-" * 45)
    for domain in domains:
        print(f"     {domain:<28} {ip}")
    print()
    print("  4. Set your Mac's DNS to 127.0.0.1:")
    print("     System Settings -> Network -> [Your Network] ->")
    print("     Details -> DNS -> Add 127.0.0.1")
    print()
    print("  5. For other devices on your network:")
    print(f"     Set their DNS server to: {ip}")
    print("     (Or configure your router's DHCP to use Pi-hole)")
    print()
    print("=" * 66)
    print()
    return 0


def cmd_tunnel(args: argparse.Namespace) -> int:
    """Start Cloudflare tunnel and show URL."""
    homelab_dir = get_homelab_dir()
    env_file = homelab_dir / ".env"

    # Check for tunnel token
    tunnel_domain = None
    has_token = False

    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if (
                    line.startswith("CLOUDFLARE_TUNNEL_TOKEN=")
                    and line.split("=", 1)[1]
                ):
                    has_token = True
                if line.startswith("TUNNEL_DOMAIN="):
                    tunnel_domain = line.split("=", 1)[1]

    if not has_token:
        print("=" * 66)
        print("               Cloudflare Tunnel Setup Required")
        print("=" * 66)
        print()
        print("  To use the tunnel, you need to:")
        print()
        print("  1. Go to: https://one.dash.cloudflare.com/")
        print("  2. Navigate to: Networks -> Tunnels -> Create a tunnel")
        print("  3. Choose 'Cloudflared' and give it a name (e.g., 'homelab')")
        print("  4. Copy the tunnel token (starts with 'eyJ...')")
        print("  5. Add to .env: CLOUDFLARE_TUNNEL_TOKEN=<your-token>")
        print()
        print("  6. In the Cloudflare dashboard, add a Public Hostname:")
        print(f"     - Domain: {tunnel_domain or 'home.yourdomain.com'}")
        print("     - Service: HTTP://caddy:80")
        print()
        print("=" * 66)
        return 1

    # Stop any existing tunnel container first
    print("Stopping existing tunnel (if any)...")
    subprocess.run(
        ["docker", "compose", "--profile", "tunnel", "down", "cloudflared"],
        cwd=homelab_dir,
        capture_output=True,
    )

    print("Starting Cloudflare tunnel...")
    print()

    # Start tunnel with profile
    result = subprocess.run(
        ["docker", "compose", "--profile", "tunnel", "up", "-d", "cloudflared"],
        cwd=homelab_dir,
    )

    if result.returncode != 0:
        return result.returncode

    # Wait for tunnel to connect
    print()
    print("Waiting for tunnel to connect...")

    connected = False
    for _ in range(15):
        time.sleep(2)
        result = subprocess.run(
            ["docker", "logs", "--tail", "20", "cloudflared"],
            capture_output=True,
            text=True,
            cwd=homelab_dir,
        )
        logs = result.stdout + result.stderr

        if "Registered tunnel connection" in logs or "Connection registered" in logs:
            connected = True
            break
        if "failed" in logs.lower() and "error" in logs.lower():
            print("Tunnel failed to connect. Check logs:")
            print("  docker logs cloudflared")
            return 1

    print()
    print("=" * 66)
    print("                  Cloudflare Tunnel Ready")
    print("=" * 66)
    print()
    if tunnel_domain:
        print(f"  Tunnel URL: https://{tunnel_domain}")
    else:
        print("  Tunnel connected! Check your Cloudflare dashboard for the URL.")
    print()
    print("  Access your homelab from anywhere!")
    print()
    print("  Stop tunnel: docker compose --profile tunnel down")
    print()
    print("=" * 66)
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    """Show status of all services."""
    homelab_dir = get_homelab_dir()

    result = subprocess.run(
        [
            "docker",
            "compose",
            "ps",
            "--format",
            "table {{.Name}}\t{{.Status}}\t{{.Ports}}",
        ],
        cwd=homelab_dir,
        capture_output=True,
        text=True,
    )

    print()
    print("Homelab Services Status")
    print("=" * 70)
    print(result.stdout)
    return 0


def cmd_up(args: argparse.Namespace) -> int:
    """Start all services."""
    homelab_dir = get_homelab_dir()

    cmd = ["docker", "compose", "up", "-d"]
    if args.service:
        cmd.append(args.service)

    result = subprocess.run(cmd, cwd=homelab_dir)
    return result.returncode


def cmd_down(args: argparse.Namespace) -> int:
    """Stop all services."""
    homelab_dir = get_homelab_dir()

    cmd = ["docker", "compose", "down"]
    if args.service:
        cmd.append(args.service)

    result = subprocess.run(cmd, cwd=homelab_dir)
    return result.returncode


def cmd_logs(args: argparse.Namespace) -> int:
    """Show logs for a service."""
    homelab_dir = get_homelab_dir()

    cmd = ["docker", "compose", "logs"]
    if args.follow:
        cmd.append("-f")
    if args.tail:
        cmd.extend(["--tail", str(args.tail)])
    if args.service:
        cmd.append(args.service)

    result = subprocess.run(cmd, cwd=homelab_dir)
    return result.returncode


def cmd_restart(args: argparse.Namespace) -> int:
    """Restart services."""
    homelab_dir = get_homelab_dir()

    cmd = ["docker", "compose", "restart"]
    if args.service:
        cmd.append(args.service)

    result = subprocess.run(cmd, cwd=homelab_dir)
    return result.returncode


def cmd_update(args: argparse.Namespace) -> int:
    """Pull latest images and restart services."""
    homelab_dir = get_homelab_dir()

    print("Pulling latest images...")
    pull_result = subprocess.run(["docker", "compose", "pull"], cwd=homelab_dir)
    if pull_result.returncode != 0:
        return pull_result.returncode

    print()
    print("Restarting services...")
    up_result = subprocess.run(["docker", "compose", "up", "-d"], cwd=homelab_dir)
    return up_result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Homelab management CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # ip
    ip_parser = subparsers.add_parser("ip", help="Get LAN IP address")
    ip_parser.set_defaults(func=cmd_ip)

    # dns
    dns_parser = subparsers.add_parser(
        "dns", help="Show Pi-hole DNS setup instructions"
    )
    dns_parser.set_defaults(func=cmd_dns)

    # tunnel
    tunnel_parser = subparsers.add_parser("tunnel", help="Start Cloudflare tunnel")
    tunnel_parser.set_defaults(func=cmd_tunnel)

    # status
    status_parser = subparsers.add_parser("status", help="Show status of all services")
    status_parser.set_defaults(func=cmd_status)

    # up
    up_parser = subparsers.add_parser("up", help="Start services")
    up_parser.add_argument("service", nargs="?", help="Specific service to start")
    up_parser.set_defaults(func=cmd_up)

    # down
    down_parser = subparsers.add_parser("down", help="Stop services")
    down_parser.add_argument("service", nargs="?", help="Specific service to stop")
    down_parser.set_defaults(func=cmd_down)

    # logs
    logs_parser = subparsers.add_parser("logs", help="Show service logs")
    logs_parser.add_argument("service", nargs="?", help="Specific service")
    logs_parser.add_argument("-f", "--follow", action="store_true", help="Follow logs")
    logs_parser.add_argument("-t", "--tail", type=int, help="Number of lines to show")
    logs_parser.set_defaults(func=cmd_logs)

    # restart
    restart_parser = subparsers.add_parser("restart", help="Restart services")
    restart_parser.add_argument(
        "service", nargs="?", help="Specific service to restart"
    )
    restart_parser.set_defaults(func=cmd_restart)

    # update
    update_parser = subparsers.add_parser(
        "update", help="Pull latest images and restart"
    )
    update_parser.set_defaults(func=cmd_update)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
