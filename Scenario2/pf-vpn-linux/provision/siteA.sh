#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive

echo "[siteA] Configuration du client..."

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

apt-get update -y
apt-get install -y frr frr-pythontools net-tools iptables-persistent

sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

cp /vagrant/frr/frr.conf.siteA /etc/frr/frr.conf
chown frr:frr /etc/frr/frr.conf
chmod 640 /etc/frr/frr.conf

systemctl enable frr
systemctl restart frr

echo "[siteA] Configuration terminée."
