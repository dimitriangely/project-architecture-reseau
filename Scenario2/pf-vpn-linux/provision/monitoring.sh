#!/bin/bash
set -eux
export DEBIAN_FRONTEND=noninteractive

echo "[monitoring] Installation de Prometheus et Grafana..."

# Supprimer un éventuel dépôt Grafana obsolète (oss/deb → 404)
rm -f /etc/apt/sources.list.d/grafana.list

apt-get update -y
apt-get install -y apt-transport-https software-properties-common wget gnupg net-tools

# Prometheus (dépôt Ubuntu universe)
apt-get install -y prometheus

# Grafana (dépôt officiel)
install -m 0755 -d /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y grafana

systemctl enable prometheus
systemctl restart prometheus

systemctl enable grafana-server
systemctl restart grafana-server

echo "[monitoring] Prometheus : http://localhost:9090"
echo "[monitoring] Grafana    : http://localhost:3000 (admin/admin au 1er login)"
