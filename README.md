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

- 1 Contrôleur SDN (Ryu)
- 2 Routeurs avec FRRouting (OSPF)
- 2 Clients dans des sous-réseaux distincts
- Utilisation d’Open vSwitch pour la connectivité
- Scripts Bash pour l’automatisation
- Tests de connectivité (ping, traceroute, iperf)

### 🔹 Scénario 2 – Infrastructure sécurisée avec pfSense + VPN + OSPF

- 1 pfSense (firewall, VPN, OSPF)
- Tunnel VPN site-à-site (Wireguard/IPsec)
- Routage dynamique avec OSPF
- Supervision via Prometheus + Grafana
- Tests de résilience et sécurité

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
