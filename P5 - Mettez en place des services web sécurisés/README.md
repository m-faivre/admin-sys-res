# 🧩 Projet de formation – Infrastructure réseau Rainbow Bank

## 📘 Description du projet

**Rainbow Bank** est une banque internationale basée à **Paris**, spécialisée dans les services financiers numériques.  
Vous occupez le poste d’**administrateur systèmes et réseaux** au sein du **Pôle Systèmes et Réseaux**, rattaché à la **Direction Infrastructure et Logistique (DIL)**.  
Ce pôle, dirigé par **Aurélie Fernandez**, compte **environ 70 collaborateurs** et assure la gestion de l’ensemble des infrastructures techniques de la banque.

Dans le cadre de la modernisation de ses services internes, vous êtes chargé de **déployer et configurer une infrastructure réseau sécurisée** intégrant :
- deux **sites web distincts** (public et administratif),  
- un **service FTP sécurisé**,  
- et un **filtrage réseau avancé** pour le contrôle des flux entre interfaces.

---


## ⚙️ Services et configurations développés

### 🧱 1. Services Web – `Apache / PHP`
**Objectif :** héberger deux sites distincts accessibles selon le réseau d’origine, avec redirection HTTPS.

#### ✨ Fonctionnalités principales
- Mise en place de **deux VirtualHosts** :
  - `www.rainbowbank.com` → site **public**, accessible via les **interfaces publique et privée**
  - `admin.rainbowbank.com` → site **administratif**, accessible uniquement via l’**interface privée**
- Activation du **HTTPS obligatoire** avec redirection automatique **HTTP → HTTPS**
- Installation et configuration des **certificats SSL**
- Gestion des **journaux distincts** pour chaque site :
  - `www-access.log` / `www-error.log`
  - `admin-access.log` / `admin-error.log`

#### 🔐 Points techniques
- **Système :** Debian 12.6  
- **Services :** Apache 2.4 / PHP 8.2  
- **Modules activés :** `ssl`, `rewrite`, `headers`, `vhost_alias`  
- **Ports :** 80 / 443  
- **Fichiers de configuration :**
  - `rainbow_public.conf`
  - `rainbow_admin.conf`
  - `default-ssl.conf`  

---


### 🧱 2. Service FTP – `vsftpd`
**Objectif :** permettre un transfert sécurisé de fichiers internes entre utilisateurs.

#### ✨ Fonctionnalités principales
- Configuration du service **vsftpd** en mode **sécurisé (FTPS explicite)**  
- Création d’un espace FTP isolé pour chaque utilisateur  
- Activation du **chroot** pour interdire l’accès hors du répertoire personnel  
- Configuration du **mode passif** pour compatibilité avec le pare-feu  
- Journalisation complète des connexions et transferts

#### 🔐 Points techniques
- **Service :** vsftpd  
- **Ports :** 21 et 40000–50000 (mode passif)  
- **Certificat TLS :** `/etc/ssl/private/vsftpd.pem`  
- **Logs :** `/var/log/vsftpd.log`  
- **Fichier principal :** `vsftpd.conf`  

---


### 🔁 3. Filtrage réseau – `iptables / netfilter`
**Objectif :** assurer la sécurité de l’infrastructure en limitant les accès selon les interfaces et les services.

#### ✨ Fonctionnalités principales
- **Politique par défaut restrictive** :  
  - `INPUT DROP`  
  - `FORWARD DROP`  
  - `OUTPUT ACCEPT`
- **Ouverture sélective des ports :**  
  - 22 (SSH)  
  - 21 + 40000–50000 (FTP)  
  - 80 / 443 (Web)
- **Filtrage par interface :**  
  - Interface publique → accès uniquement au site web public  
  - Interface privée → accès complet (site admin, SSH, FTP)
- **Persistance des règles** après redémarrage

#### 🔐 Points techniques
- Script automatisé :
  ```bash
  #!/bin/bash
  iptables -P INPUT DROP
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -p tcp --dport 22 -i eth1 -j ACCEPT
  iptables -A INPUT -p tcp --dport 21 -i eth1 -j ACCEPT
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  iptables -A INPUT -p tcp --dport 40000:50000 -i eth1 -j ACCEPT
  iptables-save > /etc/iptables/rules.v4

    Sauvegarde : /etc/iptables/rules.v4

    Vérification : iptables -L -v

#### 🧰 Technologies utilisées

    Debian 12.6

    Apache 2.4 / PHP 8.2

    vsftpd

    iptables / netfilter

    OpenSSL

    FileZilla / curl / lftp (tests)
