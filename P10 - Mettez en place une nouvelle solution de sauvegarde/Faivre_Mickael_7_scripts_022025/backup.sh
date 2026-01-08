#!/bin/bash

# =============================
# SCRIPT : Sauvegarde via rsync
# AUTEUR : Mickaël Faivre
# DATE : 19/02/2025
# VERSION : 0.4
# DESC. : Script de sauvegarde incrémentale, différentielle ou complète et de restaurations des données
# USAGE : ./backup.sh [options]
# DEPENDANCES :
#	- vars.sh : Variables du script
#	- function.sh : Fonctions appelées par le script
#==============================

# CHANGELOG :
#
# v0.4 - Gestion des paramètres pour permettre un lancement par cron - Exemple : backup --site | backup --full
#	- Les paramètres acceptés sont les valeurs données dans les tableaux INCR_FILES et DIFF_FILES
#	- Le paramètre --full permet une sauvegarde complète en bouclant sur les éléments des deux tableaux
# v0.3 - Refonte du script. Passage à un menu interactif
# v0.2 - Export des fonctions et des variables pour la lisibilité/maintenance
# v0.1b - Ajout de fonctions pour création des fichiers de log, gestion des backups, nettoyage du cache
# v0.1a - Ajout d'une fonction de logs
# v0.1 - Première version : logs, backup incrémental

#
# Les variables qui n'ont pas vocation à être modifiées
#
# Tableau du menu principal
declare -a MAIN_OPTIONS=("Afficher la liste des dernières sauvegardes" "Effectuer une sauvegarde complète" "Menu des sauvegardes incrémentales" "Menu des sauvegardes différentielles" "Menu de restauration des données" "Quitter le gestionnaire de sauvegardes")
# Menu incrémental
declare -a INCR_OPTIONS=("Effectuer une sauvegarde incrémentale complète" "Sauvegarder un sous-dossier spécifique" "Retourner au menu principal" "Quitter le gestionnaire de sauvegardes")
# Menu différentiel
declare -a DIFF_OPTIONS=("Effectuer une sauvegarde différentielle complète" "Sauvegarder un sous-dossier spécifique" "Retourner au menu principal" "Quitter le gestionnaire de sauvegardes")
# Menu restauration
declare -a REST_OPTIONS=("Afficher la vue détaillée des sauvegardes" "Restaurer un fichier spécifique" "Restaurer depuis une sauvegarde complète" "Retourner au menu principal" "Quitter le gestionnaire de sauvegardes")


# Import des fichiers de variables et de fonctions
source vars.sh
source function.sh


# Trap le signal SIGNINT (CTRL+C)
trap sigint_handler INT


# On créé, sur le serveur distant, les sous-dossiers qui ont été placés pour une sauvegarde incrémentale (cf : $INCR_FILES dans vars.sh)
for FILE in "${INCR_FILES[@]}"; do
	make_dist_dir incr "$FILE"
done
# Idem pour les dossiers de la sauvegarde différentielle
FILE=""
for FILE in "${DIFF_FILES[@]}"; do
	make_dist_dir diff "$FILE"
done


# Appel de la fonction pour nettoyer les anciens fichiers de logs (cf vars.sh)
clear_backup



# Si aucun paramètre n'est passé à backup.sh pour exécuter le script, on appelle le menu
if [ -z "$1" ]; then

	# On lance un scan pour détecter la présence de sauvegardes interrompues
	# S'il y en a, on propose de les reprendre sinon on lance le menu principal

	scan_partial_sync

# Si un argument est passé
else

	# Suppression des -- de l'argument
	ARG=$(echo "$1" | sed 's/^--//')
	# Tableau contenant les deux types de sauvegardes
	declare -a MODE=("incr" "diff")

	# Si l'argument est --full on boucle pour faire une sauvegarde complète de chaque fichier (INCR_FILES && DIFF_FILES)
	if [[ "${ARG,,}" == "full" ]]; then
		for TYPE in "${MODE[@]}"; do
			for FILE in "${FILES[@]}"; do
				make_rsync full "$LOCAL_DIR/$FILE" "$SRV_FULL_DIR/$FILE/$DATE"
				logs "INFO" "Sauvegarde automatique complète lancée." "$FULL_LOG_FILE"
				clear_cache
			done
		done

	# Si l'argument est autre
	else
		# Somme des deux tableaux pour la gestion des erreurs
		COUNT=$(( ${#INCR_FILES[@]} + ${#DIFF_FILES[@]} ))
		i=0
		# Boucle sur la tableau des types de sauvegardes
		for TYPE in "${MODE[@]}"; do
			UPP_TYPE="${TYPE^^}" # On passe la valeur de la var en majuscules
			# Déclaration des variables dynamiques
			declare -n DIR="SRV_${UPP_TYPE}_DIR"
			declare -n LOG="${UPP_TYPE}_LOG_FILE"
			declare -n FILES="${UPP_TYPE}_FILES"
			# Boucle sur la variable dynamique FILES (qui vaut INCR_FILES ou DIFF_FILES)
			for FILE in "${FILES[@]}"; do
				# Vérifier que l'argument passé existe dans les tableaux
				if [[ "${FILE,,}" == "${ARG,,}" ]]; then
					BKP=$(get_last_backup "$TYPE" "$FILE")
					make_rsync "$TYPE" "$LOCAL_DIR/$FILE" "$DIR/$FILE/$DATE" "$BKP"
					logs "INFO" "Sauvegarde automatique du dossier $ARG." "$LOG"
					clear_cache # Nettoyage du cache des VM
					break
				else
					((i++)) # Incrémentation à chaque fois que le paramètre n'est pas dans un tableau
				fi
			done
		done
		# Si la somme des tableaux est égale à l'incrémentation de i, alors le paramètre est faux
		if (( COUNT == i )); then
			echo -e "${RED}Le paramètre donné ($2) est incorrect et n'existe pas dans les tableaux de fichiers de sauvegardes incrémentales ou différentielles.${NC}"
		fi
	fi
fi
