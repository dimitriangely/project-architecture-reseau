#!/bin/bash
# Policy routing NVA : flux inter-sites LAN <-> WAN uniquement via wg0
set -eu
ACTION="${1:-up}"
RT=100
TABLE=intersite

grep -q "^${RT}[[:space:]]\\+${TABLE}" /etc/iproute2/rt_tables 2>/dev/null || \
  echo "${RT} ${TABLE}" >> /etc/iproute2/rt_tables

if [ "$ACTION" = up ]; then
  ip route replace 192.168.20.0/24 dev wg0 table "${TABLE}"

  # Underlay WireGuard : endpoint peer hors tunnel (plus spécifique que 192.168.20.0/24 dev wg0)
  ip route replace 192.168.20.3/32 dev enp0s9

  ip rule del from 192.168.10.0/24 to 192.168.20.0/24 lookup "${TABLE}" 2>/dev/null || true
  ip rule add from 192.168.10.0/24 to 192.168.20.0/24 lookup "${TABLE}" priority 100

  # Interdit le transit inter-sites en clair sur le WAN simulé
  iptables -C FORWARD -i enp0s8 -o enp0s9 -d 192.168.20.0/24 -j DROP 2>/dev/null || \
    iptables -A FORWARD -i enp0s8 -o enp0s9 -d 192.168.20.0/24 -j DROP
  iptables -C FORWARD -i enp0s9 -o enp0s8 -s 192.168.20.0/24 -d 192.168.10.0/24 -j DROP 2>/dev/null || \
    iptables -A FORWARD -i enp0s9 -o enp0s8 -s 192.168.20.0/24 -d 192.168.10.0/24 -j DROP
else
  ip rule del from 192.168.10.0/24 to 192.168.20.0/24 lookup "${TABLE}" 2>/dev/null || true
  ip route flush table "${TABLE}" 2>/dev/null || true
  iptables -D FORWARD -i enp0s8 -o enp0s9 -d 192.168.20.0/24 -j DROP 2>/dev/null || true
  iptables -D FORWARD -i enp0s9 -o enp0s8 -s 192.168.20.0/24 -d 192.168.10.0/24 -j DROP 2>/dev/null || true
fi
