# Scénario 1 — Lab SDN + OSPF (Vagrant)

Maquette à 5 VM Ubuntu 22.04 : contrôleur Ryu/OVS, deux routeurs FRR (OSPF), deux clients.

## Prérequis

- [Vagrant](https://www.vagrantup.com/) 2.x
- [VirtualBox](https://www.virtualbox.org/) 7.x
- ~10 Go de RAM libre (5 × 2 Go)
- Lancer les commandes **depuis ce dossier** (`Scenario1/sdn-lab-dev2-zip`)

## Démarrage

```bash
cd Scenario1/sdn-lab-dev2-zip
vagrant up
```

Une seule machine :

```bash
vagrant up controller
vagrant ssh router1
```

Reprovisionner après modification des scripts :

```bash
vagrant provision controller
vagrant provision router1 router2
```

## Topologie

| VM | Interface SDN (`sdn-net`) | Liens dédiés |
|----|---------------------------|--------------|
| controller | `br0` → `10.10.10.10/24` (OVS) | — |
| router1 | `enp0s8` → `10.10.10.11/24` | `enp0s9` client1 (`192.168.1.0/30`), `enp0s10` router2 (`192.168.3.0/30`) |
| router2 | `enp0s8` → `10.10.10.12/24` | `enp0s9` client2 (`192.168.2.0/30`), `enp0s10` router1 (`192.168.3.0/30`) |
| client1 | `enp0s8` → `10.10.10.13/24` | `enp0s9` → `192.168.1.2/30`, défaut via `192.168.1.1` |
| client2 | `enp0s8` → `10.10.10.14/24` | `enp0s9` → `192.168.2.2/30`, défaut via `192.168.2.1` |

Le contrôleur expose **Open vSwitch** (`br0`) et **Ryu** (OpenFlow `127.0.0.1:6633`). Les routeurs échangent des routes via **OSPF area 0**.

## Vérifications

Depuis l’hôte (après `vagrant up`) :

```bash
bash scripts/verify.sh
```

Manuellement :

```bash
# Connectivité inter-sites
vagrant ssh client1 -c "ping -c 3 192.168.2.2"

# OSPF sur router1
vagrant ssh router1 -c "sudo vtysh -c 'show ip ospf neighbor'"

# SDN sur le contrôleur
vagrant ssh controller -c "sudo ovs-vsctl show && sudo ovs-vsctl get-controller br0"
vagrant ssh controller -c "tail -5 /home/vagrant/ryu.log"
```

## Fichiers principaux

| Fichier | Rôle |
|---------|------|
| `Vagrantfile` | Définition des VM et réseaux VirtualBox |
| `controller/provision.sh` | OVS, Netplan `br0`, Ryu |
| `router-provision/provision.sh` | FRR + Netplan routeurs |
| `router-provision/router{1,2}/frr.conf` | Configuration OSPF |
| `client{1,2}/provision.sh` | Netplan clients |

## Dépannage

- **`Vagrantfile` introuvable** : exécuter Vagrant depuis ce répertoire.
- **FRR /fichier manquant** : le dossier projet est monté sur `/vagrant` (voir `Vagrantfile`).
- **Contrôleur sans IP sur `10.10.10.10`** : `vagrant provision controller` puis `ip addr show br0` dans la VM.
