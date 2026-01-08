# =============================
# SCRIPT : Configuration pour backup.sh (DEPENDANCE)
# AUTEUR : Mickaël Faivre
# DATE : 19/02/2025
# VERSION : 0.1d
# DESC. : Ensemble des variables de configurations pour backup.sh
# USAGE : N/A
# DEPENDANCES :
#       - backup.sh : Script principal pour la gestion des sauvegardes
#       - function.sh : Fonctions appelées par le script
#==============================

# CHANGELOG :
#
# v0.1d - Ajout des variables pour les rotations
# v0.1c - Définition des chemins globaux (SRV_FULL || INCR || DIFF_DIR) dans des variables
# v0.1b - Ajout de couleurs en ANSI. Ajout de variables pour les fichiers de logs.
# v0.1a - Ajout de tableaux pour les fichiers gérés en incrémental ou en différentiel
# v0.1 - Export des variables de configuration dans un fichier distinct




#
# Dossiers et sous-dossiers
#
# Répertoire principal contenant les sous-dossiers à sauvegarder
LOCAL_DIR="/home/micka/Dir"

#
# Sauvegarde incrémentale
#

# Liste des éléments présents dans le répertoire principal et que l'on peut passer en paramètre de commande
# Pour faciliter l'automatisation, il est conseillé que chacun de ces éléments
# Un sous-dossier soit créé dans le répertoire principal
# Exemple de sous-dossier : Elément Site : Répertoire : $LOCAL_DIR/Site
# Exemple de paramètre : Elément Site : Commande : ./incr.sh Site
declare -a INCR_FILES=("Site" "RH" "Mails" "Tickets")

#
# Sauvegarde différentielle
#

# Liste des éléments présents dans le répertoire principal et que l'on peut passer en paramètre de commande
# Le fonctionnement des sous-dossiers et des paramètres est similaire à la sauvegarde incrémentale
declare -a DIFF_FILES=("Machines")

# Cycle, en jours, des backups complets. Au dela, les sauvegardes sont supprimées
FULL_CYCLE="15"

# Cycle, en jours, des backups incrémentaux. Au dela, les sauvegardes sont supprimées
INCR_CYCLE="7"

# Cycle, en jours, des backups différentiels. Au dela, les sauvegardes sont supprimées
DIFF_CYCLE="7"


#
# Fichiers de logs
#

# Nom du fichier contenant les logs pour les sauvegardes incrémentales
INCR_LOG_FILE=".incr.log"

# Nom du fichier contenant les logs pour les sauvegardes différentielles
DIFF_LOG_FILE=".diff.log"

# Nom du fichier contenant les logs pour les sauvegardes complètes
FULL_LOG_FILE=".full.log"

# Nom du fichier contenant les logs pour la restauration des sauvegardes
REST_LOG_FILE=".rest.log"


#
# Serveur distant
#

# Login et IP ou DNS  utilisés pour se connecter en SSH au serveur de backup
# Exemple : login@mon-serveur.loc
SERVER="micka@SRV"

# Répertoire des sauvegardes incrémentales
SRV_INCR_DIR="/home/micka/Backup/Incr"

# Répertoire des sauvegardes différentielles
SRV_DIFF_DIR="/home/micka/Backup/Diff"

# Répertoire de la sauvegarde complète
SRV_FULL_DIR="/home/micka/Backup/Full"


#
# Couleurs utilisées dans le script
#

#Rouge
RED="\e[31m"

# Jaune
YEL="\e[33m"

# Vert
GRE="\e[32m"

# Vert gras
BGRE="\033[1;32m"

# Bleu
BLU="\e[34m"

# Cyan
CYA="\e[36m"

# Suppression des couleurs
NC="\e[0m"
