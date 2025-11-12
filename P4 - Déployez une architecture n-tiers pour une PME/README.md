# 🧩 Projet de formation – Infrastructure 3-tiers BeeSafe

## 📘 Description du projet

Vous travaillez chez **BeeSafe**, une startup d’assurance en ligne, en tant qu’**administrateur systèmes et réseaux**.  
Vous faites partie de l’équipe chargée de l’exploitation des sites web de l’entreprise et du maintien en condition opérationnelle de l’infrastructure.  

Un nouveau site web basé sur des technologies **open source** doit être déployé.  
Il a été décidé de l’installer selon une **architecture 3-tiers** afin de faciliter la maintenance, l’isolation des services et le déploiement.  

Votre rôle consiste à **concevoir et déployer l’infrastructure complète** permettant d’héberger ces trois services :
- un **serveur DNS (BIND9)**,
- un **serveur web (Apache/PHP)**,
- un **serveur de base de données (MySQL)**.

---

## ⚙️ Scripts et configurations développés

### 🧱 1. Configuration DNS – `BIND9`
**Objectif :** assurer la résolution directe et inverse du domaine `beesafe.co`.

#### ✨ Fonctionnalités principales
- Déclaration de la **zone directe** `beesafe.co` et de la **zone inverse** `20.168.192.in-addr.arpa`.  
- Enregistrements DNS :
  - `A` : résolution des noms `ns.beesafe.co` et `www.beesafe.co`
  - `NS` : désignation du serveur de noms
  - `PTR` : résolution inverse du site web vers `www.beesafe.co`

#### 🔐 Points techniques
- Fichiers de configuration :
  - `named.conf.local`
  - `db.beesafe.co`
  - `reverse.beesafe.co`
- Serveur BIND9 conteneurisé (`bind9:9.20`)
- IP du conteneur : **192.168.20.134/24**
- Port d’écoute : **53 (TCP/UDP)**

---

### 🧱 2. Serveur Web – `Apache / PHP`
**Objectif :** héberger le site web de BeeSafe sur un conteneur Apache avec PHP 8.2.

#### ✨ Fonctionnalités principales
- Configuration d’un **VirtualHost** pour le domaine `www.beesafe.co`
- Autorisation des **fichiers .htaccess** et des liens symboliques
- Gestion des **logs Apache** :
  - `error.log`
  - `access.log`

#### 🔐 Points techniques
- Image Docker : **php:8.2-apache**
- Port exposé : **80**
- Répertoire racine : `/var/www/html`
- IP du conteneur : **192.168.20.140/24**

---

### 🧱 3. Base de données – `MySQL`
**Objectif :** créer et configurer la base de données de l’application BeeSafe.

#### ✨ Fonctionnalités principales
- Création du compte utilisateur MySQL :
  ```sql
  CREATE USER IF NOT EXISTS 'micka'@'%' IDENTIFIED BY '^&DW_oen@FqX65mL';
  GRANT ALL PRIVILEGES ON beesafe_db.* TO 'micka'@'%';
  FLUSH PRIVILEGES;
