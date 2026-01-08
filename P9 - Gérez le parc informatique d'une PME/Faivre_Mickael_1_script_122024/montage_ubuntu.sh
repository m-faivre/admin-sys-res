#!/bin/bash
set -euo pipefail


<<COMMENT
Script bash de montage des dossiers partagés

Auteur : Faivre Mickaël
Date de création 15/01/2025
Version : 0.2

Changelog :
0.2:
        - Démontage des dossiers via unmount ajouté dans les services
        - Version finale ?
0.1d:
        - Ajout d'une fonction et option pour le démontage des lecteurs
0.1c:
        - Factorisation des fonctions de montage
        - Montage des dossiers dans la home de l'user

0.1b:
        - Ajout d'une fonction de log
        - Refonte du script pour programmation fonctionnelle
0.1a:
        - Première mouture du script
        - Montage des lecteurs dans /mnt/$USER

COMMENT


# Définition des variables
USER=$(logname)
USER_HOME="/home/$USER"
MOUNT_POINTS=(
    "Services"
    "Personnel/$USER"
)
SERVER_SHARE="//srv-addc-1.barzini.loc"
LOG_FILE="$USER_HOME/.mount_services.log"
MOUNT_OPTIONS="sec=krb5i,vers=3.0,cruid=$(id -u "$USER"),gid=$(id -g "$USER"),uid=$(id -u "$USER")"

# Fonction de log améliorée
log_message() {
    local level="$1"
    local message="$2"
    printf '%s - [%-7s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$LOG_FILE"
}

# Fonction de vérification/création des dossiers
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_message "INFO" "Création du dossier $dir"
        mkdir -p "$dir" || {
            log_message "ERROR" "Impossible de créer $dir"
            return 1
        }
        log_message "INFO" "Dossier $dir créé avec succès"
        return 0
    fi
    log_message "INFO" "Le dossier $dir existe déjà"
    return 0
}

# Fonction de montage CIFS
mount_share() {
    local share="$1"
    local mount_point="$2"
    
    if mountpoint -q "$mount_point"; then
        log_message "INFO" "$mount_point est déjà monté"
        return 0
    fi

    log_message "INFO" "Tentative de montage de $share sur $mount_point"
    if sudo mount.cifs "$share" "$mount_point" -o "$MOUNT_OPTIONS"; then
        log_message "SUCCESS" "Montage de $share réussi"
        return 0
    else
        log_message "ERROR" "Échec du montage de $share"
        return 1
    fi
}

# Vérification des prérequis
if ! command -v mount.cifs >/dev/null 2>&1; then
    log_message "ERROR" "Le paquet cifs-utils n'est pas installé"
    exit 1
fi

# Fonction de nettoyage
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message "ERROR" "Le script s'est terminé avec une erreur (code: $exit_code)"
    fi
}
trap cleanup EXIT

# Traitement principal
for mount_point in "${MOUNT_POINTS[@]}"; do
    # Création des dossiers
    full_path="$USER_HOME/$mount_point"
    create_directory "$full_path" || exit 1

    # Configuration du chemin de partage
    if [[ "$mount_point" == *"$USER"* ]]; then
        share_path="$SERVER_SHARE/Personnel/$USER"
    else
        share_path="$SERVER_SHARE/$mount_point"
    fi

    # Montage du partage
    mount_share "$share_path" "$full_path" || exit 1
done

log_message "INFO" "Tous les montages ont été effectués avec succès"


# Fonction de démontage
unmount_shares() {
    log_message "INFO" "Début du démontage des partages"
    
    for mount_point in "Services" "Personnel/$USER"; do
        local full_path="$USER_HOME/$mount_point"
        if mountpoint -q "$full_path"; then
            log_message "INFO" "Démontage de $full_path"
            sudo umount "$full_path" || {
                log_message "ERROR" "Échec du démontage de $full_path"
                return 1
            }
        fi
    done
    
    log_message "INFO" "Tous les partages ont été démontés"
    return 0
}


# Gestion de l'argument --unmount pour le démontage des dossiers partagés
case "${1:-}" in
    --unmount)
        unmount_shares
        exit $?
        ;;
esac