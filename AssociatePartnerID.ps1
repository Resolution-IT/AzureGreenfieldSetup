<#
.SYNOPSIS
    Associates a Microsoft Azure Partner ID with the current Azure subscription.

.DESCRIPTION
    This script verifies required Azure modules, authenticates to Azure, 
    and associates a Microsoft Partner ID (MPN ID) with the current subscription.
    
.NOTES
    Requires Az.Accounts, Az.Resources, and Az.Billing.
#>

# Define parameters
$PartnerId = "2101226"
$LogFile = "PartnerAssociation.log"
$RequiredModules = @("Az.Accounts", "Az.Resources", "Az.Billing")

# Function to log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Write-Output $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Function to check and install/update required modules
function Ensure-AzModules {
    foreach ($module in $RequiredModules) {
        try {
            $installed = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
            if (-not $installed) {
                Write-Log "Module '$module' not found. Installing..."
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                Write-Log "Module '$module' installed successfully."
            } else {
                Write-Log "Module '$module' version $($installed.Version) found."
            }

            Import-Module -Name $module -Force -ErrorAction Stop
            Write-Log "Module '$module' imported successfully."
        }
        catch {
            Write-Log "Error with module '$module': $_" "ERROR"
            exit 1
        }
    }
}

# Begin script execution
Write-Log "===== Starting Azure Partner Association Script ====="

# Step 1: Ensure all required modules are installed and imported
Ensure-AzModules

# Step 2: Get current context
try {
    $context = Get-AzContext -ErrorAction Stop
    $subscriptionId = $context.Subscription.Id
    Write-Log "Current Subscription ID: $subscriptionId"
}
catch {
    Write-Log "Failed to retrieve current Azure context. $_" "ERROR"
    exit 1
}

# Step 4: Associate Partner ID
Write-Log "Attempting to associate Partner ID: $PartnerId..."
try {
    New-AzManagementPartner -PartnerId $PartnerId -ErrorAction Stop
    Write-Log "Partner ID $PartnerId successfully associated with subscription $subscriptionId."
}
catch {
    Write-Log "Failed to associate Partner ID. $_" "ERROR"
    exit 1
}

Write-Log "===== Script completed successfully ====="
