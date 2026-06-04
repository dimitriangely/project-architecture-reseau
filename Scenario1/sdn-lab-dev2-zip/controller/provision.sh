#!/bin/bash
set -eux

echo "[+] Mise à jour du système"
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl git openvswitch-switch

echo "[+] Netplan : enp0s8 sans IP (port OVS), IP SDN sur br0"
cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: no
  bridges:
    br0:
      dhcp4: no
      interfaces: [enp0s8]
      openvswitch: {}
      addresses: [10.10.10.10/24]
EOF

echo "[+] Installation de Python 3.9"
if ! command -v python3.9 &> /dev/null; then
  sudo add-apt-repository -y ppa:deadsnakes/ppa
  sudo apt-get update -y
  sudo apt-get install -y python3.9 python3.9-distutils
fi
if ! python3.9 -m pip --version &>/dev/null; then
  curl -sS https://bootstrap.pypa.io/pip/3.9/get-pip.py | sudo python3.9
fi

echo "[+] Installation de Ryu et des dépendances compatibles"
# Ryu 4.34 : pip/setuptools récents cassent le build ; installation via setup.py
sudo apt-get install -y python3.9-dev build-essential
sudo python3.9 -m pip install "setuptools==59.8.0" wheel
sudo python3.9 -m pip install greenlet==1.1.3 eventlet==0.30.2 dnspython==1.16.0
if ! python3.9 -c "import ryu" &>/dev/null; then
  RYU_TMP=$(mktemp -d)
  curl -fsSL -o "$RYU_TMP/ryu.tar.gz" https://files.pythonhosted.org/packages/source/r/ryu/ryu-4.34.tar.gz
  tar -xzf "$RYU_TMP/ryu.tar.gz" -C "$RYU_TMP"
  (cd "$RYU_TMP/ryu-4.34" && sudo python3.9 setup.py install)
  rm -rf "$RYU_TMP"
fi

echo "[+] Démarrage du service Open vSwitch"
sudo systemctl enable openvswitch-switch
sudo systemctl start openvswitch-switch
sleep 2

echo "[+] Application Netplan (bridge OVS br0 + 10.10.10.10)"
sudo netplan apply
sleep 2

echo "[+] Vérification du bridge OVS br0"
sudo ovs-vsctl br-exists br0
sudo ovs-vsctl list-ports br0 | grep -q enp0s8

echo "[+] Définition du contrôleur Ryu pour br0 (port 6633)"
sudo ovs-vsctl set-controller br0 tcp:127.0.0.1:6633

echo "[+] Création de l'application Ryu forward_all.py"
mkdir -p /home/vagrant/ryu-app
cat <<'RYUAPP' > /home/vagrant/ryu-app/forward_all.py
from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3

class ForwardAll(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(ForwardAll, self).__init__(*args, **kwargs)

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                          ofproto.OFPCML_NO_BUFFER)]
        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        mod = parser.OFPFlowMod(datapath=datapath, priority=0,
                                match=match, instructions=inst)
        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        in_port = msg.match['in_port']
        actions = [parser.OFPActionOutput(ofproto.OFPP_FLOOD)]

        out = parser.OFPPacketOut(
            datapath=datapath,
            buffer_id=msg.buffer_id,
            in_port=in_port,
            actions=actions,
            data=msg.data)
        datapath.send_msg(out)
RYUAPP

echo "[+] Nettoyage des anciens processus Ryu"
sudo pkill -f ryu.cmd.manager || true
sleep 1

echo "[+] Lancement de Ryu"
nohup python3.9 -m ryu.cmd.manager /home/vagrant/ryu-app/forward_all.py > /home/vagrant/ryu.log 2>&1 &

echo "[✓] Ryu en cours — logs : tail -f /home/vagrant/ryu.log"
echo "[✓] IP SDN sur br0 : $(ip -4 addr show br0 | awk '/inet / {print $2}')"
echo "[✓] Contrôleur OVS : $(sudo ovs-vsctl get-controller br0)"
echo "[✓] Flux OpenFlow : sudo ovs-ofctl dump-flows br0"
