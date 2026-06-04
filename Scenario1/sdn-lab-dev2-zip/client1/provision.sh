#!/bin/bash
set -eux

echo "[+] Mise à jour du système"
sudo apt-get update -y
sudo apt-get install -y net-tools iproute2 iputils-ping traceroute

echo "[+] Configuration réseau avec Netplan"
cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: no
      addresses: [10.10.10.13/24]
    enp0s9:
      dhcp4: no
      addresses: [192.168.1.2/30]
      routes:
        - to: default
          via: 192.168.1.1
EOF

echo "[+] Application de la configuration Netplan"
sudo netplan apply

echo "[+] Suppression des routes par défaut en NAT"
sudo ip route del default via 10.0.2.2 || true

echo "[✓] Client1 prêt avec une route par défaut vers 192.168.1.1"
ip route
