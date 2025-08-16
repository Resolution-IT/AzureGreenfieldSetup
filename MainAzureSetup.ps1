<#
    .SYNOPSIS
    Master script for RIT Baseline Azure Configurations.

    .DESCRIPTION
    This script serves as the master automation entry point to set up core Azure configurations
    for RIT. It prompts the user to optionally execute specific setup scripts such as:
      - Partner ID Association
      - Azure Lighthouse Delegation
      - Management Group Structure
      - Resource Provider 
      

    .AUTHOR
    Deployed by: O.LePrevost
    
    .LASTEDIT
    2025-07-15

    .USAGE
    Run in PowerShell with necessary privileges and authenticated to Azure:
        1. Open PowerShell as Administrator (if elevated permissions are needed).
        2. Execute the script:
            PS> .\Base-AzureSetup.ps1
        3. Respond to prompts to run each setup stage.

    .REQUIREMENTS
    - Azure PowerShell module (`Az`)
    - Internet access to fetch scripts from GitHub
    - Proper permissions on Azure tenant/subscription

#>

# ========== VARIABLES ==========
$script_PartnerAssociation = "https://raw.githubusercontent.com/ritcs/AzureSetup/refs/heads/main/AssociatePartnerID.ps1"
$script_CreateManagementGroups = "https://raw.githubusercontent.com/ritcs/AzureSetup/refs/heads/main/BaseManagementGroups.ps1"
$script_SetupLighthouse = "https://raw.githubusercontent.com/"
$script_ResourceProviderRegistration = "https://raw.githubusercontent.com/ritcs/AzureSetup/refs/heads/main/RegisterResourceProviders.ps1"

# ========== FUNCTIONS ==========

function Write-Info {
    param($msg); Write-Host "[INFO] $msg" -ForegroundColor Cyan
}
function Write-WarningMessage {
    param($msg); Write-Host "[WARNING] $msg" -ForegroundColor Yellow
}
function Write-ErrorMessage {
    param($msg); Write-Host "[ERROR] $msg" -ForegroundColor Red
}

function PSGalleryTrusted {
    Write-Host "Verifying if PSGallery is Trusted" -ForegroundColor Green
    try {
    $gallery = Get-PSRepository -Name "PSGallery"
    if ($gallery.InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Write-Info "PSGallery marked as trusted."
    }
    } catch {
        Write-ErrorMessage "Failed to access PowerShell Gallery. $_"
    exit 1
    }
}

function VerifyPSModules{
    $installedAz = Get-InstalledModule -Name Az -AllVersions -ErrorAction SilentlyContinue

if ($installedAz) {
    $installedVersions = $installedAz | Select-Object -ExpandProperty Version
    Write-Info "Installed Az module versions: $($installedVersions -join ', ')"
} else {
    Write-Info "Az module not currently installed."
}

# ========== Get Latest Az Version from Gallery ==========
try {
    $latestVersion = (Find-Module -Name Az).Version
    Write-Info "Latest available Az version: $latestVersion"
} catch {
    Write-ErrorMessage "Unable to check latest Az version. $_"
    exit 1
}

# ========== Uninstall Old Versions ==========
foreach ($module in $installedAz) {
    if ($module.Version -ne $latestVersion) {
        try {
            Write-WarningMessage "Removing old Az module version: $($module.Version)"
            Uninstall-Module -Name Az -RequiredVersion $module.Version -Force -ErrorAction Stop
        } catch {
            Write-ErrorMessage "Failed to remove version $($module.Version): $_"
        }
    }
}

# ========== Install or Update to Latest ==========
try {
    if (-not ($installedAz | Where-Object Version -eq $latestVersion)) {
        Write-Info "Installing Az $latestVersion..."
        Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-Info "Az module installed successfully."
    } else {
        Write-Info "Az module is already up to date."
    }
} catch {
        Write-ErrorMessage "Failed to install/update Az module: $_"
    exit 1
}

# ========== Import Az Module ==========
try {
    Import-Module Az -Force -ErrorAction Stop
    Write-Info "Az module imported successfully."
} catch {
    Write-ErrorMessage "Failed to import Az module: $_"
    exit 1
}

Write-Host "`Az module setup complete." -ForegroundColor Green
}

function AskToRun {
    param (
        [string]$prompt,
        [string]$scriptPath
    )

    $answer = Read-Host "$prompt (Y/N)"
    if ($answer -eq "Y" -or $answer -eq "y") {
        Write-Host "Running: $scriptPath" -ForegroundColor Cyan
        Run-RemoteScript -scriptUrl "$scriptBaseUrl/$scriptPath"
    } else {
        Write-Host "Skipping: $scriptPath" -ForegroundColor Gray
    }
}

# ========== START ==========
Write-Host "Verifying prerequisities" -ForegroundColor Green
Start-Sleep -Seconds 1
PSGalleryTrusted

Write-Host "Verifying PS Modules" -ForegroundColor Green
Start-Sleep -Seconds 1
VerifyPSModules

Write-Host "RIT BASELINE AZURE SETUP" -ForegroundColor Green
Start-Sleep -Seconds 1

Connect-AzAccount

AskToRun -prompt "Do you want to associate the Microsoft Partner ID for RIT?" -scriptPath $script_PartnerAssociation
AskToRun -prompt "Do you want to create the Management Group hierarchy?" -scriptPath $script_CreateManagementGroups
AskToRun -prompt "Do you want to configure Resource Providers on the Azure subscriptions?" -scriptPath $script_ResourceProviderRegistration
#AskToRun -prompt "Do you want to configure Azure Lighthouse delegation?" -scriptPath $script_SetupLighthouse

Write-Host "All selected scripts completed." -ForegroundColor Green
Write-Host "You may review Azure Portal or logs for changes." -ForegroundColor Yellow