# =============================
# SCRIPT : Fonctions pour backup.sh (DEPENDANCE)
# AUTEUR : Mickaël Faivre
# DATE : 19/02/2025
# VERSION : 0.4
# DESC. : Ensemble des fonctions utilisées par backup.sh
# USAGE : DEPENDANCE DE BACKUP.SH
# DEPENDANCES :
#       - backup.sh : Script principal à appeler
#	- vars.sh : Variables du script
#==============================

# CHANGELOG :
#
# v0.4 - Correction de divers bugs. Refactoring. Implémentation restauration
# v0.3 - Implémenation de la reprise de sauvegarde interrompue
# v0.2 - Ajout d'une animation de traitement. Refactoring
# v0.1 - Refactoring de certaines fonctions


# Import du fichier de variables
source vars.sh


# Date - Au format JJ-MM-AAAA
DATE=$(date +\%d-\%m-\%Y)

# Heure - Au format HH:MM:SS
HOUR=$(date +\%H:\%M:\%S)

# Message pour quitter et clear l'écran
PRESS_BUTTON='read -n 1 -r -s -p "Appuyez sur une touche pour revenir au menu..." && clear'

quit() {
	echo -e "${YEL}Fermeture du script...${NC}"
	clear_cache
	rm -f "$RSYNC_OUTPUT"
	tput cnorm
	exit 0
}

# Fonction - Insertion des logs
logs() {
	local TYPE
        local MSG="$2"
	local LOG_FILE="$3"
	case $1 in
		INFO|ERREUR|WARNING)
			TYPE=$1
			shift
			;;
	esac

        echo "$DATE - $HOUR [$TYPE] $MSG" >> "$LOG_FILE"
}

# Fonction - Gestion de la synchronisation en fonction du mode demandé
# make_rsync MODE SRC DEST [REF]
make_rsync() {
	local MODE="$1"  # Mode : full, incr, diff, restore
	local SRC="$2"
	local DEST="$3"
	local REF="$4"
	local LOG_FILE


	# Vérification des arguments
	if [[ $MODE != "full" ]]; then
		if [[ -z "$MODE" || -z "$SRC" || -z "$DEST" ]]; then
			echo -e "${YEL}Usage : make_rsync <mode> <src> <dest> [ref]${NC}"
			return 1
		fi
	fi

	# Construction de la commande rsync
	local RSYNC_OPTS=(-a --progress --partial --partial-dir=.partial)
	local RSYNC_ARGS=()
	local TYPE
	case "$MODE" in
		"full") LOG_FILE="$FULL_LOG_FILE"; RSYNC_ARGS=("$SRC" "$SERVER:$DEST"); TYPE="Complet" ;;
		"incr") LOG_FILE="$INCR_LOG_FILE"; RSYNC_ARGS=(--link-dest="$REF" "$SRC" "$SERVER:$DEST"); TYPE="Incrémental" ;;
		"diff") LOG_FILE="$DIFF_LOG_FILE"; RSYNC_ARGS=(--compare-dest="$REF" "$SRC" "$SERVER:$DEST"); TYPE="Différentiel" ;;
		"restore") LOG_FILE="$REST_LOG_FILE"; RSYNC_ARGS=("$SERVER:$SRC" "$DEST"); TYPE="Restauration" ;;
		*) echo "Mode inconnu : $MODE"; return 1 ;;
	esac

        # Vérification du répertoire : SRC
	if ! [ -e "$SRC" ] && ! ssh "$SERVER" "[ -e '$SRC' ]"; then
		echo -e "${RED}Le fichier ou répertoire source $SRC est introuvable.${NC}"
		logs "ERREUR" "Synchronisation impossible. Dossier ou fichier source introuvable : $SRC" "$LOG_FILE"
		return 1
	fi

	# Test d'un dry run pour voir si la sauvegarde est utile
	if ! rsync "${RSYNC_OPTS[@]}" --dry-run --itemize-changes "${RSYNC_ARGS[@]}" | tail -n +2 | grep -q .; then
		echo -e "${YEL}Aucune modification détectée dans $SRC. Sauvegarde non nécessaire.${NC}"
		logs "INFO" "Sauvegarde non effectuée. Aucun changement détecté. Source : $SRC - Destination : $DEST" "$LOG_FILE"
		return 0
	fi

	# Exécution avec gestion des logs et animation
	RSYNC_OUTPUT=$(mktemp)
	stdbuf -oL rsync "${RSYNC_OPTS[@]}" "${RSYNC_ARGS[@]}" 2>&1 | tee "$RSYNC_OUTPUT" > /dev/null &

	#tail -f "$RSYNC_OUTPUT"

	local PID=$!

	# Si le PID rsync existe, on appelle la fonction d'animation et on attend la fin
	if ps -p $PID > /dev/null 2>&1; then
		show_anim $PID "$RSYNC_OUTPUT"
		wait $PID
	fi

	local STATUS=$?
	echo " "

	# On nettoie les fichiers temporaires quand le backup est terminé
	rm -f "$RSYNC_OUTPUT"

	# Affichage d'un résumé du backup
	if [ $STATUS -eq 0 ]; then
		echo -e "${GRE}Synchronisation terminée avec succès.${NC}"
		echo -e "Type de rsync : ${YEL}$TYPE${NC}"
		echo -e "Dossier source : ${YEL}$SRC${NC}"
		echo -e "Dossier de destination : ${YEL}$DEST${NC}"
		[ -n "$REF" ] && echo -e "Dossier de référence : ${YEL}$REF${NC}"
		echo -e "${CYA}----------------------------------------${NC}"
		logs "INFO" "Synchronisation réussie. Type : $TYPE - Source : $SRC - Destination : $DEST" "$LOG_FILE"
	else
		echo -e "${RED}Erreur lors de la synchronisation des fichiers...${NC}"
		logs "ERREUR" "Impossible d'exécuter rsync : $(cat "$RSYNC_OUTPUT")" "$LOG_FILE"
	fi

	return $STATUS
}

# Fonction - Vérification et création, si besoin est, des sous-dossiers contenant les backup sur le serveur distant
make_dist_dir() {
	local DIR
	local LOG_FILE

	case "$1" in
		"incr") LOG_FILE="$INCR_LOG_FILE"; DIR="$SRV_INCR_DIR/$2" ;;
		"diff") LOG_FILE="$DIFF_LOG_FILE"; DIR="$SRV_DIFF_DIR/$2" ;;
		*) return 1 ;;
	esac

	# Vérification de la présence des dossiers distants
	# Si absent, mkdir pour créer l'arborescence
	if ! ssh "$SERVER" "[ -d '$DIR' ]"; then
		local MKDIR=$(ssh "$SERVER" "mkdir -p $DIR" 2>&1)
		local ERR_MKDIR=$?
		if [ $ERR_MKDIR -ne 0 ]; then
			echo "Erreur lors de la création du sous-dossier $2 sur le serveur."
			echo "$MKDIR"
			logs "ERREUR" "Impossible de créer le sous-dossier $2 sur le serveur : $MKDIR" "$LOG_FILE"
		else
			logs "INFO" "Création du sous-dossier $2 dans $DIR" "$LOG_FILE"
		fi
	fi
}

# Fonction - Nettoyer le cache des Vms
# Appeler lors de la fermeture du script ou d'un ctrl+c
clear_cache() {
	sudo sysctl -w vm.drop_caches=3 > /dev/null 2>&1
	ssh "$SERVER" "sudo systemctl -w vm.drop_caches=3 > /dev/null 2>&1"
}

# Fonction - Récupérer la dernière sauvegarde
# get_last_backup [TYPE] [DIR] [SUBFOLD] - Recherche la dernière sauvegarde en fonction du type (incrémental, différentiel)
get_last_backup() {
	local SUBFOLD="$2"

	# Parsing (Remettre les dates dans le bon format, tier par date, garder le premier résultat, remettre la date au format JJ-MM-AAAA
	LAST_FULL=$(ssh "$SERVER" "
			ls -d '$SRV_FULL_DIR/$SUBFOLD'/*/ 2>/dev/null | \
			sed -E 's|([0-9]{2})-([0-9]{2})-([0-9]{4})|\3-\2-\1|' | \
			sort -t '-' -k1,1nr -k2,2nr -k3,3nr | \
			head -n 1 | \
			sed -E 's|([0-9]{4})-([0-9]{2})-([0-9]{2})|\3-\2-\1|'")

	LAST_INCR=$(ssh "$SERVER" "
                        ls -d '$SRV_INCR_DIR/$SUBFOLD'/*/ 2>/dev/null | \
                        sed -E 's|([0-9]{2})-([0-9]{2})-([0-9]{4})|\3-\2-\1|' | \
                        sort -t '-' -k1,1nr -k2,2nr -k3,3nr | \
                        head -n 1 | \
                        sed -E 's|([0-9]{4})-([0-9]{2})-([0-9]{2})|\3-\2-\1|'")

	declare -a MODE=("INCR" "DIFF")
	for TYPE in "${MODE[@]}"; do
		declare -n LOG="${TYPE}_LOG_FILE"
		if [[ -z "$LAST_FULL" ]]; then
			echo -e "${RED}Vous devez effectuer une sauvegarde complète avant de poursuivre...${NC}"
			logs "ERREUR" "Aucune sauvegarde complète détectée. Impossible de continuer." "$LOG"
			sleep 5
			exit 1
		else
			if [[ "$1" == "diff" ]]; then
				echo "$LAST_FULL"
				return 1
			fi
			if [[ "$1" == "incr" ]]; then
				if [[ -z "$LAST_INCR" ]]; then
					echo "$LAST_FULL"
					return 1
				else
					echo "$LAST_INCR"
					return 1
				fi
			fi
		fi
	done
}

# Fonction - Afficher la dernière sauvegarde en fonction du répertoire
# show_last_backup [TYPE] [DIR] [SUBFOLD]
show_last_backup() {
	local LOG_FILE
	local DIR="$2"
	local SUBFOLD
	[[ -n $3 ]] && SUBFOLD="$3"


	case $1 in
		"incr") LOG_FILE="$INCR_LOG_FILE";;
		"diff")	LOG_FILE="$DIFF_LOG_FILE";;
		"full") LOG_FILE="$FULL_LOG_FILE";;
	esac

	# Vérifier si le dossier existe sur le serveur
	if ! ssh "$SERVER" "[ -d '$DIR/$SUBFOLD' ]"; then
		echo -e "${YEL}Le dossier $DIR/$SUBFOLD n'existe pas sur le serveur.${NC}"
		logs "WARNING" "Vérification de la dernière sauvegarde impossible. Dossier introuvable : $DIR/$SUBFOLD"
		echo "Recherche de la dernière sauvegarde complète..."
		LAST_CPL=$(ssh "$SERVER" "
			ls -d '$DIR/$SUBFOLD'/*/ 2>/dev/null | \ # On récupère la liste des dossiers
			sed -E 's|([0-9]{2})-([0-9]{2})-([0-9]{4})|\3-\2-\1|' | \ # On inverse les dates au format AAAA-MM-JJ
			sort -t '-' -k1,1nr -k2,2nr -k3,3nr | \ # On tri par date
			head -n 1 | \ # On garde le premier
			sed -E 's|([0-9]{4})-([0-9]{2})-([0-9]{2})|\3-\2-\1|'") # On remet dans le bon ordre (JJ-MM-AAAA)


		if [[ -z "$LAST_CPL" ]]; then
			echo -e "Aucune sauvegarde complète n'a été trouvée.${NC}"
			echo "Vous devez effectuer une sauvegarde complète avant de poursuivre..."
			logs "ERREUR" "Aucune sauvegarde complète trouvée. Impossible de continuer." "$LOG_FILE"
			return 1
		else
			echo "$LAST_CPL"
			return 0
		fi
	fi

	# Exécuter la commande directement sur le serveur via SSH
	LAST_BKP=$(ssh "$SERVER" "
		ls -d '$DIR/$SUBFOLD'/*/ 2>/dev/null | \
		sed -E 's|([0-9]{2})-([0-9]{2})-([0-9]{4})|\3-\2-\1|' | \
		sort -t '-' -k1,1nr -k2,2nr -k3,3nr | \
		head -n 1 | \
		sed -E 's|([0-9]{4})-([0-9]{2})-([0-9]{2})|\3-\2-\1|'")


	# Vérifier si une sauvegarde a été trouvée
	if [[ -z "$LAST_BKP" ]]; then
		echo -e "${YEL}Aucune sauvegarde trouvée dans $DIR/$SUBFOLD ${NC}"
		logs "WARNING" "Aucune sauvegarde trouvée dans $DIR/$SUBFOLD" "$LOG_FILE"
		return 1
	else
		echo "$LAST_BKP"
		return 0
    fi
}

# Fonction - Création d'un menu en fonction des arguments passés
# Le tableau des options défini dans backup.sh est envoyé comme argument pour construire un menu
make_menu() {
	local TITLE="$1"
	shift
	local OPTIONS=("$@")
	local OPT

	while true; do
		echo "=============================================="
		echo "	$TITLE"
		echo "=============================================="


		local COLUMNS=1
		local PS3="Veuillez entrer le numéro de l'option désirée : "
		select OPT in "${OPTIONS[@]}"; do
			if  [[ -n "$OPT" ]]; then
				return "$REPLY"
			else
				echo -e "${RED}Choix incorrect. Veuillez patienter...${NC}"; sleep 2; clear;
			fi
			break
		done
	done
}

# Fonction - Affichage du menu principal
show_main_menu() {
	clear
	while true; do
		make_menu "	Backup Manager" "${MAIN_OPTIONS[@]}"

		case $? in
			1) # Boucle pour afficher les dernières sauvegardes incrémentales, différentielles et complètes
				local SUBFOLD
				echo "Liste des dernières sauvegardes :"
				for SUBFOLD in "${INCR_FILES[@]}"; do
					R1=$(show_last_backup incr "$SRV_INCR_DIR" "$SUBFOLD")
					R2=$(show_last_backup incr "$SRV_FULL_DIR" "$SUBFOLD")
					echo -e "📁 ${BGRE}$SUBFOLD :${NC}\n- Incrémentale : ${YEL}$SERVER:$R1${NC}\n- Complète : ${YEL}$SERVER:$R2${NC}"
				done
				SUBFOLD=""
				for SUBFOLD in "${DIFF_FILES[@]}"; do
					R1=$(show_last_backup diff "$SRV_DIFF_DIR" "$SUBFOLD")
					R2=$(show_last_backup diff "$SRV_FULL_DIR" "$SUBFOLD")
					echo -e "📁 ${BGRE}$SUBFOLD :${NC}\n- Différentiel : ${YEL}$SERVER:$R1${NC}\n- Complète : ${YEL}$SERVER:$R2${NC}"
				done
				eval "$PRESS_BUTTON"
				;;
			2) # Sauvegarde complète de chaque sous-dossier enregistrés dans les variables INCR_FILES et DIFF_FILES
				local SUBFOLD
				for SUBFOLD in "${INCR_FILES[@]}"; do
					make_rsync full "$LOCAL_DIR/$SUBFOLD/" "$SRV_FULL_DIR/$SUBFOLD/$DATE"
				done
				SUBFOLD=""
				for SUBFOLD in "${DIFF_FILES[@]}"; do
					make_rsync full "$LOCAL_DIR/$SUBFOLD/" "$SRV_FULL_DIR/$SUBFOLD/$DATE"
				done
				eval "$PRESS_BUTTON"
				;;
			3) show_bkp_menu incr ;; # Appel de la fonction pour afficher le menu des sauvegardes incrémentales
			4) show_bkp_menu diff ;; # Appel de la fonction pour afficher le menu des sauvegardes différentielles
			5) show_rest_menu ;; # Appel de la fonction pour afficher le menu des restaurations de sauvegardes
			6) quit ;;
		esac
	done
}

# Fonction - Menu avec gestion dynamique du contenu (sauvegarde incrémentale et différentielle)
# show_bkp_menu incr || diff
show_bkp_menu() {
	clear

	# Défini le type de mode (incr || diff) - Argument passé lors de l'appel fonction
	local MODE="${1^^}"
	if [[ "$MODE" != "INCR" && "$MODE" != "DIFF" ]]; then
		echo -e "${RED}Erreur lors de l'accès au menu. L'argument passé est incorrect.${NC}"; exit 1;
	fi

	case $MODE in
		"INCR") local TXT="incrémentale";;
		"DIFF") local TXT="différentielle";;
	esac

	declare -n DIR="SRV_${MODE}_DIR"
	declare -n LOG="${MODE}_LOG_FILE"
	declare -n OPTIONS="${MODE}_OPTIONS"
	declare -n FILES="${MODE}_FILES"

	while true; do
		make_menu "	Sauvegarde $TXT" "${OPTIONS[@]}"

		case $? in
			1) # Boucle sur INCR_FILES ou DIFF_FILES pour effectuer le type de sauvegarde définie - Sauvegarde entière
				local SUBFOLD
				local LAST_BKP=$([ "$MODE" = "DIFF" ] && echo "$SRV_FULL_DIR" || echo "$DIR")
				logs "INFO" "Création d'une sauvegarde $TXT complète..." "$LOG"
				for SUBFOLD in "${FILES[@]}"; do
					local REF=$(get_last_backup "$1" "$SUBFOLD")
					make_rsync "$1" "$LOCAL_DIR/$SUBFOLD/" "$DIR/$SUBFOLD/$DATE" "$REF"
				done
				eval "$PRESS_BUTTON"
				;;

			2) # Idem que précédent, mais ici on choisi précisement le dossier qu'on veut sauvegarder et on adapte le type de backup en fonction de sa présence dans INCR_FILES ou DIFF_FILES
				local SUBFOLD
				local LAST_BKP=$([ "$MODE" = "DIFF" ] && echo "$SRV_FULL_DIR" || echo "$DIR")
				echo "Liste des sous-répertoires disponible : "
				PS3="Veuillez entrer le sous-dossier à sauvegarder : "
				select SUBFOLD in "${FILES[@]}"; do
					if [[ -n "$SUBFOLD" ]]; then
						logs "INFO" "Création d'une sauvegarde $TXT par dossier" "$LOG"
						local REF=$(get_last_backup "$1" "$SUBFOLD")
						make_rsync "$1" "$LOCAL_DIR/$SUBFOLD/" "$DIR/$SUBFOLD/$DATE" "$REF"
					else
						echo -e "${RED}Choix invalide. Veuillez réessayer...${NC}"
					fi
					eval "$PRESS_BUTTON"
					break
				done
				;;
			3) show_main_menu ;;
			4) quit ;;
		esac
	done
}

# Fonction - Menu pour la restauration des données
show_rest_menu() {
	clear

	while true; do
		make_menu "     Restauration des données" "${REST_OPTIONS[@]}"

		case $? in
			1) # Affiche l'arborescence complète de SRV_FULL_DIR || SRV_INCR_DIR || SRV_DIFF_DIR
				declare -A OPT_SAVE
				OPT_SAVE["Complète"]="full"
				OPT_SAVE["Incrémentale"]="incr"
				OPT_SAVE["Différentielle"]="diff"

				PS3="Veuillez choisir le type de sauvegardes à lister : "
				echo "=============================================="
				select MENU in "${!OPT_SAVE[@]}"; do
					if [[ -n "$MENU" ]]; then
						TYPE="${OPT_SAVE[$MENU]}"
						TYPE="${TYPE^^}"
						declare -n DIR="SRV_${TYPE}_DIR"
						ARG=$([ "$TYPE" = "INCR" ] && echo "--inodes" || echo "")
						LIST=$(ssh "$SERVER" "tree $ARG $DIR")
						echo -e "${YEL}Liste des sauvegardes et de leurs contenus pour $SERVER:$DIR :${NC}"
						echo -e "$LIST"
						eval "$PRESS_BUTTON"
						break
					else
						echo -e "${RED}Choix invalide. Veuillez réessayer...${NC}"
					fi
				done
				;;


			2) # Restauration d'un fichier/dossier spécifique
				declare -a FIND_PATHS
				echo "=============================================="
				read -rp "Veuillez entrer le nom du fichier recherché : " FILE
				declare -a TYPE=("FULL" "DIFF" "INCR")
				i=1
				j=0
				# Boucle sur l'ensemble des éléments
				for SEARCH in "${TYPE[@]}"; do
					declare -a FIND_LINE
					declare -n DIR_TYPE="SRV_${SEARCH}_DIR"
					# Ajoute le résultat d'un find dans un tableau
					mapfile -t FIND_FILE < <(ssh "$SERVER" "find $DIR_TYPE -type f -iname \"*$FILE*\"")
					case $SEARCH in
						"FULL") TEXT="complète" ;;
						"DIFF") TEXT="différentielle" ;;
						"INCR") TEXT="incrémentale" ;;
					esac
					# Si le tableau contient 1 ou +, on liste les éléments
					if [[ "${#FIND_FILE[@]}" -ge 1 ]]; then
						echo -e "${BGRE}${#FIND_FILE[@]} occurrences dans la sauvegarde $TEXT :${NC}"
						for ENTRY in "${FIND_FILE[@]}"; do
							# Affichage de l'entrée et stockage dans un tableau à portée globale avec une correspondance numéro -> valeur
							echo -e "$i) ${CYA}${ENTRY}${NC}"
							FIND_PATHS[i]="$ENTRY"
							((i++))
						done
						echo ""
					else # Tableau vide, on le précise
						echo -e "${RED}Aucun résultat trouvé dans la sauvegarde $TEXT.${NC}"
						echo ""
						((j++))
					fi
				done
				# Si les trois types de backups (full, incr, diff) sont vides, on permet à l'user de quitter le menu
				if (( j == 3 )); then
					eval "$PRESS_BUTTON"
				fi
				EXIT=$((i++))
				echo "$EXIT) Revenir au menu précédent"
				echo ""
				# Gestion de la saisie utilisateur
				while true; do
					read -rp "Entrez le numéro de ligne de la sauvegarde que vous voulez restaurer : " LINE
					# Si la saisie n'est pas numérique, choix invalide
					if ! [[ "$LINE" =~ ^[0-9]+$ ]]; then
						echo -e "${RED}Choix invalide. Veuillez réessayer...${NC}"
						continue
					fi
					# Si la saisie est en dehors des valeurs du tableau, choix invalide
					LINE=$((LINE))
					if (( LINE < 1 || LINE > EXIT )); then
						echo -e "${RED}Choix invalide. Veuillez réessayer...${NC}"
						continue
					fi
					# Si la saisie correspond à la valeur de l'option pour quitter, on quitte
					if (( LINE == EXIT )); then
						show_rest_menu
						break
					fi
					FILE_PATH="${FIND_PATHS[LINE]}"
					# Nettoyage de la valeur du tableau
					for CLEAN in "${TYPE[@]}"; do
						declare -n DIR="SRV_${CLEAN}_DIR"
						FILE_PATH=${FILE_PATH#*"$DIR"}
					done
					# Définition du répertoire locale grâce à la valeur du tableau
					DEST_PATH="$LOCAL_DIR/Restore$FILE_PATH"
					if [ ! -d "$(dirname "$DEST_PATH")" ]; then
						mkdir -p "$(dirname "$DEST_PATH")"
					fi
					echo -e "${CYA}Restauration depuis ${YEL}$SERVER:${FIND_PATHS[LINE]} ${CYA}vers ${YEL}$DEST_PATH ${CYA}...${NC}"
					make_rsync restore "${FIND_PATHS[LINE]}" "$DEST_PATH"
					eval "$PRESS_BUTTON"
					break
				done
				;;


			3) # Sensiblement la même chose que précédemment, mais pour les sauvegardes complètes - Grosse refactorisation possible
				echo "=============================================="
				echo "Liste des sauvegardes complètes disponibles sur le serveur :"
				i=1
				j=0
				declare -a FIND_BKP
				for FOLD in "${INCR_FILES[@]}" "${DIFF_FILES[@]}"; do
					mapfile -t FULL < <(ssh "$SERVER" "find "$SRV_FULL_DIR/$FOLD" -type d -maxdepth 1 -mindepth 1")
					if [[ "${#FULL[@]}" -ge 1 ]]; then
						echo ""
						echo -e "${BGRE}${#FULL[@]} sauvegardes complètes pour $FOLD :${NC}"
						echo ""
						for RESULT in "${FULL[@]}"; do
							echo -e "$i) ${CYA}$RESULT${NC}"
							FIND_BKP[i]="$RESULT"
							((i++))
						done
					else
						echo ""
						echo -e "${RED}Aucune sauvegarde complète trouvée pour $FOLD.${NC}"
						echo ""
						((j++))
					fi
				done
				COUNT=$(( ${#INCR_FILES[@]} + ${#DIFF_FILES[@]} ))
				if (( j == COUNT )); then
					eval "$PRESS_BUTTON"
				fi
				EXIT=$((i++))
				echo ""
				echo "$EXIT) Revenir au menu précédent"
				echo ""
				while true; do
					read -rp "Veuillez entrer le numéro de la sauvegarde complète que vous souhaitez restaurer : " LINE
					if ! [[ "$LINE" =~ ^[0-9]+$ ]]; then
                                                echo -e "${RED}Choix invalide. Veuillez réessayer...${NC}"
                                                continue
                                        fi
                                        LINE=$((LINE))
                                        if (( LINE < 1 || LINE > EXIT )); then
                                                echo -e "${RED}Choix invalide. Veuillez réessayer...${NC}"
                                                continue
                                        fi
                                        if (( LINE == EXIT )); then
                                                show_rest_menu
                                                break
                                        fi
					FULL_BKP="${FIND_BKP[LINE]}"
					BKP=${FULL_BKP#*"$SRV_FULL_DIR"}
					BKP_DIR=$(dirname "$BKP")
					LOCAL="$LOCAL_DIR/Restore$BKP_DIR"
					echo -e "${CYA}Restauration dans ${YEL}$SERVER:$FULL_BKP ${CYA}dans ${YEL}$LOCAL_DIR/Restore$BKP ${CYA}...${NC}"
					make_rsync restore "$FULL_BKP" "$LOCAL_DIR/Restore$BKP_DIR"
					eval "$PRESS_BUTTON"
					break
				done
				 ;;
			4) show_main_menu ;;
			5) quit ;;

		esac
	done
}


# Fonction - Vérification de reprise des sauvegardes interrompues
# La fonction est appelée par le script principal à son exécution
scan_partial_sync() {

	# Find dans l'ensemble des répértoires de sauvegardes du serveur
	# On recherche un .partial (utilisé dans rsync lors de la sauvegarde)
	# Si .partial présent, alors une sauvegarde n'a pas été terminée correctement
	local PARTIAL=$(ssh "$SERVER" "find \"$SRV_DIFF_DIR\" \"$SRV_FULL_DIR\" \"$SRV_INCR_DIR\" -type d -name \".partial\" | head -n 1")
	if [[ -n "$PARTIAL" ]]; then
		local PARTIAL_DIR=$(dirname "$PARTIAL")
		echo -e "${RED}Une sauvegarde incomplète a été détectée :${NC}"
		echo -e "${YEL}$PARTIAL_DIR${NC}"

		while true; do
			read -rp "Voulez-vous [S]upprimer ou [C]omplèter cette sauvegarde ? " CHOICE
			CHOICE=${CHOICE^^}

			case $CHOICE in
				"S") # L'user choisi de supprimer, alors rm -rf sur le dossier trouvé
					local DIR=$(dirname "$PARTIAL_DIR")
					local RM=$(ssh "$SERVER" "rm -rf \"$DIR\"/" 2>&1)
					if [ $? -ne 0 ]; then
						echo -e "${RED}Erreur lors de la suppression de la sauvegarde partielle...${NC}"
						echo "$RM"
					else
						echo -e "${GRE}La sauvegarde ${YEL}$DIR ${GRE}a bien été supprimée.${NC}"
						echo "Ouverture du menu principal dans 5 secondes..."
						sleep 5
						show_main_menu
					fi
					break
					;;
				"C") # L'user décide de reprendre, on parse le retour de find pour créer les entrées de rsync
					local FOLD=$(dirname "$PARTIAL_DIR")
					local FOLD=$(dirname "$FOLD")
					FOLD=$(basename "$FOLD")
					local SRC="$LOCAL_DIR/$FOLD"
					local DEST=$(dirname "$PARTIAL_DIR")
					# On adapte la commande rsync en fonction du type de backup
					# Si dossier dans INCR_FILES, alors incrémentale, sinon, différentielle ou complète
					if [[ " ${INCR_FILES[*]} " == " $FOLD " ]]; then
						REF=$(get_last_backup incr "$FOLD")
						make_rsync incr "$SRC/" "$DEST" "$REF"
						#echo "Save incr : make_rsync incr $SRC/ $DEST $REF"
					elif [[ " ${DIFF_FILES[*]}" == " $FOLD " ]]; then
						REF=$(get_last_backup diff "$FOLD")
						#echo "Save diff : make_rsync diff $SRC/ $DEST $REF"
						make_rsync diff "$SRC/" "$DEST" "$REF"
					else
						make_rsync full "$SRC/" "$DEST"
						#echo "Save full : make_rsync full $SRC/ $DEST"
					fi
					echo -e "${GRE}Reprise de la sauvegarde terminée. Ouverture du menu principal...\n${NC}"
					sleep 10
					show_main_menu
					;;
				*)
					echo "${RED}Option incorrecte...${NC}"
					;;
			esac
		done
	else
		show_main_menu
	fi
}

# Fonction - Capture d'un ctrl+c, nettoyage de la RAM et des éventuels fichiers TMP
sigint_handler() {
	echo ""
	quit

	# Réinitialiser le gestionnaire de signal et renvoyer SIGINT
	trap - INT
	exec kill -INT "$$"
}

# Fonction - Ajout d'une ligne dynamique récupérant les informations de rsync
show_anim() {
        local PID=$1
        local LOG=$2
        local i=0
        local BAR_WIDTH=20
        local LAST_INC=-1

        # Suppression du pointeur à l'écran
        tput civis

        # Boucle tant que le PID rsync est actif
        while ps -p $PID > /dev/null 2>&1; do
                # On récupère chaque ligne dans le dossier temporaire ou rsync affiche son --progress
                LINE=$(tail -n 1 "$LOG")
                # Tri des lignes que ne nous intéresse pas
                if [[ "$LINE" = "sending incremental file list" ]]; then
                        continue
                fi
                if [[ "$LINE" =~ /$ ]]; then
                        continue
                fi
                if [[ -z "$LINE" ]]; then
                        continue
                fi
                # Capture des infos qui nous intéresse (Poucentage, débit, temps restant)
                local PERCENT=$(echo "$LINE" | grep -o '[0-9]\+%' | tail -n 1)
                local SPEED=$(echo "$LINE" | grep -o '[0-9]\+\.[0-9]\+[KMGT]\?B/s' | tail -n 1)
                local TIME=$(echo "$LINE" | grep -o '[0-9]\{1,\}:[0-9]\{2,\}\(:[0-9]\{2,\}\)\?' | tail -n 1)
                # Calcul pour la taille de la barre de progression
                local BAR_LENGTH=$((INC * BAR_WIDTH / 100))
                local REMAINING_LENGTH=$((BAR_WIDTH - BAR_LENGTH))

                local PROGRESS_BAR=$(printf "%${BAR_LENGTH}s" | sed 's/ /█/g')
                local REMAINING_BAR=$(printf "%${REMAINING_LENGTH}s" | sed 's/ /░/g')

                printf "\r\033[K${CYA}Fichier $i :${NC} [${GRE}${PROGRESS_BAR}${NC}${RED}${REMAINING_BAR}${NC}]  ${YEL}%s${NC} - ${CYA}Débit :${NC} ${YEL}%s${NC} - ${CYA}Temps restant :${NC} ${YEL}%s${NC}" "$PERCENT" "$SPEED" "$TIME"
                # On tente de compter le nombre de fichiers traités en fonction du nombre de fois où le pourcentage retombe à 0
                # A optimiser, manque de fiabilité en raison de la rapidité de traitement des très petits fichiers
                INC=$(echo "$PERCENT" | tr -d "%")
                if [[ "$INC" -eq 0 && "$LAST_INC" -ne 0 ]]; then
                        if [ -z "$RESUME" ]; then
                                RESUME=$i
                        fi
                        ((i++))
                fi

                LAST_INC=$INC

                #sleep 0.0002
        done
        # Le retour du pointeur (c'est un peu moins bien que le retour du jedi)
        tput cnorm

        if [ -n "$RESUME" ]; then
                if [ "$i" -gt 0 ]; then
                        printf "\r\033[K${CYA}Nombre de fichiers transférés :${NC} ${YEL}$i${NC}"
                else
                        printf "\r\033[K${CYA}Aucun fichier n'a été transféré.${NC}"
                fi
        fi
}

# Fonction - Gestion de la rotation des logs
# Appelée au lancement du script, supprime les logs en fonction de leur âge (FULL|DIFF|INCR_CYCLE dans vars.sh)
clear_backup() {
	declare -a TYPE=("DIFF" "INCR" "FULL")

	for VAL in "${TYPE[@]}"; do
		declare -n CYCLE="${VAL}_CYCLE"
		declare -n DIR="SRV_${VAL}_DIR"
		declare -n LOG="${VAL}_LOG_FILE"

        	# Stocker les résultats correctement
		mapfile -t FIND < <(ssh "$SERVER" "ls -d \"$DIR\"/*/*/ | grep -E '/[0-9]{2}-[0-9]{2}-[0-9]{4}/$'")
		T_DATE=$(date -d "-$CYCLE days" +%s)

		for OLD_BKP in "${FIND[@]}"; do
			# Récupération du nom du backup (au format date)
			BASENAME=$(basename "$OLD_BKP")
			# Passage au format UNIX classique (YYYY-MM-JJ)
			R_DATE=$(echo "$BASENAME" | awk -F'-' '{print $3"-"$2"-"$1}')
			# Timestamp du cycle défini
			BACKUP_DATE=$(date -d "$R_DATE" +%s 2>/dev/null)
			# Si la sauvegarde est plus ancienne, on supprime
			if [[ -n "$BACKUP_DATE" && "$BACKUP_DATE" -lt "$T_DATE" ]]; then
				# Exécute rm et capture la sortie d'erreur
				ERROR_MSG=$(ssh "$SERVER" "rm -rf \"$OLD_BKP\"" 2>&1)
				if [[ $? -eq 0 ]]; then
					logs "INFO" "Suppression de la sauvegarde $OLD_BKP. Âge maximal atteint ($CYCLE jours)" "$LOG"
				else
					logs "ERREUR" "Impossible de supprimer la sauvegarde $OLD_BKP. Erreur : $ERROR_MSG" "$LOG"
				fi
			fi
		done
	done
}

