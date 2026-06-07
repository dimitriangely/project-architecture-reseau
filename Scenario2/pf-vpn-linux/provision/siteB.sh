#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive

echo "[siteB] Configuration du peer distant..."

apt-get update -y
apt-get install -y frr frr-pythontools wireguard net-tools

# --- WireGuard (peer distant vers NVA) ---
WG_DIR=/vagrant/wireguard
for _ in $(seq 1 60); do
  if [ -f "$WG_DIR/siteB.key" ] && [ -f "$WG_DIR/nva.pub" ]; then
    break
  fi
  echo "Attente des clés WireGuard (provision nva requis)..."
  sleep 2
done
if [ ! -f "$WG_DIR/siteB.key" ]; then
  echo "ERREUR: clés absentes dans $WG_DIR — exécutez: vagrant provision nva" >&2
  exit 1
fi

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.255.0.2/30
PrivateKey = $(cat "$WG_DIR/siteB.key")

[Peer]
PublicKey = $(cat "$WG_DIR/nva.pub")
Endpoint = 192.168.20.2:51820
AllowedIPs = 10.255.0.1/32, 192.168.10.0/24
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# --- FRR / OSPF (adjacence NVA sur wg0) ---
sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

cp /vagrant/frr/frr.conf.siteB /etc/frr/frr.conf
chown frr:frr /etc/frr/frr.conf
chmod 640 /etc/frr/frr.conf

systemctl enable frr
systemctl restart frr

echo "[siteB] WireGuard : $(wg show wg0 | head -3)"
echo "[siteB] Configuration terminée."
