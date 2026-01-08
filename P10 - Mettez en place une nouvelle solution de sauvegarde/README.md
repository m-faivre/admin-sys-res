# 🧩 Projet – Stratégie de sauvegarde avec rsync

## 📘 Description du projet

Depuis quelque temps, la **mairie de Mareuil-sur-Oise** exploite de manière systématique les **technologies de virtualisation** pour ses services informatiques, internes comme publics.

Le **logiciel de sauvegarde actuellement en place** n’étant pas compatible avec ces technologies, il devient nécessaire de définir et de mettre en œuvre une **véritable stratégie de sauvegarde**.

Votre responsable, **Monsieur Andréas Sauvage**, DSI, vous confie un **projet de recherche et développement** autour de l’outil libre et gratuit **rsync**, afin de répondre à ce besoin.

---

## ⚙️ Livrables réalisés

### 🧱 1. Support de présentation de l’intervention
- Support au format **PowerPoint / Google Slides / PDF**
- Présentation synthétisant :
  - la **problématique d’origine**
  - le **schéma des flux**
  - les **stratégies de sauvegarde**
  - la **solution mise en place**, incluant les options rsync retenues
  - la **procédure de restauration**

### 🧱 2. Traces des sauvegardes incrémentales (LOG)
- Fichier de traces **rsync** des sauvegardes incrémentales

### 🧱 3. Traces des restaurations incrémentales (LOG)
- Fichier de traces **rsync** des restaurations incrémentales

### 🧱 4. Traces des sauvegardes différentielles (LOG)
- Fichier de traces **rsync** des sauvegardes différentielles

### 🧱 5. Traces des restaurations différentielles (LOG)
- Fichier de traces **rsync** des restaurations différentielles

### 🧱 6. Scripts et planification des tâches
- Scripts de **sauvegarde** et de **restauration**
- Configuration du **planificateur de tâches**
- Export de la configuration au format **crontab.txt**

---

## 🧰 Technologies utilisées

- **rsync**
- Systèmes Linux
- Sauvegardes incrémentales et différentielles
- Planification de tâches (**cron**)
- Outils de supervision et de journalisation
