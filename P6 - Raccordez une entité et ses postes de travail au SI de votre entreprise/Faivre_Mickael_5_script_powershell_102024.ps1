<# 
Synchronisation des données vers le disque virtual Google Drive

- Auteur : Mickaël Faivre

- Version actuelle 0.1b

- Historique des versions

    - 1.0b : Refonte complète. Utilisation de Google Drive Desktop et du disque virtuel.

    - 1.0 : Utilisation de l'API Google Cloud via le SDK gcloud
#>


# Paramètres de configuration

# Lettre du disque local à copier
$localDisk = "D:"

# Lettre du disque virtuel Google Drive
$virtualDisk = "G:\Mon Drive" 

# Eléments refusés dans la synchronisation par répertoire
$forbiddenSources = @(
    "C:",
    "C:\Windows",
    "C:\Windows\system32"
)

# Chemin du fichier de log pour robocopy
$logFilePath = "C:\log_robocopy.txt"





# Ici, on ne touche plus à rien


# Variables pour les tests ...
# ... du disque local
$stateLocalDisk = Test-Path -Path $localDisk
# ... du disque virtuel
$stateVirtualDisk = Test-Path -Path $virtualDisk
# ... de la connexion internet
$connexion = Test-Connection -ComputerName www.google.com -ErrorAction SilentlyContinue


# Fonction pour les couleurs
function Write-Color() {

    param(
        [Parameter(Mandatory=$true)]
        [string]$text,
        [Parameter(Mandatory=$true)]
        [ConsoleColor]$color
    )
    Write-Host $text -ForegroundColor $color
}


# Fonction pour quitter en appuyant sur une touche en cas d'erreur
function KeyPress {

    Write-Host "Appuyez sur n'importe quelle touche pour quitter..."
    Read-Host
}


# Fonction pour la gestion des codes d'erreur lors de la commande robocopy
function Handle-ExitCode {

  param(
    [int]$exitCode
  )

  # Traitement du code LASTEXITCODE pour en faire une sortie compréhensible
  switch ($exitCode) {
    0 { Write-Color "Aucune synchronisation nécessaire. Les fichiers sont déjà à jour." Gray }
    1 { Write-Color "Synchronisation terminée." Green }
    2 { Write-Color "Synchronisation partielle. Veuillez vérifier que certains fichiers ou dossiers ne sont pas verrouillés ou que vous avez les droits suffisants." Yellow }
    3 { Write-Color "Synchronisation partielle. Veuillez vérifier que certains fichiers ou dossiers ne sont pas verrouillés ou que vous avez les droits suffisants." Yellow }
    { $exitCode -gt 3 } { Write-Color "Erreur Robocopy: $($exitCode)" Red }
  }
  Write-Host "Les logs de robocopy sont disponibles dans le fichier $logFilePath"
}


# Fonction pour la gestion du choix utilisateur à la fin du robocopy
function Get-UserChoice {

  $choice = Read-Host "Souhaitez-vous [Q]uitter ou revenir au [M]enu principal"
  switch ($choice) {
    'Q' { exit }
    'M' { Main-Menu }
    default { Write-Color "Choix non reconnu, retour au menu principal." Yellow; Main-Menu }
  }
}


# Fonction pour forcer la synchronisation de tout le disque local
function Forced-Sync {

    # Utilisation de /MIR pour le mode miroir
    # /NFL & /NFL : gestion de la sortie (ici, aucun retour)
    robocopy $localDisk $virtualDisk /MIR /R:3 /W:10 /NFL /NDL /LOG:$logFilePath | Out-Null

    # On capte le retour de la fonction de gestion des codes robocopy
    Handle-ExitCode $LASTEXITCODE

    # Puis on appelle la fonction du menu, pour savoir ce que l'user veut faire
    Get-UserChoice
}


# Fonction pour une synchronisation différentielle
function Partial-Sync {

    # On exclu les fichiers $RECYCLE.BIN et System Volume Information pour ne pas avoir de "faux positif" dans le code erreur de la synchro
    # $RECYCLE.BIN se modifiant perpetuellement, sans cela, la synchro dit que des modifications ont été apportées à chaque fois
    $recycle_bin = "$localDisk\`$RECYCLE.BIN"
    # /E pour copier les répertoires vides
    # /DCOPY:DAT : copier les attributs des répertoires
    # /COPY:DAT : copier les attributs des fichiers
    # /XO : exclusion des fichiers plus anciens
    # /XD : exclusion de répertoires spécifiques
    robocopy $localDisk $virtualDisk /E /DCOPY:DAT /COPY:DAT /PURGE /R:3 /W:10 /NFL /NDL /XO /XD "$recycle_bin" "System Volume Information" /LOG:$logFilePath | Out-Null
    
    # On capte le retour de la fonction de gestion des codes robocopy
    Handle-ExitCode $LASTEXITCODE

    # Puis on appelle la fonction du menu, pour savoir ce que l'user veut faire
    Get-UserChoice
}


# Fonction pour traiter la saisie de l'utilisateur
function Handle-DirSelectedSync {

    param (
        [string]$userDir
    )

    if (-not $userDir) {
        return $false
    }
    elseif ($forbiddenSources -contains $userDir) {
        Write-Color "La synchronisation de cette source n'est pas autorisée..." Red
        return $false
    } 
    elseif (Test-Path -Path $userDir) {
        return $true
    }
    else { return $false }
}

# Fonction pour une synchronisation spécifique, par dossier/fichier
function Selected-Sync {
    # On initialise les variables
    $checkDir = $false
    $dir = $null
    
    # Affichage des instructions
    Write-Host "..."
    Write-Host "Le répertoire donné doit avoir la forme suivante <Lettre>:\<Dossier>\<Fichier>"
    Write-Host "Exemple : X:\Mon dossier ou X:\Mon dossier\document.txt"
    Write-Host "Le dossier ou fichier peut être sur un autre disque que celui défini dans les paramètres du script ($localDisk)."
    
    # Boucle sur la vérification de la saisie
    do {
        # Si une tentative précédente a échoué, on affiche le message d'erreur
        if ($checkDir -eq $false -and $dir -ne $null) {
            Write-Host "Le chemin donné n'est pas correct. Veuillez recommencer..." -ForegroundColor Red
        }
        
        # Demander la saisie
        $dir = Read-Host "Veuillez entrer le répertoire à synchroniser"
        
        # Vérifier la saisie
        $checkDir = Handle-DirSelectedSync -userDir $dir
        
        # Si le chemin est valide, on passe à la suite
        if ($checkDir) {
            # Vérifier si c'est un fichier ou un dossier
            if (Test-Path -Path $dir -PathType Container) {
                # C'est un dossier
                robocopy $dir $virtualDisk /E /DCOPY:DAT /COPY:DAT /PURGE /R:3 /W:10 /NFL /NDL /LOG:$logFilePath | Out-Null
            }
            elseif (Test-Path -Path $dir -PathType Leaf) {
                # C'est un fichier
                $parentDir = Split-Path -Parent $dir
                $fileName = Split-Path -Leaf $dir
                robocopy $parentDir $virtualDisk $fileName /COPY:DAT /R:3 /W:10 /NFL /NDL /LOG:$logFilePath | Out-Null
            }
            # On capte le retour de la fonction de gestion des codes robocopy
            Handle-ExitCode $LASTEXITCODE

            # Puis on appelle la fonction du menu, pour savoir ce que l'user veut faire
            Get-UserChoice
        }
    } while (-not $checkDir)
}



# Fonction du menu principal
function Main-Menu {
    Write-Host "1 - Synchronisation forcée complète"
    Write-Host "2 - Synchronisation différentielle"
    Write-Host "3 - Synchroniser un dossier ou un fichier spécifique"
    Write-Host "4 - Quitter le script"
    Write-Host "..."
    $choice = Read-Host "Veuillez indiquer l'option souhaitée"

    # Dépendamment du choix, on envoie à la fonction concernée
    switch ($choice) {
        1 { Forced-Sync }
        2 { Partial-Sync }
        3 { Selected-Sync }
        4 { exit }
        default {
            Write-Color "Choix invalide" Red
            Main-Menu
        }
    }
}

# Fonction de vérification des paramètres de configuration et de la connexion internet
function Test-Environment() {
    # On vérifie l'état de la connexion internet
    if (!$connexion) {
        Write-Color "Connexion KO ..." Red
        Write-Host "Aucune connexion internet détectée. Veuillez vérifier votre connectivité avant de continuer."
        KeyPress
    }
    else {
        Write-Color "Connexion OK ..." Green
        # Si la connexion est OK, on vérifie la présence du disque virtuel Google Drive
        if (!$stateVirtualDisk) {
            Write-Color "Disque virtuel KO ..." Red
            Write-Host "Le disque virtuel $virtualDisk est introuvable. Vérifiez les paramètres de configuration."
            KeyPress
        }
        else {
            Write-Color "Disque virtuel OK ..." Green
            # Si le disque virtuel est OK, on vérifie la présence du disque local
            if (!$stateLocalDisk) {
                Write-Color "Disque local KO ..." Red
                Write-Host "Le disque local $localDisk est introuvable. Vérifiez les paramètres de configuration."
                KeyPress
            }
            # Tous les tests sont au vert, let's go
            else {
                Write-Color "Disque local OK ..." Green
                Write-Host "..."
                # Lancement du menu principal
                Main-Menu
            }
        }
    }
}


# Affichage au lancement du script
Write-Host "Script de synchronisation vers Google Drive"
Write-Host "..."
Write-Host "Vérification de la connexion et des paramètres de configuration ..."

# On lance la fonction de test des différentes variables de conf et de la connexion internet
Test-Environment