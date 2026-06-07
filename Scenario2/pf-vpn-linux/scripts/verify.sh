#!/usr/bin/env bash
# Vérifications du lab Scénario 2 (à lancer depuis pf-vpn-linux sur l'hôte)
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_DIR"

if ! command -v vagrant >/dev/null 2>&1; then
  echo "[!] vagrant introuvable"
  exit 1
fi

run() {
  local vm="$1"
  shift
  echo "==> $vm : $*"
  vagrant ssh "$vm" -c "$*" </dev/null
}

echo "[+] État des machines"
vagrant status

echo "[+] WireGuard siteB (handshake actif)"
run siteB "sudo wg show wg0 | grep -q 'latest handshake'"

echo "[+] Ping tunnel NVA (10.255.0.1)"
run siteB "ping -c 2 -W 2 10.255.0.1"

echo "[+] Ping inter-sites siteB -> siteA"
run siteB "ping -c 2 -W 2 192.168.10.3"

echo "[+] Ping inter-sites siteA -> siteB"
run siteA "ping -c 2 -W 2 192.168.20.3"

echo "[+] Policy routing NVA (table intersite)"
run nva "ip rule list | grep -q 'from 192.168.10.0/24 to 192.168.20.0/24 lookup intersite'"
run nva "ip route show table intersite | grep -q '192.168.20.0/24 dev wg0'"

echo "[+] OSPF siteA <-> NVA (Full sur enp0s8)"
run nva "sudo vtysh -c 'show ip ospf neighbor' | grep -q Full"

echo "[+] Prometheus actif (monitoring)"
run monitoring "systemctl is-active prometheus"

echo "[✓] Vérifications terminées"
