# Scénario 2 — Multi-sites, VPN WireGuard, OSPF et monitoring (Vagrant)

Maquette à **4 VM** Ubuntu 20.04 simulant une **infrastructure multi-sites hub-and-spoke** :

| VM | Rôle |
|----|------|
| **nva** | Routeur central (NVA), VPN hub, NAT, policy routing |
| **siteA** | Site principal (`192.168.10.0/24`) |
| **siteB** | Site distant (`192.168.20.0/24`) |
| **monitoring** | Prometheus + Grafana |

Contrairement au scénario 1 (SDN + OSPF hybride), ce lab met l’accent sur :

- une architecture **hub-and-spoke** (NVA = point de convergence) ;
- un **VPN site-to-site WireGuard** chiffré NVA ↔ siteB ;
- le **policy routing** forçant **100 % du trafic inter-sites** dans le tunnel ;
- le **routage dynamique OSPF** sur le LAN (siteA ↔ NVA) ;
- l’**observabilité** (Prometheus, Grafana).

---

## Prérequis

| Outil | Version testée |
|-------|----------------|
| [Vagrant](https://www.vagrantup.com/) | 2.x |
| [VirtualBox](https://www.virtualbox.org/) | 7.x |
| RAM libre | ~8 Go (4 VM × ~2 Go) |
| Shell | PowerShell (Vagrant) ; Git Bash / WSL pour `scripts/verify.sh` |

Lancer toutes les commandes **depuis ce dossier** : `Scenario2/pf-vpn-linux`.

```powershell
$env:VAGRANT_DEFAULT_PROVIDER = "virtualbox"
VBoxManage --version   # doit répondre (ex. 7.2.x)
```

---

## Démarrage

### Toutes les VM

```powershell
cd Scenario2/pf-vpn-linux
vagrant up --provider=virtualbox
```

Ordre recommandé si vous montez les VM une par une :

```powershell
vagrant up nva siteA siteB monitoring --provider=virtualbox
```

### Après modification d’un script `provision/*.sh`

`vagrant up` **ne relance pas** le provisionnement si la VM existe déjà :

```powershell
vagrant provision nva
vagrant provision siteB
vagrant provision siteA siteB monitoring
```

> **WireGuard :** les clés sont générées sur le NVA dans `wireguard/`. Provisionnez **`nva` avant `siteB`**.

---

## Architecture

### Schéma logique

```
  réseau VirtualBox "lan" (192.168.10.0/24)
  ┌──────────────────────────────────────────────────────────┐
  │  siteA (.3)          NVA (.2)           monitoring (.4)  │
  │  site principal      routeur hub        Prometheus/Grafana│
  │  FRR OSPF            enp0s8 + wg0                          │
  └──────────────────────────┬───────────────────────────────┘
                             │
                        ┌────┴────┐
                        │   NVA   │
                        │ NAT     │
                        │ policy  │
                        │ routing │
                        └────┬────┘
                             │ wg0 (chiffré) + enp0s9 (UDP 51820 underlay)
  ┌──────────────────────────┴───────────────────────────────┐
  │  réseau VirtualBox "wan" (192.168.20.0/24) — underlay simulé│
  │  siteB (.3) — peer WireGuard                                │
  └─────────────────────────────────────────────────────────────┘
```

### Modèle hub-and-spoke

- **siteA** n’a pas de tunnel direct vers **siteB** : tout passe par la **NVA**.
- **siteB** est le seul spoke VPN (WireGuard vers le hub).
- Le réseau `wan` simule l’**underlay** (Internet / opérateur) : seul le **UDP WireGuard** y transite en clair.

### Chemins de trafic inter-sites

| Sens | Chemin | Mécanisme |
|------|--------|-----------|
| **siteB → siteA** | siteB → `wg0` → NVA → `enp0s8` → siteA | `AllowedIPs = 192.168.10.0/24` sur siteB |
| **siteA → siteB** | siteA → NVA `enp0s8` → `wg0` → siteB | `ip rule` table `intersite` + `iptables DROP` WAN |

Aucun ICMP inter-sites ne transite en clair sur `enp0s9` (validé par `tcpdump`).

### Rôles par VM

| VM | Rôle | Réseau(x) | Services |
|----|------|-----------|----------|
| **nva** | Routeur / passerelle / hub VPN | `lan` + `wan` | FRR, WireGuard, NAT, **policy routing** |
| **siteA** | Site principal | `lan` | FRR (OSPF) |
| **siteB** | Site distant | `wan` | FRR, WireGuard peer |
| **monitoring** | Supervision | `lan` | Prometheus, Grafana, node-exporter |

### Adressage

| VM | Interface | IP | Réseau VirtualBox |
|----|-----------|-----|-------------------|
| **nva** | `enp0s8` | `192.168.10.2/24` | `lan` |
| **nva** | `enp0s9` | `192.168.20.2/24` | `wan` |
| **nva** | `wg0` | `10.255.0.1/30` | tunnel VPN |
| **siteA** | `enp0s8` | `192.168.10.3/24` | `lan` |
| **siteB** | `enp0s8` | `192.168.20.3/24` | `wan` |
| **siteB** | `wg0` | `10.255.0.2/30` | tunnel VPN |
| **monitoring** | `enp0s8` | `192.168.10.4/24` | `lan` |

Chaque VM a aussi une interface NAT Vagrant (`enp0s3`, `10.0.2.15`).

### Ports SSH (hôte Windows)

| VM | Port hôte |
|----|-----------|
| nva | `2201` |
| siteA | `2202` |
| siteB | `2203` |
| monitoring | `2204` |

---

## WireGuard (VPN site-to-site)

### Paramètres du tunnel

| Paramètre | NVA | siteB |
|-----------|-----|-------|
| Interface | `wg0` | `wg0` |
| IP tunnel | `10.255.0.1/30` | `10.255.0.2/30` |
| Port UDP | `51820` (écoute) | dynamique → `192.168.20.2:51820` |
| AllowedIPs (peer) | `10.255.0.2/32`, `192.168.20.0/24` | `10.255.0.1/32`, `192.168.10.0/24` |
| `Table` | `off` (pas de routes auto wg-quick) | défaut |

Les clés Curve25519 sont générées au premier `vagrant provision nva` dans `wireguard/` (fichiers `*.key` / `*.pub` ignorés par Git).

### Policy routing — transit 100 % tunnel

Script : `provision/nva-intersite-policy.sh` (appelé au `PostUp` de `wg0`).

| Mécanisme | Rôle |
|-----------|------|
| `ip rule` priority 100 : `from 192.168.10.0/24 to 192.168.20.0/24 lookup intersite` | Trafic siteA → siteB via `wg0` |
| `ip route` table `intersite` : `192.168.20.0/24 dev wg0` | Encapsulation WireGuard |
| `ip route` main : `192.168.20.3/32 dev enp0s9` | Underlay UDP (handshake) — **sans** inclure `.3` dans AllowedIPs NVA |
| `Table = off` dans `wg0.conf` | Évite le conflit `192.168.20.0/24` connecté vs route wg-quick |
| `iptables DROP` `enp0s8→enp0s9` et `enp0s9→enp0s8` (inter-sites) | Interdit le WAN en clair |

---

## OSPF et routage

Configurations FRR : `frr/frr.conf.{nva,siteA,siteB}`.

| Équipement | Réseaux annoncés (area 0) | Adjacence observée |
|------------|---------------------------|--------------------|
| **nva** | `192.168.10.0/24`, `192.168.20.0/24`, `10.255.0.0/30` | **siteA Full** sur `enp0s8` |
| **siteA** | `192.168.10.0/24` | **NVA Full** sur `enp0s8` |
| **siteB** | `192.168.20.0/24`, `10.255.0.0/30` | Pas d’adjacence sur `wg0` (OSPF multicast incompatible avec WireGuard) |

### Routage effectif inter-sites

| Composant | Rôle |
|-----------|------|
| **OSPF** siteA ↔ NVA | siteA apprend `192.168.20.0/24` via le NVA (`enp0s9` passif) |
| **AllowedIPs** siteB | siteB route `192.168.10.0/24` via le tunnel |
| **Policy routing** NVA | siteA → siteB forcé dans `wg0` |

Le **Router ID** du NVA est en général `192.168.20.2` (IP la plus élevée).

---

## Vérifications automatisées

```bash
bash scripts/verify.sh
```

### Résultat attendu (lab validé)

| Test | Critère de succès |
|------|-------------------|
| État VM | 4 machines `running` |
| WireGuard | Handshake actif sur siteB |
| Ping tunnel | `10.255.0.1` depuis siteB, 0 % perte |
| Ping inter-sites | siteA ↔ siteB, 0 % perte |
| Policy routing | Règle `intersite` + route `192.168.20.0/24 dev wg0` |
| OSPF | Voisin **Full** siteA ↔ NVA |
| Prometheus | `active` sur monitoring |

---

## Vérifications manuelles et interprétation

### 1. WireGuard

```powershell
vagrant ssh siteB -c "sudo wg show"
```

**Exemple validé :**

```text
latest handshake: … ago
transfer: … received, … sent
allowed ips: 10.255.0.1/32, 192.168.10.0/24
```

| Champ | Signification |
|-------|---------------|
| `latest handshake` | Tunnel actif |
| `transfer` | Trafic chiffré échangé |
| `allowed ips` | Préfixes routés via le tunnel |

### 2. Ping tunnel

```powershell
vagrant ssh siteB -c "ping -c 3 10.255.0.1"
```

**Attendu :** 0 % perte — connectivité L3 sur le réseau de transport VPN.

### 3. Connectivité inter-sites

```powershell
vagrant ssh siteA -c "ping -c 3 192.168.20.3"
vagrant ssh siteB -c "ping -c 3 192.168.10.3"
```

**Attendu :** 0 % perte, TTL ≈ 63 (traversée du NVA + tunnel).

### 4. Policy routing

```powershell
vagrant ssh nva -c "ip rule list; ip route show table intersite"
```

**Exemple validé :**

```text
100:    from 192.168.10.0/24 to 192.168.20.0/24 lookup intersite
192.168.20.0/24 dev wg0 scope link
```

### 5. Absence de trafic ICMP en clair sur le WAN

Lancer **pendant** un ping siteA → siteB :

```powershell
vagrant ssh nva -c "sudo timeout 8 tcpdump -i enp0s9 -n icmp and host 192.168.20.3"
```

**Exemple validé :**

```text
0 packets captured
```

Preuve que le payload inter-sites **ne transite pas en clair** sur `enp0s9`.

### 6. OSPF

```powershell
vagrant ssh nva -c "sudo vtysh -c 'show ip ospf neighbor'"
```

**Exemple validé :**

```text
192.168.10.3   1 Full/DR   …   enp0s8:192.168.10.2
```

---

## Monitoring (Prometheus + Grafana)

| Service | URL (hôte) |
|---------|------------|
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |

### Prometheus — targets par défaut

| Job | Endpoint | État |
|-----|----------|------|
| `prometheus` | `localhost:9090` | UP |
| `node` | `localhost:9100` | UP |

Seule la VM **monitoring** est supervisée (pas NVA / siteA / siteB par défaut).

### Requêtes PromQL utiles

```promql
up
node_memory_MemAvailable_bytes
rate(node_cpu_seconds_total[1m])
```

### Grafana

1. Connexion http://localhost:3000 (`admin` / `admin` au 1er login).
2. **Connections → Data sources → Prometheus** → `http://localhost:9090`.
3. Importer le dashboard **Node Exporter Full** (ID `1860`).
4. Variables : **Instance = `localhost:9100`** (pas `9090`).

> Sur Ubuntu 20.04, certains panneaux du dashboard `1860` peuvent afficher « No data » ; RAM, load et disque suffisent pour valider la chaîne monitoring.

---

## Fichiers du projet

| Fichier | Rôle |
|---------|------|
| `Vagrantfile` | 4 VM, réseaux `lan` / `wan`, ports SSH et web |
| `provision/nva.sh` | FRR, WireGuard hub, NAT, policy routing |
| `provision/nva-intersite-policy.sh` | `ip rule`, table `intersite`, `iptables DROP` |
| `provision/siteA.sh` | FRR OSPF site principal |
| `provision/siteB.sh` | FRR, WireGuard peer |
| `provision/monitoring.sh` | Prometheus + Grafana |
| `frr/frr.conf.nva` | OSPF LAN + annonce WAN passif + config wg0 |
| `frr/frr.conf.siteA` | OSPF LAN |
| `frr/frr.conf.siteB` | OSPF (wg0 configuré) |
| `wireguard/` | Clés générées au provisionnement NVA |
| `scripts/verify.sh` | Checklist automatisée post-déploiement |

Dossier partagé dans chaque VM : `/vagrant`.

---

## Dépannage

| Symptôme | Cause probable | Action |
|----------|----------------|--------|
| OSPF sans voisins | NVA non reprovisionné | `vagrant provision nva` |
| `wg show` vide sur siteB | siteB non provisionné | `vagrant provision nva` puis `siteB` |
| WireGuard sans handshake | Clés absentes / mauvais ordre | Reprovisionner NVA puis siteB |
| `wg-quick` échoue (RTNETLINK File exists) | Conflit route `192.168.20.0/24` | Vérifier `Table = off` dans `wg0.conf` |
| Ping OK mais tcpdump ICMP sur wan | Policy routing absent | `vagrant provision nva` |
| Verrou `apt` sur NVA | iptables-persistent bloqué | `sudo dpkg --configure -a` |
| Grafana introuvable | Ancienne URL apt Grafana | `vagrant provision monitoring` |
| Dashboard Grafana vide | Instance = `9090` | Choisir **`9100`** |
| SSH siteB timeout | VM bloquée | `vagrant destroy siteB -f` puis `vagrant up siteB` |
| Quoting PowerShell | Guillemets | `vagrant ssh nva -c "sudo vtysh -c 'show ip ospf neighbor'"` |

---

## Arrêt du lab

```powershell
vagrant halt
# ou :
vagrant destroy -f
```

---

## Synthèse (état validé du lab)

| Couche | Technologie | Statut |
|--------|-------------|--------|
| Virtualisation | Vagrant + VirtualBox | OK |
| Architecture | Hub-and-spoke (NVA) | OK |
| VPN | WireGuard NVA ↔ siteB | OK (handshake + ping tunnel) |
| Sécurisation inter-sites | Policy routing + iptables | OK (tcpdump WAN = 0 ICMP) |
| Routage LAN | OSPF siteA ↔ NVA Full | OK |
| Connectivité inter-sites | Ping bidirectionnel | OK |
| Observabilité | Prometheus + Grafana | OK (VM monitoring) |

---

## Conclusion (rapport)

> Une architecture d’interconnexion de type **hub-and-spoke** a été mise en œuvre. Un tunnel VPN **WireGuard** opérationnel relie la **NVA** au site distant (**siteB**), validé par l’établissement du **handshake** et par des tests de connectivité sur le réseau de transport VPN (`10.255.0.0/30`).
>
> Le **policy routing** sur la NVA force l’ensemble des flux inter-sites à transiter par le tunnel, ce qui est confirmé par l’**absence de trafic ICMP en clair** sur l’interface WAN simulée (`tcpdump` : 0 paquet capturé).
>
> Le protocole **OSPF** est actif entre le site principal (**siteA**) et la NVA, avec une adjacence établie à l’état **Full** sur le réseau local partagé. La connectivité inter-sites entre `192.168.10.0/24` et `192.168.20.0/24` a été confirmée par des **pings bidirectionnels**.
>
> Le routage inter-sites combine les **routes injectées par WireGuard** (`AllowedIPs` côté siteB), le **policy routing** côté NVA (table `intersite`) et les **annonces OSPF** du NVA vers le LAN. Cette approche assure simultanément la **sécurisation des échanges inter-sites** et la **propagation dynamique des routes** au sein du site principal.

Ce scénario constitue une base pour un **POC entreprise** : extension possible vers BGP inter-cloud, supervision multi-sites (node-exporter sur NVA/siteA/siteB), ou déploiement cloud (AWS/Azure).
