# Scénario 1 — Lab SDN + OSPF (Vagrant)

Maquette à **5 VM** Ubuntu 22.04 : contrôleur **Ryu/OVS**, deux routeurs **FRR (OSPF)**, deux clients.  
Architecture **mixte** : routage dynamique classique entre sites + plan de contrôle SDN sur le bus `10.10.10.0/24`.

---

## Prérequis

| Outil | Version testée |
|-------|----------------|
| [Vagrant](https://www.vagrantup.com/) | 2.x |
| [VirtualBox](https://www.virtualbox.org/) | 7.x |
| RAM libre | ~10 Go (5 × 2 Go) |
| Shell | Git Bash / WSL (pour `verify.sh`) ou PowerShell |

Lancer toutes les commandes **depuis ce dossier** : `Scenario1/sdn-lab-dev2-zip`.

```powershell
$env:VAGRANT_DEFAULT_PROVIDER = "virtualbox"
VBoxManage --version   # doit répondre (ex. 7.2.x)
```

---

## Démarrage

```bash
cd Scenario1/sdn-lab-dev2-zip
vagrant up --provider=virtualbox
```

Machine isolée :

```bash
vagrant up controller --provider=virtualbox
vagrant ssh router1
```

Après modification des scripts :

```bash
vagrant provision controller
vagrant provision router1 router2
```

---

## Architecture

### Schéma logique

```
                    sdn-net (10.10.10.0/24) — OSPF area 0
    ┌─────────────────────────────────────────────────────────────┐
    │  controller          router1              router2         │
    │  br0 (OVS)           enp0s8 .11          enp0s8 .12       │
    │  10.10.10.10         enp0s9 ────┐    ┌── enp0s9          │
    │  Ryu :6633                        │    │                  │
    └───────────────────────────────────┼────┼──────────────────┘
                                        │    │
              client1-router1           │    │    client2-router2
              192.168.1.0/30            │    │    192.168.2.0/30
                    ┌───────────────────┘    └───────────────────┐
                    │                                              │
               client1 .2                                    client2 .2
               défaut → .1                                   défaut → .1

              router1-router2 : 192.168.3.0/30  (.1 router1 — .2 router2)
```

### Rôles par VM

| VM | Rôle | Plan de données | Plan de contrôle |
|----|------|-----------------|------------------|
| **controller** | Nœud SDN | OVS `br0` + port `enp0s8` | Ryu (OpenFlow `127.0.0.1:6633`) |
| **router1 / router2** | Routeurs L3 | FRR, interfaces point-à-point | OSPF area 0 |
| **client1 / client2** | Hôtes finaux | IP site + route par défaut vers son routeur | — |

### Adressage détaillé

| VM | Interface SDN | Autres interfaces |
|----|---------------|-------------------|
| controller | `br0` → `10.10.10.10/24` | — |
| router1 | `enp0s8` → `10.10.10.11/24` | `enp0s9` `192.168.1.1/30` (client1), `enp0s10` `192.168.3.1/30` (router2) |
| router2 | `enp0s8` → `10.10.10.12/24` | `enp0s9` `192.168.2.1/30` (client2), `enp0s10` `192.168.3.2/30` (router1) |
| client1 | `enp0s8` → `10.10.10.13/24` | `enp0s9` `192.168.1.2/30`, défaut via `192.168.1.1` |
| client2 | `enp0s8` → `10.10.10.14/24` | `enp0s9` `192.168.2.2/30`, défaut via `192.168.2.1` |

### SDN vs OSPF dans ce lab

- **OSPF (FRR)** : assure la **connectivité inter-sites** (client1 ↔ client2) via les routeurs et le réseau `10.10.10.0/24`.
- **SDN (Ryu + OVS)** : le contrôleur gère le **bus SDN** comme un switch OpenFlow ; l’application `forward_all.py` envoie les paquets inconnus au contrôleur puis les **inonde** (comportement hub).
- Les routeurs **ne sont pas** des switches OpenFlow : ils participent au SDN uniquement comme **voisins OSPF** sur `10.10.10.0/24`.

---

## Vérifications automatisées

```bash
bash scripts/verify.sh
```

### Résultat attendu (lab validé)

| Test | Critère de succès |
|------|-------------------|
| État VM | 5 machines `running` |
| Ping | `client1` → `192.168.2.2` (client2), 0 % perte |
| OSPF | Voisins `Full` sur router1 et router2 |
| OVS | `br0` avec `10.10.10.10/24`, contrôleur port `6633` |
| Ryu | Processus `python3.9 -m ryu.cmd.manager`, log sans `Traceback` |

Exemple de fin de script :

```text
[✓] Vérifications terminées
```

---

## Vérifications manuelles et interprétation

### 1. Connectivité inter-sites (OSPF)

```bash
vagrant ssh client1 -c "ping -c 3 192.168.2.2"
```

**Attendu** : 3 réponses, TTL ≈ 62 (traversée de 2 routeurs).

### 2. Voisins OSPF

```bash
vagrant ssh router1 -c "sudo vtysh -c 'show ip ospf neighbor'"
```

**Attendu** : voisin `2.2.2.1` en état **`Full`** sur `enp0s8` (SDN) et `enp0s10` (lien direct router1–router2).

### 3. Routes OSPF (router1)

```bash
vagrant ssh router1 -c "sudo vtysh -c 'show ip route ospf'"
```

**Exemple validé** :

```text
O   10.10.10.0/24 [110/100] is directly connected, enp0s8
O   192.168.1.0/30 [110/100] is directly connected, enp0s9
O>* 192.168.2.0/30 [110/200] via 10.10.10.12, enp0s8
  *                          via 192.168.3.2, enp0s10
O   192.168.3.0/30 [110/100] is directly connected, enp0s10
```

| Route | Signification |
|-------|----------------|
| `192.168.1.0/30` | Réseau local client1 |
| `192.168.2.0/30` | Réseau client2, appris par OSPF (équiv. ECMP) |
| `192.168.3.0/30` | Lien backbone router1 ↔ router2 |

### 4. Open vSwitch et lien OpenFlow

```bash
vagrant ssh controller -c "sudo ovs-vsctl show"
```

**Exemple validé** :

```text
Bridge br0
    Controller "tcp:127.0.0.1:6633"
        is_connected: true
    fail_mode: standalone
    Port enp0s8
    Port br0
        type: internal
```

| Champ | Signification |
|-------|----------------|
| `is_connected: true` | Ryu écoute et OVS est connecté en OpenFlow |
| `fail_mode: standalone` | Si Ryu tombe, OVS reste autonome (sans contrôleur) |
| `Port enp0s8` | Interface physique du bus SDN dans le bridge |

### 5. Table de flux OpenFlow

```bash
vagrant ssh controller -c "sudo ovs-ofctl dump-flows br0"
```

**Exemple validé** :

```text
cookie=0x0, duration=164s, table=0, n_packets=39, n_bytes=3126,
  priority=0 actions=CONTROLLER:65535
```

| Champ | Signification |
|-------|----------------|
| `priority=0` | Règle par défaut (installée par `forward_all.py`) |
| `actions=CONTROLLER` | Paquets envoyés à Ryu (`PacketIn`) |
| `n_packets > 0` | Trafic réel sur `br0` (OSPF, ARP, OpenFlow, etc.) |

Ryu répond avec une action **FLOOD** dans `controller/provision.sh` → comportement hub.

### 6. Processus Ryu

```powershell
vagrant ssh controller -c "pgrep -af ryu.cmd.manager"
```

**Attendu** :

```text
python3.9 -m ryu.cmd.manager /home/vagrant/ryu-app/forward_all.py
```

---

## Fichiers du projet

| Fichier | Rôle |
|---------|------|
| `Vagrantfile` | 5 VM, réseaux VirtualBox (`sdn-net`, liens /30), dossier partagé `/vagrant` |
| `controller/provision.sh` | OVS, Netplan `br0`, Python 3.9, Ryu, `forward_all.py` |
| `router-provision/provision.sh` | FRR + Netplan (détection hostname) |
| `router-provision/router{1,2}/frr.conf` | OSPF (router-id, networks) |
| `client{1,2}/provision.sh` | Netplan clients + route par défaut |
| `scripts/verify.sh` | Checklist automatisée post-déploiement |

---

## Dépannage

| Symptôme | Action |
|----------|--------|
| `VBoxManage` introuvable | Installer VirtualBox, ajouter au `PATH` |
| Erreur VMware Utility | `$env:VAGRANT_DEFAULT_PROVIDER = "virtualbox"` |
| `Vagrantfile` introuvable | Exécuter Vagrant depuis `sdn-lab-dev2-zip` |
| FRR : fichier `/vagrant/...` manquant | Lancer Vagrant depuis le dossier du lab |
| Pas d’IP sur `br0` | `vagrant provision controller` puis `ip addr show br0` |
| Ryu arrêté (`ryu.log`) | `vagrant provision controller` ou : `sudo python3.9 -m pip install netaddr webob routes msgpack oslo.config tinyrpc` puis relancer le manager |
| Quoting PowerShell | Préférer : `vagrant ssh controller -c "python3.9 -c 'import ryu'"` |

---

## Synthèse (état validé du lab)

| Couche | Technologie | Statut |
|--------|-------------|--------|
| Virtualisation | Vagrant + VirtualBox | OK |
| Routage inter-sites | FRR / OSPF area 0 | OK |
| Connectivité hôtes | client1 ↔ client2 | OK |
| Data plane SDN | Open vSwitch `br0` | OK |
| Control plane SDN | Ryu + OpenFlow `:6633` | OK (`is_connected: true`) |
| Application SDN | `forward_all.py` (flood) | OK (flux → `CONTROLLER`) |

Ce lab démontre une **infrastructure hybride** : **OSPF** pour le routage multi-sites et **SDN** pour la gestion programmée du segment `10.10.10.0/24` via OpenFlow.
