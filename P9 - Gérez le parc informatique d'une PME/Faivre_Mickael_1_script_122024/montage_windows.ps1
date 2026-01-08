<#
Script PowerShell de montage des dossiers partagés

Auteur : Faivre Mickaël
Date de création : 15/01/2025
Version : 0.2

Changelog :
0.2:
        - Ajout de la fonction de démontage
        - Vérification des connexions existantes avant le montage
        - Utilisation de paramètres pour le montage
        - Amélioration du logging

0.1b:
        - Remplacement de New-SMBMapping par net use pour corriger le bug avec explorer.exe
        - Ajout de try/catch pour la gestion des erreurs

0.1a:
        - Première mouture du script
        - Création de la fonction de log et montage des lecteurs via New-SMBMapping
#>

param (
    [switch]$Unmount
)

# Chemin du fichier de log
$logFile = "C:\Logs\montage_smb.log"

# Déclaration des variables globales
$domain = "barzini.loc"
$Personnel = "Personnel"
$persoLetter = "P:"
$Services = "Services"
$servLetter = "Q:"
$user = $env:USERNAME

$dirServices = "\\$domain\$Services"
$dirPerso = "\\$domain\$Personnel\$user"

# Fonction pour écrire dans le log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] [$Level] $Message"
}

# Début du script
Write-Log "Début du script de montage des dossiers partagés."
Write-Log "Dossier personnel : $dirPerso"
Write-Log "Dossier services : $dirServices"



# Fonction pour monter un lecteur réseau
function Mount-Share {
    param (
        [string]$DriveLetter,
        [string]$RemotePath
    )

    try {
        if (Get-SmbMapping | Where-Object { $_.LocalPath -eq $DriveLetter }) {
            Write-Log "Le lecteur $DriveLetter est déjà monté sur $RemotePath."
        } else {
            net use $DriveLetter $RemotePath
            Write-Log "Le lecteur $DriveLetter a été monté avec succès sur $RemotePath."
        }
    } catch {
        Write-Log "Erreur lors du montage du lecteur $DriveLetter : $_" -Level "ERROR"
    }
}


# Fonction pour démonter un lecteur réseau
function Unmount-Share {
    param (
        [string]$DriveLetter
    )

    try {
        if (Get-SmbMapping | Where-Object { $_.LocalPath -eq $DriveLetter }) {
            net use $DriveLetter /delete
            Write-Log "Le lecteur $DriveLetter a été démonté avec succès."
        } else {
            Write-Log "Le lecteur $DriveLetter n'est pas monté."
        }
    } catch {
        Write-Log "Erreur lors du démontage du lecteur $DriveLetter : $_" -Level "ERROR"
    }
}

Write-Log "Fin du script de montage des dossiers partagés."

if ($Unmount) {
    Write-Log "Démontage des lecteurs réseau."
    Unmount-Share -DriveLetter $persoLetter
    Unmount-Share -DriveLetter $servLetter
} else {
    Write-Log "Montage des lecteurs réseau."
    Mount-Share -DriveLetter $persoLetter -RemotePath $dirPerso
    Mount-Share -DriveLetter $servLetter -RemotePath $dirServices
}