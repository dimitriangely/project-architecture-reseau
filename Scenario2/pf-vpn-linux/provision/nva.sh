#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive

echo "[NVA] Configuration du routeur..."

wait_for_apt() {
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    echo "Attente du verrou apt..."
    sleep 3
  done
}
wait_for_apt

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

apt-get update -y
apt-get install -y frr frr-pythontools wireguard net-tools iptables-persistent

grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1
sysctl -p

# --- WireGuard (hub VPN vers siteB) ---
WG_DIR=/vagrant/wireguard
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"
if [ ! -f "$WG_DIR/nva.key" ]; then
  wg genkey | tee "$WG_DIR/nva.key" | wg pubkey > "$WG_DIR/nva.pub"
  wg genkey | tee "$WG_DIR/siteB.key" | wg pubkey > "$WG_DIR/siteB.pub"
  chmod 600 "$WG_DIR"/*.key
fi

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.255.0.1/30
ListenPort = 51820
PrivateKey = $(cat "$WG_DIR/nva.key")
Table = off

PostUp = /vagrant/provision/nva-intersite-policy.sh up; iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = /vagrant/provision/nva-intersite-policy.sh down; iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT

[Peer]
PublicKey = $(cat "$WG_DIR/siteB.pub")
AllowedIPs = 10.255.0.2/32, 192.168.20.0/24
EOF
chmod 600 /etc/wireguard/wg0.conf
chmod +x /vagrant/provision/nva-intersite-policy.sh
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# Appliquer la policy si wg-quick n'a pas exécuté PostUp (reprovision)
/vagrant/provision/nva-intersite-policy.sh up

# --- FRR / OSPF (adjacence siteB sur wg0) ---
sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

cp /vagrant/frr/frr.conf.nva /etc/frr/frr.conf
chown frr:frr /etc/frr/frr.conf
chmod 640 /etc/frr/frr.conf

systemctl enable frr
systemctl restart frr

iptables -t nat -C POSTROUTING -o enp0s9 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o enp0s9 -j MASQUERADE
netfilter-persistent save

echo "[NVA] WireGuard : $(wg show wg0 endpoints 2>/dev/null || echo 'en attente du peer siteB')"
echo "[NVA] Configuration terminée."
