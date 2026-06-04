#!/bin/bash
set -eux

# Déduire le nom de la VM (hostname défini par Vagrant)
ROUTER_NAME=$(hostname)

echo "[+] Installation de FRRouting"
sudo apt-get update -y
sudo apt-get install -y frr frr-pythontools

echo "[+] Activation des démons zebra et ospfd"
sudo sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons
sudo sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons

echo "[+] Génération du fichier Netplan pour $ROUTER_NAME"

if [[ "$ROUTER_NAME" == "router1" ]]; then
  cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: no
      addresses: [10.10.10.11/24]
    enp0s9:
      dhcp4: no
      addresses: [192.168.1.1/30]
    enp0s10:
      dhcp4: no
      addresses: [192.168.3.1/30]
EOF

elif [[ "$ROUTER_NAME" == "router2" ]]; then
  cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: no
      addresses: [10.10.10.12/24]
    enp0s9:
      dhcp4: no
      addresses: [192.168.2.1/30]
    enp0s10:
      dhcp4: no
      addresses: [192.168.3.2/30]
EOF
fi

echo "[+] Application de la configuration Netplan"
sudo netplan apply

echo "[+] Copie de la configuration FRR pour $ROUTER_NAME"
FRR_SRC="/vagrant/router-provision/${ROUTER_NAME}/frr.conf"
if [[ ! -f "$FRR_SRC" ]]; then
  echo "[!] Fichier introuvable : $FRR_SRC (vérifiez le dossier partagé /vagrant)"
  exit 1
fi
sudo cp "$FRR_SRC" /etc/frr/frr.conf
sudo chown frr:frr /etc/frr/frr.conf
sudo chmod 640 /etc/frr/frr.conf

echo "[+] Vérification/Création de vtysh.conf"
sudo touch /etc/frr/vtysh.conf
sudo chown frr:frr /etc/frr/vtysh.conf
sudo chmod 640 /etc/frr/vtysh.conf

echo "[+] Activation de l'IP forwarding (runtime + permanent)"
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i '/^net\.ipv4\.ip_forward\s*=.*/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "[+] Redémarrage du service FRR"
sudo systemctl enable frr
sudo systemctl restart frr

echo "[✓] FRR configuré avec succès sur $ROUTER_NAME"
echo "[✓] Interfaces configurées :"
ip a | grep "inet "

echo "[✓] Vérifiez vos voisins OSPF : sudo vtysh -c 'show ip ospf neighbor'"
echo "[✓] Vérifiez vos routes     : sudo vtysh -c 'show ip route ospf'"
echo "[✓] Vérifiez vos interfaces : sudo vtysh -c 'show ip interface'"
