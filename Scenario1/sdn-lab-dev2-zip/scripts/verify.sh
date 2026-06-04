#!/usr/bin/env bash
# Vérifications rapides du lab (à lancer depuis sdn-lab-dev2-zip sur l'hôte)
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

echo "[+] Ping client1 -> client2 (via OSPF)"
run client1 "ping -c 3 -W 2 192.168.2.2"

echo "[+] Voisins OSPF router1"
run router1 "sudo vtysh -c 'show ip ospf neighbor'"

echo "[+] Voisins OSPF router2"
run router2 "sudo vtysh -c 'show ip ospf neighbor'"

echo "[+] Contrôleur : br0 et Ryu"
run controller "ip -4 addr show br0 | grep -q '10.10.10.10/'"
run controller "sudo ovs-vsctl br-exists br0 && sudo ovs-vsctl get-controller br0 | grep -q 6633"
run controller "pgrep -f ryu.cmd.manager >/dev/null && echo 'Ryu actif'"

echo "[✓] Vérifications terminées"
