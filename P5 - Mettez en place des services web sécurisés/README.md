# 🧩 Projet de formation – Infrastructure réseau Rainbow Bank

## 📘 Description du projet

**Rainbow Bank** est une banque internationale basée à **Paris**, spécialisée dans les services financiers numériques.  
Vous occupez le poste d’**administrateur systèmes et réseaux** au sein du **Pôle Systèmes et Réseaux**, rattaché à la **Direction Infrastructure et Logistique (DIL)**.  
Ce pôle, dirigé par **Aurélie Fernandez**, compte **environ 70 collaborateurs** et assure la gestion de l’ensemble des infrastructures techniques de la banque.

Dans le cadre de la modernisation de ses services internes, vous êtes chargé de **déployer et configurer plusieurs services réseau sécurisés** au sein de l’infrastructure Rainbow Bank :
- un **service web** interne,  
- un **service FTP sécurisé**,  
- et un **filtrage réseau avancé** pour le contrôle des flux.

---

## ⚙️ Services et configurations développés

### 🧱 1. Service Web – `Apache / PHP`
**Objectif :** mettre à disposition un serveur web sécurisé pour héberger le portail interne de Rainbow Bank.

#### ✨ Fonctionnalités principales
- Installation et configuration du serveur **Apache 2.4**
- Gestion des **hôtes virtuels** pour la séparation des environnements
- Activation du **module SSL** et mise en place d’un **certificat HTTPS**
- Configuration des **logs d’accès et d’erreur**
- Test de disponibilité et de performance via `curl` et `systemctl`

#### 🔐 Points techniques
- OS cible : **Debian 12.6**
- Modules activés : `rewrite`, `ssl`, `headers`
- Répertoire racine : `/var/www/html`
- Ports : **80 (HTTP)** et **443 (HTTPS)**
- Fichiers principaux :  
  - `000-default.conf`  
  - `default-ssl.conf`  
  - `index.php` de test applicatif

---

### 🧱 2. Service FTP – `vsftpd`
**Objectif :** permettre le transfert sécurisé de fichiers internes tout en garantissant la confidentialité des données.

#### ✨ Fonctionnalités principales
- Installation et configuration du service **vsftpd**
- Création d’un **espace FTP isolé** pour chaque utilisateur
- Activation du **mode chroot** (interdiction d’accès hors du répertoire personnel)
- Configuration du **mode passif** pour compatibilité réseau
- Sécurisation des échanges via **TLS explicite**

#### 🔐 Points techniques
- Service : **vsftpd**
- Port principal : **21**
- Plage passive : **40000–50000**
- Authentification locale (`/etc/vsftpd.userlist`)
- Journalisation activée (`/var/log/vsftpd.log`)
- Configuration principale : `vsftpd.conf`
- Tests de connexion via **FileZilla** et **lftp**

---

### 🔁 3. Filtrage réseau – `iptables / netfilter`
**Objectif :** sécuriser l’accès aux services déployés par une politique de filtrage stricte.

#### ✨ Fonctionnalités principales
- Mise en place d’un **pare-feu local** avec `iptables`
- Définition des politiques par défaut :
  - `INPUT DROP`
  - `FORWARD DROP`
  - `OUTPUT ACCEPT`
- Autorisation sélective des ports nécessaires :
  - 22 (SSH)
  - 80 / 443 (Web)
  - 21 + 40000–50000 (FTP)
- Blocage de tout trafic non explicitement autorisé

#### 🔐 Points techniques
- Script de configuration automatisé :
  ```bash
  #!/bin/bash
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
  iptables -P OUTPUT ACCEPT
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  iptables -A INPUT -p tcp --dport 21 -j ACCEPT
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  iptables -A INPUT -p tcp --dport 40000:50000 -j ACCEPT
