# Projet Réseaux – Cloud & SDN Avancés avec Vagrant

> **Formation** : Ynov Campus Paris  
> **Matière** : Architecture des Réseaux MAJ  
> **Référent** : Mr TAIEB  
> **Groupe 6** :  
> Dimitri ANGELY (Chef de projet)  
> Mohamed TOURE (Architecte/Intégrateur/Testeur)  
> Ibrahima GASSAMA (Assistant chef de projet)  
> Yves-Michael OLEMY (Architecte Réseau)  
> Lamya TAHRI (Rédactrice / Documentaliste)

---

## 🎯 Objectif du projet

Ce projet vise à construire une **maquette de réseau d’entreprise virtuelle**, automatisée et sécurisée, en utilisant des technologies modernes Cloud et SDN. L'infrastructure est déployée via **Vagrant** et intègre des composants open source comme **Open vSwitch**, **FRRouting**, **pfSense**, **Ryu**, **Prometheus** et **Grafana**.

---

## 🧰 Technologies utilisées

| Domaine               | Outils / Technologies               |
|----------------------|-------------------------------------|
| Virtualisation       | Vagrant, VirtualBox                |
| Routage dynamique    | FRRouting (OSPF, BGP)              |
| SDN                  | Ryu (contrôleur SDN), Open vSwitch |
| Sécurité réseau      | pfSense, VPN IPsec/WireGuard       |
| Supervision          | Prometheus, Grafana, tcpdump       |
| Automatisation       | Bash, Ansible (base)               |
| Dév/Tests            | Ubuntu 22.04, Visual Studio Code   |

---

## 📁 Scénarios développés

### 🔹 Scénario 1 – Réseau SDN automatisé avec OSPF

- 1 Contrôleur SDN (Ryu + Open vSwitch)
- 2 Routeurs avec FRRouting (OSPF area 0)
- 2 Clients dans des sous-réseaux distincts (`192.168.1.0/30`, `192.168.2.0/30`)
- Bus SDN commun `10.10.10.0/24` (OpenFlow sur le contrôleur)
- Scripts Bash + Vagrant pour le déploiement automatisé
- Script de validation `scripts/verify.sh` (ping inter-sites, OSPF, Ryu/OVS)

**Documentation complète** : [`Scenario1/sdn-lab-dev2-zip/README.md`](Scenario1/sdn-lab-dev2-zip/README.md)  
(topologie, interprétation des commandes `ovs-vsctl`, `dump-flows`, routes OSPF, dépannage)

### 🔹 Scénario 2 – Multi-sites, VPN WireGuard, OSPF et monitoring

- 1 NVA (routeur hub), site principal (siteA), site distant (siteB), supervision (monitoring)
- Tunnel **WireGuard** site-to-site NVA ↔ siteB
- **Policy routing** : transit inter-sites 100 % chiffré via le tunnel
- Routage dynamique **OSPF** (siteA ↔ NVA)
- Supervision **Prometheus + Grafana**
- Script de validation `scripts/verify.sh`

**Documentation complète** : [`Scenario2/pf-vpn-linux/readme.md`](Scenario2/pf-vpn-linux/readme.md)  
(topologie hub-and-spoke, policy routing, interprétation des tests WireGuard/OSPF/tcpdump, dépannage)

---

## 📊 Diagrammes & Monitoring

- Schémas d’infrastructure inclus dans le rapport
- Supervision live : états des tunnels VPN, latence, disponibilité des sites
- Métriques visualisées dans Grafana via Prometheus

---

## ❓ Questions traitées

- Différences switch SDN vs classique
- Intérêt de BGP en environnement multi-cloud
- Risques de convergence lente
- Monitoring SDN moderne
- Sécurité réseau SDN
- Alternatives à Istio (Linkerd, Traefik Mesh…)
- Déploiement Cloud public (AWS, Azure)
- Passage vers un POC en entreprise

---

## 🔄 Évolutivité vers un environnement pro

- Industrialisation avec Proxmox ou VMware
- CI/CD avec GitHub Actions
- Sécurité renforcée (TLS, RBAC)
- Supervision complète (ELK, Grafana Loki)
- Montée en charge simulée

---

## 📎 Liens utiles

- 📘 Rapport complet : *voir dossier `Documentation_technique.docx`*
- 🗂️ GitHub du projet : [GitHub Repository](https://github.com/dimitriangely/project-architecture-reseau.git)
- 🧩 Jira : [Board Projet](https://projetarchireseaux.atlassian.net/jira/software/projects/PAR/boards/1)

---

## ✅ Conclusion

Ce projet démontre notre capacité à concevoir, déployer et superviser une infrastructure réseau avancée à l’aide d’outils Cloud & SDN. Il pose les bases d’une architecture prête à évoluer vers un usage professionnel, et reflète des pratiques DevOps et infrastructure-as-code modernes.
